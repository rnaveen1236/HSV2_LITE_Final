#include <iomanip>
#include <sstream>
#include <jni.h>
#include <string>
#include <android/log.h>
#include "vio/vio_engine.h"
#include "librealsense/src/ds5/ds5-motion.h"
#include "librealsense/src/ds5/ds5-color.h"
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <thread>
#include <atomic>
#include <mutex>
#include <vector>
#include <deque>
#include <cstring>
#include <chrono>
#include <algorithm>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <sys/stat.h>

#include <librealsense2/rs.hpp>
#include <librealsense2/rsutil.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "HSV2Native", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "HSV2Native", __VA_ARGS__)

int currentStage = 1;

// Actual VIO integration engine.
hsv2::VioEngine g_vio_engine;

// Persist the selected D455 IMU stream profiles so camera<->IMU
// calibration/extrinsics can be queried after sensor startup.
rs2::stream_profile g_d455_gyro_profile;
rs2::stream_profile g_d455_accel_profile;
bool g_d455_imu_profiles_valid = false;

bool isCameraInitialized = false;

// ============================================================================
// RealSense Global State
// ============================================================================

std::unique_ptr<rs2::context> rs_ctx;
std::unique_ptr<rs2::pipeline> rs_pipe;

// ============================================================================
// D455 IMU synchronization state
// ============================================================================

std::mutex imu_mutex;

double latest_gyro_timestamp_ms = 0.0;
double latest_accel_timestamp_ms = 0.0;

rs2_vector latest_gyro_data{};
rs2_vector latest_accel_data{};

bool imu_streaming = false;

ANativeWindow* nativeWindow = nullptr;
ANativeWindow* depthNativeWindow = nullptr;

std::atomic<bool> isStreaming(false);
std::thread streamThread;
std::atomic<double> current_fps(0.0);

std::atomic<unsigned long long> imu_gyro_count(0);
std::atomic<unsigned long long> imu_accel_count(0);

// Keep the D455 motion sensor handle alive for the lifetime of IMU streaming.
rs2::sensor g_d455_motion_sensor;
bool g_d455_motion_sensor_valid = false;

// ============================================================================
// Fixed Test Sequence Recorder
// ============================================================================
//
// Records synchronized RGB + Depth frames and RealSense hardware timestamps.
// Used for deterministic live-vs-replay comparison.
//

std::mutex recorder_mutex;

bool fixed_recording = false;

std::string fixed_recording_dir;

std::ofstream fixed_rgb_file;
std::ofstream fixed_depth_file;
std::ofstream fixed_metadata_file;

unsigned long long fixed_recording_frame_count = 0;

std::chrono::steady_clock::time_point fixed_recording_start_time;

constexpr int FIXED_RECORDING_DURATION_SEC = 60;

// ============================================================================
// D455 RGB <-> Depth calibration
// ============================================================================

rs2_intrinsics color_intrinsics{};
rs2_intrinsics depth_intrinsics{};

rs2_extrinsics color_to_depth_extrinsics{};
rs2_extrinsics depth_to_color_extrinsics{};

float depth_scale = 0.001f;
bool calibration_ready = false;

// ============================================================================
// Telemetry state
// ============================================================================

std::mutex telemetry_mutex;
char telemetry_json[4096] = "{}";

// ============================================================
// LIVE LATENCY HISTORY
// Maintains recent latency samples and calculates p50/p95/p99.
// ============================================================
static std::mutex latency_history_mutex;
static std::vector<double> latency_history_ms;

static void add_latency_sample(double latency_ms) {
    std::lock_guard<std::mutex> lock(latency_history_mutex);

    latency_history_ms.push_back(latency_ms);

    // Keep the latest 1000 samples.
    if (latency_history_ms.size() > 1000) {
        latency_history_ms.erase(
                latency_history_ms.begin(),
                latency_history_ms.begin() +
                (latency_history_ms.size() - 1000));
    }
}

static double calculate_percentile(double percentile) {
    std::lock_guard<std::mutex> lock(latency_history_mutex);

    if (latency_history_ms.empty()) {
        return 0.0;
    }

    std::vector<double> samples = latency_history_ms;
    std::sort(samples.begin(), samples.end());

    double position =
            (percentile / 100.0) *
            static_cast<double>(samples.size() - 1);

    size_t lower = static_cast<size_t>(position);
    size_t upper = lower + 1;

    if (upper >= samples.size()) {
        return samples[lower];
    }

    double fraction =
            position - static_cast<double>(lower);

    return samples[lower] +
           fraction * (samples[upper] - samples[lower]);
}

static double read_latency_p50() {
    return calculate_percentile(50.0);
}

static double read_latency_p95() {
    return calculate_percentile(95.0);
}

static double read_latency_p99() {
    return calculate_percentile(99.0);
}



// ============================================================
// LIVE CPU CLOCK TELEMETRY
// Reads CPU0..CPU7 current frequency.
// scaling_cur_freq is reported in kHz.
// Returns highest current CPU frequency in MHz.
// ============================================================

// ============================================================
// LIVE THERMAL TELEMETRY
// Reads thermal_zone0..thermal_zone63.
// Returns the hottest valid temperature in Celsius.
// ============================================================

// ============================================================
// LIVE BATTERY TELEMETRY
// Reads Android battery capacity from sysfs.
// Returns percentage [0..100], or -1 if unavailable.
// ============================================================
static float read_battery_percent() {
    const char* paths[] = {
            "/sys/class/power_supply/battery/capacity",
            "/sys/class/power_supply/BAT0/capacity"
    };

    for (const char* path : paths) {
        std::ifstream battery_file(path);

        if (!battery_file.is_open()) {
            continue;
        }

        int capacity = -1;
        battery_file >> capacity;

        if (!battery_file.fail() &&
            capacity >= 0 &&
            capacity <= 100) {
            return static_cast<float>(capacity);
        }
    }

    return -1.0f;
}

static float read_max_thermal_celsius() {
    float max_cpu_temp_c = -1.0f;

    // Read actual CPU thermal zones only.
    // Exclude cpu-hw-trip-* because those are hardware
    // trip thresholds rather than current CPU temperatures.
    for (int zone = 0; zone < 128; ++zone) {
        const std::string base_path =
                "/sys/class/thermal/thermal_zone" +
                std::to_string(zone);

        const std::string type_path = base_path + "/type";
        const std::string temp_path = base_path + "/temp";

        std::ifstream type_file(type_path);
        std::ifstream temp_file(temp_path);

        if (!type_file.is_open() || !temp_file.is_open()) {
            continue;
        }

        std::string zone_type;
        std::getline(type_file, zone_type);

        // Keep only real CPU thermal zones.
        if (zone_type.rfind("cpu-", 0) != 0) {
            continue;
        }

        // Ignore hardware thermal trip threshold zones.
        if (zone_type.rfind("cpu-hw-trip-", 0) == 0) {
            continue;
        }

        long temp_raw = 0;
        temp_file >> temp_raw;

        if (temp_file.fail()) {
            continue;
        }

        const float temp_c =
                static_cast<float>(temp_raw) / 1000.0f;

        if (temp_c >= 0.0f && temp_c <= 120.0f) {
            if (temp_c > max_cpu_temp_c) {
                max_cpu_temp_c = temp_c;
            }
        }
    }

    return max_cpu_temp_c;
}

static std::string read_cpu_thermal_zones_json() {
    std::string json = "{";
    bool first = true;

    // Record every actual CPU thermal zone individually.
    // Exclude cpu-hw-trip-* because those are trip thresholds,
    // not current CPU temperatures.
    for (int zone = 0; zone < 128; ++zone) {
        const std::string base_path =
                "/sys/class/thermal/thermal_zone" +
                std::to_string(zone);

        const std::string type_path = base_path + "/type";
        const std::string temp_path = base_path + "/temp";

        std::ifstream type_file(type_path);
        std::ifstream temp_file(temp_path);

        if (!type_file.is_open() || !temp_file.is_open()) {
            continue;
        }

        std::string zone_type;
        std::getline(type_file, zone_type);

        if (zone_type.rfind("cpu-", 0) != 0) {
            continue;
        }

        if (zone_type.rfind("cpu-hw-trip-", 0) == 0) {
            continue;
        }

        long temp_raw = 0;
        temp_file >> temp_raw;

        if (temp_file.fail()) {
            continue;
        }

        const float temp_c =
                static_cast<float>(temp_raw) / 1000.0f;

        if (temp_c < 0.0f || temp_c > 120.0f) {
            continue;
        }

        if (!first) {
            json += ",";
        }

        json += "\"";
        json += zone_type;
        json += "\":";
        json += std::to_string(temp_c);

        first = false;
    }

    json += "}";
    return json;
}

static float read_cpu_clock_max_mhz() {
    float max_freq_mhz = -1.0f;

    for (int cpu = 0; cpu < 8; ++cpu) {
        std::string path =
                "/sys/devices/system/cpu/cpu" +
                std::to_string(cpu) +
                "/cpufreq/scaling_cur_freq";

        std::ifstream freq_file(path);

        if (!freq_file.is_open()) {
            continue;
        }

        long freq_khz = 0;
        freq_file >> freq_khz;

        if (freq_file.fail() || freq_khz <= 0) {
            continue;
        }

        float freq_mhz =
                static_cast<float>(freq_khz) / 1000.0f;

        if (freq_mhz > max_freq_mhz) {
            max_freq_mhz = freq_mhz;
        }
    }

    return max_freq_mhz;
}



// ============================================================================
// Latest RGB frame
// ============================================================================

std::mutex latest_rgb_mutex;

std::vector<uint8_t> latest_rgb_frame;

int latest_rgb_width = 0;
int latest_rgb_height = 0;

double latest_rgb_timestamp_ms = 0.0;

unsigned long long latest_rgb_frame_num = 0;

// ============================================================================
// Latest Depth frame
// ============================================================================

std::mutex latest_depth_mutex;

std::vector<uint16_t> latest_depth_frame;

int latest_depth_width = 0;
int latest_depth_height = 0;

double latest_depth_timestamp_ms = 0.0;

unsigned long long latest_depth_frame_num = 0;

// ============================================================================
// IMU sync logger state
std::mutex imu_sync_log_mutex;
std::ofstream imu_sync_log_file;
bool imu_sync_logging = false;
std::chrono::steady_clock::time_point imu_sync_start_time;

// IMU -> FRAME SYNC LOGGER
// ============================================================================
//
// Records nearest hardware-timestamped IMU samples for BOTH RGB and depth.
// This avoids the old "latest IMU sample" association, which can introduce
// an artificial ~70 ms offset when the IMU callback runs ahead of the frame
// processing thread.
//
// CSV columns:
// elapsed_ms
// rgb_frame_number
// rgb_timestamp_ms
// depth_frame_number
// depth_timestamp_ms
// rgb_gyro_timestamp_ms
// rgb_accel_timestamp_ms
// depth_gyro_timestamp_ms
// depth_accel_timestamp_ms
// rgb_gyro_delta_ms
// rgb_accel_delta_ms
// depth_gyro_delta_ms
// depth_accel_delta_ms
// gyro_count
// accel_count
// ============================================================================

struct ImuTimestampSample {
    double timestamp_ms;
    uint64_t count;
};

std::deque<ImuTimestampSample> gyro_timestamp_buffer;
std::deque<ImuTimestampSample> accel_timestamp_buffer;

constexpr size_t IMU_SYNC_BUFFER_SIZE = 1000;

static bool findNearestImuTimestamp(
        const std::deque<ImuTimestampSample>& buffer,
        double frame_timestamp_ms,
        double& nearest_timestamp_ms) {

    if (buffer.empty()) {
        return false;
    }

    double best_diff = std::numeric_limits<double>::max();
    double best_timestamp = 0.0;

    for (const auto& sample : buffer) {

        const double diff =
                std::abs(sample.timestamp_ms - frame_timestamp_ms);

        if (diff < best_diff) {
            best_diff = diff;
            best_timestamp = sample.timestamp_ms;
        }
    }

    nearest_timestamp_ms = best_timestamp;
    return true;
}

void startImuSyncLogger(const std::string& dir) {

    std::lock_guard<std::mutex> lock(
            imu_sync_log_mutex);

    if (imu_sync_logging) {
        return;
    }

    const std::string path =
            dir + "/imu_frame_sync.csv";

    imu_sync_log_file.open(
            path,
            std::ios::out |
            std::ios::trunc);

    if (!imu_sync_log_file.is_open()) {

        LOGE(
                "IMU_SYNC: failed to open log file: %s",
                path.c_str());

        return;
    }

    imu_sync_log_file
            << "elapsed_ms,"
            << "rgb_frame_number,"
            << "rgb_timestamp_ms,"
            << "depth_frame_number,"
            << "depth_timestamp_ms,"
            << "rgb_gyro_timestamp_ms,"
            << "rgb_accel_timestamp_ms,"
            << "depth_gyro_timestamp_ms,"
            << "depth_accel_timestamp_ms,"
            << "rgb_gyro_delta_ms,"
            << "rgb_accel_delta_ms,"
            << "depth_gyro_delta_ms,"
            << "depth_accel_delta_ms,"
            << "gyro_count,"
            << "accel_count\n";

    // Start this validation log with fresh IMU history.
    {
        std::lock_guard<std::mutex> imu_lock(
                imu_mutex);

        gyro_timestamp_buffer.clear();
        accel_timestamp_buffer.clear();
    }

    imu_sync_start_time =
            std::chrono::steady_clock::now();

    imu_sync_logging = true;

    LOGI(
            "IMU_SYNC: logging started: %s",
            path.c_str());
}

void recordImuFrameSync(
        const rs2::video_frame& color_frame,
        const rs2::depth_frame& depth_frame) {

    std::lock_guard<std::mutex> log_lock(
            imu_sync_log_mutex);

    if (!imu_sync_logging ||
        !imu_sync_log_file.is_open()) {
        return;
    }

    const double rgb_ts =
            color_frame.get_timestamp();

    const double depth_ts =
            depth_frame.get_timestamp();

    double rgb_gyro_ts = 0.0;
    double rgb_accel_ts = 0.0;
    double depth_gyro_ts = 0.0;
    double depth_accel_ts = 0.0;

    uint64_t gyro_count = 0;
    uint64_t accel_count = 0;

    {
        std::lock_guard<std::mutex> imu_lock(
                imu_mutex);

        findNearestImuTimestamp(
                gyro_timestamp_buffer,
                rgb_ts,
                rgb_gyro_ts);

        findNearestImuTimestamp(
                accel_timestamp_buffer,
                rgb_ts,
                rgb_accel_ts);

        findNearestImuTimestamp(
                gyro_timestamp_buffer,
                depth_ts,
                depth_gyro_ts);

        findNearestImuTimestamp(
                accel_timestamp_buffer,
                depth_ts,
                depth_accel_ts);

        gyro_count =
                imu_gyro_count.load();

        accel_count =
                imu_accel_count.load();
    }

    const double elapsed_ms =
            std::chrono::duration<double, std::milli>(
                    std::chrono::steady_clock::now() -
                    imu_sync_start_time)
                    .count();

    const double rgb_gyro_delta =
            rgb_gyro_ts != 0.0
                    ? rgb_ts - rgb_gyro_ts
                    : 0.0;

    const double rgb_accel_delta =
            rgb_accel_ts != 0.0
                    ? rgb_ts - rgb_accel_ts
                    : 0.0;

    const double depth_gyro_delta =
            depth_gyro_ts != 0.0
                    ? depth_ts - depth_gyro_ts
                    : 0.0;

    const double depth_accel_delta =
            depth_accel_ts != 0.0
                    ? depth_ts - depth_accel_ts
                    : 0.0;

    imu_sync_log_file
            << std::fixed
            << std::setprecision(3)
            << elapsed_ms << ","
            << color_frame.get_frame_number() << ","
            << rgb_ts << ","
            << depth_frame.get_frame_number() << ","
            << depth_ts << ","
            << rgb_gyro_ts << ","
            << rgb_accel_ts << ","
            << depth_gyro_ts << ","
            << depth_accel_ts << ","
            << rgb_gyro_delta << ","
            << rgb_accel_delta << ","
            << depth_gyro_delta << ","
            << depth_accel_delta << ","
            << gyro_count << ","
            << accel_count
            << "\n";

    imu_sync_log_file.flush();
}

void stopImuSyncLogger() {

    std::lock_guard<std::mutex> lock(
            imu_sync_log_mutex);

    if (!imu_sync_logging) {
        return;
    }

    imu_sync_log_file.flush();
    imu_sync_log_file.close();

    imu_sync_logging = false;

    LOGI("IMU_SYNC: logging stopped");
}


// ============================================================================

// RGB BOX -> DEPTH BOX MAPPING
// ============================================================================
//
// MediaPipe detection box:
//
//     RGB image
//        |
//        v
//     RGB bounding box
//        |
//        v
//     RealSense RGB -> Depth projection
//        |
//        v
//     Depth bounding box
//
// The resulting depth box will later be passed to DepthProcessor for
// central ROI median depth calculation.
// ============================================================================


// ============================================================================
// LADDER STAGE 2
// Decimated depth -> 3D deprojection -> single-frame voxel grid
// ============================================================================
//
// This is an additional workload. It does not replace the MediaPipe pipeline.
// One depth frame is decimated by 2x, deprojected using the runtime D455
// depth intrinsics, and inserted into a single-frame voxel grid.
//


// ============================================================================
// Stage 4: VIO-shaped concurrent CPU workload
// ============================================================================
//
// This is a representative synthetic workload for ladder testing.
// It is NOT a production VIO implementation.
//
// It performs image-gradient-style sampling followed by repeated small
// matrix/vector numerical operations. The work is executed on a separate
// thread so that it overlaps the main D455/MediaPipe pipeline.
// ============================================================================

struct Stage4Result {
    double processing_ms;
    double checksum;
};

static Stage4Result run_stage4_vio_shaped_workload(
        const rs2::video_frame& color_frame) {

    Stage4Result result{};
    const auto start = std::chrono::steady_clock::now();

    if (!color_frame) {
        return result;
    }

    const int width = color_frame.get_width();
    const int height = color_frame.get_height();

    const auto* data =
            static_cast<const uint8_t*>(color_frame.get_data());

    if (!data || width < 8 || height < 8) {
        return result;
    }

    double checksum = 0.0;

    // Image-gradient / feature-tracking style sampling.
    // Sample every 4 pixels to keep the workload deterministic.
    for (int y = 2; y < height - 2; y += 4) {
        for (int x = 2; x < width - 2; x += 4) {

            const int idx = (y * width + x) * 4;

            const double gx =
                    static_cast<double>(data[idx + 4]) -
                    static_cast<double>(data[idx - 4]);

            const double gy =
                    static_cast<double>(data[idx + width * 4]) -
                    static_cast<double>(data[idx - width * 4]);

            const double magnitude =
                    std::sqrt(gx * gx + gy * gy);

            checksum += magnitude;
        }
    }

    // Small iterative matrix/vector workload representative of
    // VIO state propagation / optimization-style numerical processing.
    double state[9] = {
        1.0, 0.1, 0.2,
        0.1, 1.0, 0.3,
        0.2, 0.3, 1.0
    };

    double vector[3] = {
        checksum * 0.000001,
        checksum * 0.000002,
        checksum * 0.000003
    };

    for (int iteration = 0; iteration < 80; ++iteration) {

        double next[3];

        next[0] =
                state[0] * vector[0] +
                state[1] * vector[1] +
                state[2] * vector[2];

        next[1] =
                state[3] * vector[0] +
                state[4] * vector[1] +
                state[5] * vector[2];

        next[2] =
                state[6] * vector[0] +
                state[7] * vector[1] +
                state[8] * vector[2];

        vector[0] = next[0] + 0.0001;
        vector[1] = next[1] + 0.0002;
        vector[2] = next[2] + 0.0003;

        // Lightweight state update.
        state[0] += 0.000001;
        state[4] += 0.000001;
        state[8] += 0.000001;
    }

    checksum += vector[0] + vector[1] + vector[2];

    result.checksum = checksum;

    const auto end = std::chrono::steady_clock::now();
    result.processing_ms =
            std::chrono::duration<double, std::milli>(end - start).count();

    return result;
}

struct Stage2Result {
    double processing_ms;
    size_t valid_points;
    size_t voxel_count;
};

static Stage2Result run_stage2_voxel_workload(
        const rs2::depth_frame& depth_frame) {

    Stage2Result result{};
    const auto start = std::chrono::steady_clock::now();

    if (!depth_frame || !calibration_ready) {
        return result;
    }

    const int src_width = depth_frame.get_width();
    const int src_height = depth_frame.get_height();

    if (src_width <= 0 || src_height <= 0) {
        return result;
    }

    // ------------------------------------------------------------------------
    // 2x decimation
    // ------------------------------------------------------------------------

    constexpr int DECIMATION = 2;

    const int width = src_width / DECIMATION;
    const int height = src_height / DECIMATION;

    if (width <= 0 || height <= 0) {
        return result;
    }

    // Single-frame voxel grid.
    // Voxel size = 20 mm.
    constexpr float VOXEL_SIZE_M = 0.020f;

    std::vector<uint64_t> voxels;
    voxels.reserve(
            static_cast<size_t>(width) *
            static_cast<size_t>(height) / 4);

    for (int y = 0; y < height; ++y) {

        const int src_y = y * DECIMATION;

        for (int x = 0; x < width; ++x) {

            const int src_x = x * DECIMATION;

            const float depth_m =
                    depth_frame.get_distance(src_x, src_y);

            if (depth_m <= 0.10f || depth_m >= 10.0f) {
                continue;
            }

            float pixel[2] = {
                    static_cast<float>(src_x),
                    static_cast<float>(src_y)
            };

            float point[3] = {};

            rs2_deproject_pixel_to_point(
                    point,
                    &depth_intrinsics,
                    pixel,
                    depth_m);

            const int vx = static_cast<int>(
                    std::floor(point[0] / VOXEL_SIZE_M));

            const int vy = static_cast<int>(
                    std::floor(point[1] / VOXEL_SIZE_M));

            const int vz = static_cast<int>(
                    std::floor(point[2] / VOXEL_SIZE_M));

            // Pack signed voxel coordinates into a 64-bit key.
            constexpr int OFFSET = 1000000;

            const uint64_t ux =
                    static_cast<uint64_t>(
                            static_cast<int64_t>(vx) + OFFSET);

            const uint64_t uy =
                    static_cast<uint64_t>(
                            static_cast<int64_t>(vy) + OFFSET);

            const uint64_t uz =
                    static_cast<uint64_t>(
                            static_cast<int64_t>(vz) + OFFSET);

            const uint64_t key =
                    (ux << 42) |
                    ((uy & 0x1FFFFFULL) << 21) |
                    (uz & 0x1FFFFFULL);

            voxels.push_back(key);

            ++result.valid_points;
        }
    }

    // Sort + unique gives the occupied single-frame voxel set.
    std::sort(voxels.begin(), voxels.end());
    voxels.erase(
            std::unique(voxels.begin(), voxels.end()),
            voxels.end());

    result.voxel_count = voxels.size();

    const auto end = std::chrono::steady_clock::now();

    result.processing_ms =
            std::chrono::duration<double, std::milli>(
                    end - start).count();

    return result;
}

static bool mapColorBoxToDepthBox(
        float color_left,
        float color_top,
        float color_right,
        float color_bottom,
        float& depth_left,
        float& depth_top,
        float& depth_right,
        float& depth_bottom) {

    // ------------------------------------------------------------------------
    // Calibration check
    // ------------------------------------------------------------------------

    if (!calibration_ready) {

        LOGE(
                "mapColorBoxToDepthBox: "
                "calibration not ready");

        return false;
    }

    // ------------------------------------------------------------------------
    // Validate RGB bounding box
    // ------------------------------------------------------------------------

    if (color_right <= color_left ||
        color_bottom <= color_top) {

        LOGE(
                "mapColorBoxToDepthBox: "
                "invalid RGB bounding box");

        return false;
    }

    // ------------------------------------------------------------------------
    // Copy latest depth frame safely
    // ------------------------------------------------------------------------

    std::vector<uint16_t> depth_copy;

    int depth_width = 0;
    int depth_height = 0;

    {
        std::lock_guard<std::mutex> lock(
                latest_depth_mutex);

        if (latest_depth_frame.empty() ||
            latest_depth_width <= 0 ||
            latest_depth_height <= 0) {

            LOGE(
                    "mapColorBoxToDepthBox: "
                    "no latest depth frame");

            return false;
        }

        depth_copy =
                latest_depth_frame;

        depth_width =
                latest_depth_width;

        depth_height =
                latest_depth_height;
    }

    // ------------------------------------------------------------------------
    // Validate depth buffer
    // ------------------------------------------------------------------------

    const size_t expected_depth_pixels =
            static_cast<size_t>(depth_width) *
            static_cast<size_t>(depth_height);

    if (depth_copy.size() <
            expected_depth_pixels) {

        LOGE(
                "mapColorBoxToDepthBox: "
                "invalid depth frame size");

        return false;
    }

    // ------------------------------------------------------------------------
    // Clamp RGB coordinates
    // ------------------------------------------------------------------------

    const float color_width =
            static_cast<float>(
                    color_intrinsics.width);

    const float color_height =
            static_cast<float>(
                    color_intrinsics.height);

    color_left =
            std::clamp(
                    color_left,
                    0.0f,
                    color_width - 1.0f);

    color_top =
            std::clamp(
                    color_top,
                    0.0f,
                    color_height - 1.0f);

    color_right =
            std::clamp(
                    color_right,
                    0.0f,
                    color_width - 1.0f);

    color_bottom =
            std::clamp(
                    color_bottom,
                    0.0f,
                    color_height - 1.0f);

    if (color_right <= color_left ||
        color_bottom <= color_top) {

        return false;
    }

    // ------------------------------------------------------------------------
    // Five RGB points
    //
    //       TL ---------------- TR
    //       |                   |
    //       |         C         |
    //       |                   |
    //       BL ---------------- BR
    //
    // Four corners + center.
    // ------------------------------------------------------------------------

    const float points[5][2] = {

        // Top-left
        {
                color_left,
                color_top
        },

        // Top-right
        {
                color_right,
                color_top
        },

        // Bottom-left
        {
                color_left,
                color_bottom
        },

        // Bottom-right
        {
                color_right,
                color_bottom
        },

        // Center
        {
                (color_left + color_right) * 0.5f,
                (color_top + color_bottom) * 0.5f
        }
    };

    // ------------------------------------------------------------------------
    // Initialize depth bounding box
    // ------------------------------------------------------------------------

    float min_x =
            static_cast<float>(
                    depth_width);

    float min_y =
            static_cast<float>(
                    depth_height);

    float max_x = -1.0f;
    float max_y = -1.0f;

    int valid_points = 0;

    // ------------------------------------------------------------------------
    // RGB -> Depth projection
    // ------------------------------------------------------------------------

    for (int i = 0; i < 5; ++i) {

        const float color_pixel[2] = {
                points[i][0],
                points[i][1]
        };

        float depth_pixel[2] = {
                0.0f,
                0.0f
        };

        /*
         * Correct 10-argument RealSense API:
         *
         * 1  to_pixel
         * 2  depth
         * 3  depth_scale
         * 4  depth_min
         * 5  depth_max
         * 6  depth_intrinsics
         * 7  color_intrinsics
         * 8  color_to_depth_extrinsics
         * 9  depth_to_color_extrinsics
         * 10 from_pixel
         */

        rs2_project_color_pixel_to_depth_pixel(
                depth_pixel,
                depth_copy.data(),
                depth_scale,
                0.1f,
                10.0f,
                &depth_intrinsics,
                &color_intrinsics,
                &color_to_depth_extrinsics,
                &depth_to_color_extrinsics,
                color_pixel);

        // --------------------------------------------------------------------
        // Diagnostic: inspect depth near projected coordinate
        // --------------------------------------------------------------------

        int sample_x = static_cast<int>(depth_pixel[0]);
        int sample_y = static_cast<int>(depth_pixel[1]);

        if (sample_x >= 0 &&
            sample_x < depth_width &&
            sample_y >= 0 &&
            sample_y < depth_height) {

            const int sample_index =
                    sample_y * depth_width + sample_x;

            const uint16_t sample_depth_raw =
                    depth_copy[sample_index];

            const float sample_depth_m =
                    sample_depth_raw * depth_scale;

            LOGI(
                    "Projection depth %d: "
                    "DepthPixel[%.1f, %.1f] "
                    "raw=%u distance=%.3f m",
                    i,
                    depth_pixel[0],
                    depth_pixel[1],
                    sample_depth_raw,
                    sample_depth_m);
        } else {
            LOGI(
                    "Projection depth %d: "
                    "DepthPixel[%.1f, %.1f] outside image",
                    i,
                    depth_pixel[0],
                    depth_pixel[1]);
        }

        // --------------------------------------------------------------------
        // Validate projected coordinate
        // --------------------------------------------------------------------

        if (!std::isfinite(depth_pixel[0]) ||
            !std::isfinite(depth_pixel[1])) {

            LOGI(
                    "Projection point %d rejected: "
                    "non-finite Depth[%.1f, %.1f]",
                    i,
                    depth_pixel[0],
                    depth_pixel[1]);

            continue;
        }

        // --------------------------------------------------------------------
        // Reject projections outside actual depth image
        // --------------------------------------------------------------------

        if (depth_pixel[0] < 0.0f ||
            depth_pixel[0] >= static_cast<float>(depth_width) ||
            depth_pixel[1] < 0.0f ||
            depth_pixel[1] >= static_cast<float>(depth_height)) {

            LOGI(
                    "Projection point %d rejected: "
                    "RGB[%.1f, %.1f] -> "
                    "Depth[%.1f, %.1f] outside %dx%d",
                    i,
                    color_pixel[0],
                    color_pixel[1],
                    depth_pixel[0],
                    depth_pixel[1],
                    depth_width,
                    depth_height);

            continue;
        }

        // --------------------------------------------------------------------
        // Reject zero projection
        // --------------------------------------------------------------------

        if (depth_pixel[0] == 0.0f &&
            depth_pixel[1] == 0.0f) {

            LOGI(
                    "Projection point %d rejected: "
                    "RGB[%.1f, %.1f] -> Depth[0.0, 0.0]",
                    i,
                    color_pixel[0],
                    color_pixel[1]);

            continue;
        }

        // --------------------------------------------------------------------
        // Valid projection
        // --------------------------------------------------------------------

        valid_points++;

        LOGI(
                "Projection point %d: "
                "RGB[%.1f, %.1f] -> "
                "Depth[%.1f, %.1f]",
                i,
                color_pixel[0],
                color_pixel[1],
                depth_pixel[0],
                depth_pixel[1]);

        min_x =
                std::min(
                        min_x,
                        depth_pixel[0]);

        min_y =
                std::min(
                        min_y,
                        depth_pixel[1]);

        max_x =
                std::max(
                        max_x,
                        depth_pixel[0]);

        max_y =
                std::max(
                        max_y,
                        depth_pixel[1]);
    }

    // ------------------------------------------------------------------------
    // No valid projection
    // ------------------------------------------------------------------------

    if (valid_points == 0) {

        LOGE(
                "mapColorBoxToDepthBox: "
                "no valid projected points");

        return false;
    }

    // ------------------------------------------------------------------------
    // Check projected box
    // ------------------------------------------------------------------------

    if (max_x < 0.0f ||
        max_y < 0.0f ||
        min_x >
                static_cast<float>(
                        depth_width - 1) ||
        min_y >
                static_cast<float>(
                        depth_height - 1)) {

        LOGE(
                "mapColorBoxToDepthBox: "
                "projected box outside depth image");

        return false;
    }

    // ------------------------------------------------------------------------
    // Clamp final depth box
    // ------------------------------------------------------------------------

    depth_left =
            std::clamp(
                    min_x,
                    0.0f,
                    static_cast<float>(
                            depth_width - 1));

    depth_top =
            std::clamp(
                    min_y,
                    0.0f,
                    static_cast<float>(
                            depth_height - 1));

    depth_right =
            std::clamp(
                    max_x,
                    0.0f,
                    static_cast<float>(
                            depth_width - 1));

    depth_bottom =
            std::clamp(
                    max_y,
                    0.0f,
                    static_cast<float>(
                            depth_height - 1));

    // ------------------------------------------------------------------------
    // Validate final box
    // ------------------------------------------------------------------------

    if (depth_right <= depth_left ||
        depth_bottom <= depth_top) {

        LOGE(
                "mapColorBoxToDepthBox: "
                "invalid mapped depth box");

        return false;
    }

    // ------------------------------------------------------------------------
    // Log mapping
    // ------------------------------------------------------------------------

    LOGI(
            "RGB->Depth box: "
            "RGB[%.1f,%.1f,%.1f,%.1f] "
            "Depth[%.1f,%.1f,%.1f,%.1f] "
            "valid=%d",

            color_left,
            color_top,
            color_right,
            color_bottom,

            depth_left,
            depth_top,
            depth_right,
            depth_bottom,

            valid_points);

    return true;
}

// ============================================================================
// JNI BRIDGE: RGB BOX -> DEPTH BOX
// ============================================================================

extern "C"
JNIEXPORT jfloatArray JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_mapColorBoxToDepthBox(
        JNIEnv* env,
        jobject /* thiz */,
        jfloat left,
        jfloat top,
        jfloat right,
        jfloat bottom) {

    float depth_left = 0.0f;
    float depth_top = 0.0f;
    float depth_right = 0.0f;
    float depth_bottom = 0.0f;

    const bool success =
            mapColorBoxToDepthBox(
                    left,
                    top,
                    right,
                    bottom,
                    depth_left,
                    depth_top,
                    depth_right,
                    depth_bottom);

    if (!success) {

        LOGE(
                "mapColorBoxToDepthBox JNI failed");

        return nullptr;
    }

    jfloatArray output =
            env->NewFloatArray(4);

    if (output == nullptr) {

        LOGE(
                "Failed to allocate depth box array");

        return nullptr;
    }

    const jfloat values[4] = {
            depth_left,
            depth_top,
            depth_right,
            depth_bottom
    };

    env->SetFloatArrayRegion(
            output,
            0,
            4,
            values);

    LOGI(
            "JNI RGB->Depth box: "
            "RGB[%.1f, %.1f, %.1f, %.1f] "
            "Depth[%.1f, %.1f, %.1f, %.1f]",

            left,
            top,
            right,
            bottom,

            depth_left,
            depth_top,
            depth_right,
            depth_bottom);

    return output;
}

// ============================================================================
// Forward declare internal librealsense USB device injection method
// ============================================================================

extern "C" void
Java_com_intel_realsense_librealsense_DeviceWatcher_nAddUsbDevice(
        JNIEnv *env,
        jclass type,
        jstring deviceName,
        jint fileDescriptor);

// ============================================================================
// INIT REALSENSE
// ============================================================================

extern "C" JNIEXPORT jboolean JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_initRealSenseWithFD(
        JNIEnv* env,
        jobject /* this */,
        jint fd,
        jstring usbfsPath) {

    const char *path =
            env->GetStringUTFChars(
                    usbfsPath,
                    nullptr);

    LOGI(
            "Init RealSense with FD: %d, Path: %s",
            fd,
            path);

    try {

        if (!rs_ctx) {

            rs_ctx =
                    std::make_unique<rs2::context>();

            LOGI(
                    "librealsense2 context instantiated successfully!");
        }

        Java_com_intel_realsense_librealsense_DeviceWatcher_nAddUsbDevice(
                env,
                nullptr,
                usbfsPath,
                fd);

        LOGI(
                "Successfully injected USB FD into rsusb backend!");

    } catch (const std::exception& e) {

        LOGE(
                "Error: %s",
                e.what());

        env->ReleaseStringUTFChars(
                usbfsPath,
                path);

        return JNI_FALSE;
    }

    env->ReleaseStringUTFChars(
            usbfsPath,
            path);

    isCameraInitialized = true;

    return JNI_TRUE;
}


// ============================================================================
// D455 CAMERA <-> IMU CALIBRATION QUERY
// ============================================================================

bool queryD455VioCalibration(
    const rs2::pipeline_profile& pipeline_profile)
{
    LOGI("VIO CALIB TRACE: ENTER queryD455VioCalibration()");

    try
    {
        auto* d455_motion =
            librealsense::ds5_motion::get_active_vio_instance();

        auto* d455_color =
            librealsense::get_active_d455_vio_color_instance();

        if (!d455_motion || !d455_color)
        {
            LOGI(
                "VIO CALIB TRACE: active instance missing motion=%s color=%s",
                d455_motion ? "VALID" : "NULL",
                d455_color ? "VALID" : "NULL");
            return false;
        }

        LOGI(
            "VIO CALIB TRACE: active ds5_motion + ds5_color obtained");

        rs2_extrinsics color_to_depth{};
        rs2_extrinsics depth_to_imu{};

        LOGI(
            "VIO CALIB TRACE: BEFORE color_to_depth accessor");

        const bool color_depth_ok =
            d455_color->get_vio_color_to_depth_extrinsics(
                color_to_depth);

        LOGI(
            "VIO CALIB TRACE: AFTER color_to_depth accessor result=%s",
            color_depth_ok ? "SUCCESS" : "FAILED");

        if (!color_depth_ok)
        {
            LOGI(
                "VIO CALIB TRACE: color_to_depth accessor failed");
            return false;
        }

        LOGI(
            "VIO_COLOR_TO_DEPTH: t=[%.6f %.6f %.6f]",
            color_to_depth.translation[0],
            color_to_depth.translation[1],
            color_to_depth.translation[2]);

        LOGI(
            "VIO CALIB TRACE: BEFORE depth_to_imu accessor");

        const bool depth_imu_ok =
            d455_motion->get_vio_depth_to_imu_extrinsics(
                depth_to_imu);

        LOGI(
            "VIO CALIB TRACE: AFTER depth_to_imu accessor result=%s",
            depth_imu_ok ? "SUCCESS" : "FAILED");

        if (!depth_imu_ok)
        {
            LOGI(
                "VIO CALIB TRACE: depth_to_imu accessor failed");
            return false;
        }

        LOGI(
            "VIO_DEPTH_TO_IMU: t=[%.6f %.6f %.6f]",
            depth_to_imu.translation[0],
            depth_to_imu.translation[1],
            depth_to_imu.translation[2]);

        // Compose Color -> Depth and Depth -> IMU:
        //
        // R_ci = R_di * R_cd
        // t_ci = R_di * t_cd + t_di

        rs2_extrinsics color_to_imu{};

        for (int r = 0; r < 3; ++r)
        {
            for (int c = 0; c < 3; ++c)
            {
                color_to_imu.rotation[r * 3 + c] = 0.0f;

                for (int k = 0; k < 3; ++k)
                {
                    color_to_imu.rotation[r * 3 + c] +=
                        depth_to_imu.rotation[r * 3 + k] *
                        color_to_depth.rotation[k * 3 + c];
                }
            }
        }

        for (int r = 0; r < 3; ++r)
        {
            color_to_imu.translation[r] =
                depth_to_imu.translation[r];

            for (int k = 0; k < 3; ++k)
            {
                color_to_imu.translation[r] +=
                    depth_to_imu.rotation[r * 3 + k] *
                    color_to_depth.translation[k];
            }
        }

        LOGI(
            "VIO_COLOR_TO_IMU: t=[%.6f %.6f %.6f]",
            color_to_imu.translation[0],
            color_to_imu.translation[1],
            color_to_imu.translation[2]);

        LOGI(
            "VIO CALIB TRACE: Color->Depth + Depth->IMU composition SUCCESS");

        return true;
    }
    catch (const rs2::error& e)
    {
        LOGI(
            "VIO CALIB TRACE: RealSense error: %s",
            e.what());
        return false;
    }
    catch (const std::exception& e)
    {
        LOGI(
            "VIO CALIB TRACE: std::exception: %s",
            e.what());
        return false;
    }
    catch (...)
    {
        LOGI(
            "VIO CALIB TRACE: unknown exception");
        return false;
    }
}

bool startD455ImuSensor()
{
    LOGI("D455 IMU TRACE: ENTER startD455ImuSensor()");

    if (!rs_ctx) {
        LOGE("IMU start skipped: RealSense context unavailable");
        return false;
    }

    try {
        auto devices = rs_ctx->query_devices();

        if (devices.size() == 0) {
            LOGE("IMU start failed: no RealSense device found");
            return false;
        }

        rs2::device device = devices.front();

        auto sensors = device.query_sensors();

        for (auto&& sensor : sensors) {

            rs2::motion_sensor motion =
                    sensor.as<rs2::motion_sensor>();

            if (!motion) {
                continue;
            }

            // Persist the underlying sensor handle so the callback remains active
            // after startD455ImuSensor() returns.
            g_d455_motion_sensor = sensor;
            g_d455_motion_sensor_valid = true;

            auto profiles =
                    motion.get_stream_profiles();

            rs2::stream_profile selected_gyro;
            rs2::stream_profile selected_accel;

            LOGI(
                    "D455 IMU available profiles: count=%zu",
                    profiles.size());

            for (auto&& profile : profiles) {

                LOGI(
                        "IMU profile: stream=%d format=%d fps=%d index=%d",
                        static_cast<int>(profile.stream_type()),
                        static_cast<int>(profile.format()),
                        profile.fps(),
                        profile.stream_index());

                if (profile.stream_type() == RS2_STREAM_GYRO &&
                    profile.format() == RS2_FORMAT_MOTION_XYZ32F) {

                    if (!selected_gyro ||
                        profile.fps() > selected_gyro.fps()) {

                        selected_gyro = profile;
                    }
                }

                if (profile.stream_type() == RS2_STREAM_ACCEL &&
                    profile.format() == RS2_FORMAT_MOTION_XYZ32F) {

                    if (!selected_accel ||
                        profile.fps() > selected_accel.fps()) {

                        selected_accel = profile;
                    }
                }
            }

            if (!selected_gyro || !selected_accel) {
                LOGE(
                        "IMU profiles not found: gyro=%d accel=%d",
                        selected_gyro ? 1 : 0,
                        selected_accel ? 1 : 0);
                continue;
            }

            // Persist the selected profiles for VIO calibration/extrinsics queries.
            g_d455_gyro_profile = selected_gyro;
            g_d455_accel_profile = selected_accel;
            g_d455_imu_profiles_valid = true;

            LOGI(
                    "VIO IMU profiles saved: gyro_fps=%d accel_fps=%d",
                    selected_gyro.fps(),
                    selected_accel.fps());

            std::vector<rs2::stream_profile> imu_profiles;
            imu_profiles.push_back(selected_gyro);
            imu_profiles.push_back(selected_accel);

            motion.open(imu_profiles);

            motion.start(
                    [](rs2::frame frame) {

                try {

                    rs2::motion_frame motion_frame =
                            frame.as<rs2::motion_frame>();

                    if (!motion_frame) {
                        return;
                    }

                    const auto stream_type =
                            frame.get_profile()
                                 .stream_type();

                    const double timestamp_ms =
                            frame.get_timestamp();

                    const rs2_vector motion_data =
                            motion_frame.get_motion_data();

                    std::lock_guard<std::mutex> lock(
                            imu_mutex);

                    if (stream_type == RS2_STREAM_GYRO) {

                        latest_gyro_timestamp_ms =
                                timestamp_ms;

                        latest_gyro_data =
                                motion_data;

                        // Feed the real D455 gyro sample into VIO.
                        g_vio_engine.addGyro(
                                timestamp_ms,
                                hsv2::Vec3{
                                        motion_data.x,
                                        motion_data.y,
                                        motion_data.z});

                        const auto count =
                                ++imu_gyro_count;

                        // Store hardware timestamp for nearest frame matching.
                        gyro_timestamp_buffer.push_back(
                                {timestamp_ms, count});

                        while (gyro_timestamp_buffer.size() >
                               IMU_SYNC_BUFFER_SIZE) {
                            gyro_timestamp_buffer.pop_front();
                        }

                        if (count == 1 || count % 200 == 0) {

                            LOGI(
                                    "IMU GYRO samples=%llu "
                                    "timestamp=%.3f "
                                    "xyz=[%.4f, %.4f, %.4f]",
                                    count,
                                    timestamp_ms,
                                    motion_data.x,
                                    motion_data.y,
                                    motion_data.z);
                        }

                    } else if (stream_type == RS2_STREAM_ACCEL) {

                        latest_accel_timestamp_ms =
                                timestamp_ms;

                        latest_accel_data =
                                motion_data;

                        // Feed the real D455 accelerometer sample into VIO.
                        g_vio_engine.addAccel(
                                timestamp_ms,
                                hsv2::Vec3{
                                        motion_data.x,
                                        motion_data.y,
                                        motion_data.z});

                        const auto count =
                                ++imu_accel_count;

                        // Store hardware timestamp for nearest frame matching.
                        accel_timestamp_buffer.push_back(
                                {timestamp_ms, count});

                        while (accel_timestamp_buffer.size() >
                               IMU_SYNC_BUFFER_SIZE) {
                            accel_timestamp_buffer.pop_front();
                        }

                        if (count == 1 || count % 200 == 0) {

                            LOGI(
                                    "IMU ACCEL samples=%llu "
                                    "timestamp=%.3f "
                                    "xyz=[%.4f, %.4f, %.4f]",
                                    count,
                                    timestamp_ms,
                                    motion_data.x,
                                    motion_data.y,
                                    motion_data.z);
                        }
                    }

                } catch (const std::exception& e) {

                    LOGE(
                            "IMU callback exception: %s",
                            e.what());
                }
            });

            imu_streaming = true;

            LOGI(
                    "D455 IMU sensor started: "
                    "gyro=200Hz accel=63Hz");

            return true;
        }

    } catch (const std::exception& e) {

        LOGE(
                "Failed to start D455 IMU sensor: %s",
                e.what());
    }

    return false;
}

// ============================================================================
// FIXED TEST SEQUENCE RECORDING
// ============================================================================

extern "C" JNIEXPORT void JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_startFixedRecording(
        JNIEnv* env,
        jobject /* this */,
        jstring filesDir) {

    std::lock_guard<std::mutex> lock(recorder_mutex);

    if (fixed_recording) {
        LOGI("FIXED_RECORDING already active");
        return;
    }

    if (filesDir == nullptr) {
        LOGE("FIXED_RECORDING: filesDir is null");
        return;
    }

    const char* path = env->GetStringUTFChars(filesDir, nullptr);

    if (path == nullptr) {
        LOGE("FIXED_RECORDING: failed to read filesDir");
        return;
    }

    fixed_recording_dir =
            std::string(path) + "/fixed_sequence";

    env->ReleaseStringUTFChars(filesDir, path);

    try {

        mkdir(
                fixed_recording_dir.c_str(),
                0700);

        fixed_rgb_file.open(
                fixed_recording_dir + "/rgb.bin",
                std::ios::binary | std::ios::trunc);

        fixed_depth_file.open(
                fixed_recording_dir + "/depth.bin",
                std::ios::binary | std::ios::trunc);

        fixed_metadata_file.open(
                fixed_recording_dir + "/metadata.csv",
                std::ios::out | std::ios::trunc);

        if (!fixed_rgb_file.is_open() ||
            !fixed_depth_file.is_open() ||
            !fixed_metadata_file.is_open()) {

            LOGE(
                    "FIXED_RECORDING: failed to open output files");

            if (fixed_rgb_file.is_open())
                fixed_rgb_file.close();

            if (fixed_depth_file.is_open())
                fixed_depth_file.close();

            if (fixed_metadata_file.is_open())
                fixed_metadata_file.close();

            return;
        }

        fixed_metadata_file
                << "frame_index,"
                << "rgb_frame_number,"
                << "rgb_timestamp_ms,"
                << "depth_frame_number,"
                << "depth_timestamp_ms,"
                << "rgb_width,"
                << "rgb_height,"
                << "depth_width,"
                << "depth_height,"
                << "record_elapsed_ms\n";

        fixed_recording_frame_count = 0;

        fixed_recording_start_time =
                std::chrono::steady_clock::now();

        fixed_recording = true;

        // Start IMU-to-frame timestamp logging in the same fixed-sequence directory.
        LOGI("IMU_SYNC: about to start logger, dir=%s",
             fixed_recording_dir.c_str());
        startImuSyncLogger(fixed_recording_dir);

        LOGI(
                "FIXED_RECORDING STARTED "
                "duration=%d sec "
                "dir=%s",
                FIXED_RECORDING_DURATION_SEC,
                fixed_recording_dir.c_str());

    } catch (const std::exception& e) {

        LOGE(
                "FIXED_RECORDING start exception: %s",
                e.what());

        if (fixed_rgb_file.is_open())
            fixed_rgb_file.close();

        if (fixed_depth_file.is_open())
            fixed_depth_file.close();

        if (fixed_metadata_file.is_open())
            fixed_metadata_file.close();
    }
}


extern "C" JNIEXPORT void JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_stopFixedRecording(
        JNIEnv* /* env */,
        jobject /* this */) {

    std::lock_guard<std::mutex> lock(recorder_mutex);

    if (!fixed_recording) {
        LOGI("FIXED_RECORDING is not active");
        return;
    }

    fixed_recording = false;

    // Stop and flush IMU-to-frame timestamp logging.
    stopImuSyncLogger();

    if (fixed_rgb_file.is_open())
        fixed_rgb_file.close();

    if (fixed_depth_file.is_open())
        fixed_depth_file.close();

    if (fixed_metadata_file.is_open())
        fixed_metadata_file.close();

    LOGI(
            "FIXED_RECORDING STOPPED "
            "frames=%llu "
            "dir=%s",
            fixed_recording_frame_count,
            fixed_recording_dir.c_str());
}


// ============================================================================
// EXPORT FIXED TEST SEQUENCE
// ============================================================================
//
// Copies the completed recording from app-private storage to Download
// so it can be retrieved with adb.
//

extern "C" JNIEXPORT jboolean JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_exportFixedRecording(
        JNIEnv* env,
        jobject /* this */,
        jstring destinationDir) {

    try {

        const std::string source_dir =
                fixed_recording_dir;

        const char* destination_path =
                env->GetStringUTFChars(
                        destinationDir,
                        nullptr);

        if (destination_path == nullptr) {
            LOGE("FIXED_EXPORT: destination path is null");
            return JNI_FALSE;
        }

        const std::string destination_dir =
                std::string(destination_path) +
                "/HSV2_fixed_sequence";

        env->ReleaseStringUTFChars(
                destinationDir,
                destination_path);

        mkdir(
                destination_dir.c_str(),
                0777);

        const std::string files[] = {
                "rgb.bin",
                "depth.bin",
                "metadata.csv",
                "imu_frame_sync.csv"
        };

        for (const auto& file : files) {

            const std::string source =
                    source_dir + "/" + file;

            const std::string destination =
                    destination_dir + "/" + file;

            std::ifstream input(
                    source,
                    std::ios::binary);

            if (!input.is_open()) {

                LOGE(
                        "FIXED_EXPORT: failed to open %s",
                        source.c_str());

                return JNI_FALSE;
            }

            std::ofstream output(
                    destination,
                    std::ios::binary |
                    std::ios::trunc);

            if (!output.is_open()) {

                LOGE(
                        "FIXED_EXPORT: failed to create %s",
                        destination.c_str());

                return JNI_FALSE;
            }

            output << input.rdbuf();

            input.close();
            output.close();

            LOGI(
                    "FIXED_EXPORT: copied %s",
                    file.c_str());
        }

        LOGI(
                "FIXED_EXPORT: SUCCESS destination=%s",
                destination_dir.c_str());

        return JNI_TRUE;

    } catch (const std::exception& e) {

        LOGE(
                "FIXED_EXPORT exception: %s",
                e.what());

        return JNI_FALSE;
    }
}

// ============================================================================
// START PIPELINE
// ============================================================================

extern "C" JNIEXPORT void JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_startPipeline(
        JNIEnv* env,
        jobject /* this */) {

    if (isStreaming ||
        !rs_ctx) {

        return;
    }

    try {

        rs_pipe =
                std::make_unique<rs2::pipeline>(
                        *rs_ctx);

        rs2::config cfg;

        // --------------------------------------------------------------------
        // COLOR STREAM
        // --------------------------------------------------------------------

        cfg.enable_stream(
                RS2_STREAM_COLOR,
                640,
                480,
                RS2_FORMAT_RGBA8,
                15);

        // --------------------------------------------------------------------
        // DEPTH STREAM
        // --------------------------------------------------------------------

        cfg.enable_stream(
                RS2_STREAM_DEPTH,
                640,
                480,
                RS2_FORMAT_Z16,
                15);

        // --------------------------------------------------------------------
        // START PIPELINE
        // --------------------------------------------------------------------

        rs2::pipeline_profile pipeline_profile =
                rs_pipe->start(cfg);

        // --------------------------------------------------------------------
        // START D455 IMU SENSOR SEPARATELY FROM RGB/DEPTH PIPELINE
        // --------------------------------------------------------------------

        const bool imu_started =
                startD455ImuSensor();

        LOGI(
                "D455 IMU start result: %s",
                imu_started ? "SUCCESS" : "FAILED");

        // --------------------------------------------------------------------
        // QUERY D455 CAMERA <-> IMU CALIBRATION FOR VIO
        // --------------------------------------------------------------------

        if (imu_started) {
            const bool vio_calibration_ok =
                    queryD455VioCalibration(pipeline_profile);

            LOGI(
                    "D455 VIO calibration query result: %s",
                    vio_calibration_ok ? "SUCCESS" : "FAILED");
        } else {
            LOGI(
                    "D455 VIO calibration skipped: IMU startup failed");
        }

        // --------------------------------------------------------------------
        // CACHE D455 CALIBRATION
        // --------------------------------------------------------------------

        try {

            auto color_profile =
                    pipeline_profile
                            .get_stream(
                                    RS2_STREAM_COLOR)
                            .as<rs2::video_stream_profile>();

            auto depth_profile =
                    pipeline_profile
                            .get_stream(
                                    RS2_STREAM_DEPTH)
                            .as<rs2::video_stream_profile>();

            auto depth_sensor =
                    pipeline_profile
                            .get_device()
                            .first<rs2::depth_sensor>();

            depth_scale =
                    depth_sensor.get_depth_scale();

            color_intrinsics =
                    color_profile.get_intrinsics();

            depth_intrinsics =
                    depth_profile.get_intrinsics();

            color_to_depth_extrinsics =
                    color_profile.get_extrinsics_to(
                            depth_profile);

            depth_to_color_extrinsics =
                    depth_profile.get_extrinsics_to(
                            color_profile);

            calibration_ready = true;

            // Initialize VIO using the actual D455 RGB camera intrinsics.
            const bool vio_initialized =
                    g_vio_engine.initialize(
                            color_intrinsics.width,
                            color_intrinsics.height,
                            color_intrinsics.fx,
                            color_intrinsics.fy,
                            color_intrinsics.ppx,
                            color_intrinsics.ppy);

            LOGI(
                    "VIO initialization: %s",
                    vio_initialized ? "SUCCESS" : "FAILED");

            LOGI(
                    "D455 calibration ready: "
                    "color=%dx%d fx=%.2f fy=%.2f "
                    "depth=%dx%d fx=%.2f fy=%.2f "
                    "depth_scale=%.6f",

                    color_intrinsics.width,
                    color_intrinsics.height,
                    color_intrinsics.fx,
                    color_intrinsics.fy,

                    depth_intrinsics.width,
                    depth_intrinsics.height,
                    depth_intrinsics.fx,
                    depth_intrinsics.fy,

                    depth_scale);

        } catch (const rs2::error& e) {

            calibration_ready = false;

            LOGE(
                    "Failed to get D455 calibration: %s",
                    e.what());
        }

        isStreaming = true;

        current_fps = 0.0;

        // --------------------------------------------------------------------
        // STREAM THREAD
        // --------------------------------------------------------------------

        streamThread =
                std::thread([]() {

            LOGI(
                    "Native stream thread started!");

            rs2::colorizer color_map;

            auto last_time =
                    std::chrono::steady_clock::now();

            int frame_count = 0;

            unsigned long long last_frame_num = 0;

            int total_dropped_frames = 0;

            while (isStreaming) {

                if (currentStage >= 1) {

                    try {

                        const auto frame_loop_start =
                                std::chrono::steady_clock::now();

                        rs2::frameset frames =
                                rs_pipe->wait_for_frames(
                                        5000);

                        const auto frames_received =
                                std::chrono::steady_clock::now();

                        const double wait_ms =
                                std::chrono::duration<
                                        double,
                                        std::milli>(
                                        frames_received -
                                        frame_loop_start)
                                        .count();

                        rs2::video_frame color_frame =
                                frames.get_color_frame();

                        rs2::depth_frame depth_frame =
                                frames.get_depth_frame();

                        // -----------------------------------------------------
                        // ACTUAL VIO RGB INPUT
                        // Feed the real D455 RGB frame and hardware timestamp
                        // into the VIO engine.
                        // -----------------------------------------------------

                        if (color_frame &&
                            g_vio_engine.isInitialized()) {

                            const bool vio_image_ok =
                                    g_vio_engine.addImage(
                                            color_frame.get_timestamp(),
                                            static_cast<const uint8_t*>(
                                                    color_frame.get_data()),
                                            color_frame.get_width(),
                                            color_frame.get_height());

                            if (currentStage == 4 && vio_image_ok) {

                                const hsv2::VioTiming vio_timing =
                                        g_vio_engine.getTiming();

                                LOGI(
                                        "VIO_INPUT: "
                                        "frame=%llu "
                                        "timestamp=%.3f "
                                        "processing=%.3f ms "
                                        "images=%llu "
                                        "imu=%llu",
                                        static_cast<unsigned long long>(
                                                color_frame.get_frame_number()),
                                        color_frame.get_timestamp(),
                                        vio_timing.processing_ms,
                                        static_cast<unsigned long long>(
                                                vio_timing.image_count),
                                        static_cast<unsigned long long>(
                                                vio_timing.imu_count));
                            }
                        }

                        // -----------------------------------------------------
                        // LADDER STAGE 4
                        // VIO-shaped concurrent CPU workload.
                        // Runs on a separate thread so it overlaps the normal
                        // D455 + MediaPipe processing pipeline.
                        // -----------------------------------------------------

                        if (currentStage == 4 && color_frame) {

                            rs2::video_frame stage4_frame = color_frame;

                            std::thread([stage4_frame]() {

                                const Stage4Result stage4 =
                                        run_stage4_vio_shaped_workload(
                                                stage4_frame);

                                LOGI(
                                        "STAGE4: "
                                        "time=%.2f ms "
                                        "checksum=%.6f",
                                        stage4.processing_ms,
                                        stage4.checksum);

                            }).detach();
                        }

                        // -----------------------------------------------------
                        // LADDER STAGE 2
                        // Decimated depth + 3D deprojection + single-frame
                        // voxel grid. This adds workload without replacing
                        // the normal MediaPipe pipeline.
                        // -----------------------------------------------------

                        if (currentStage == 2 && depth_frame) {

                            const Stage2Result stage2 =
                                    run_stage2_voxel_workload(
                                            depth_frame);

                            LOGI(
                                    "STAGE2: "
                                    "time=%.2f ms "
                                    "valid_points=%zu "
                                    "voxels=%zu",
                                    stage2.processing_ms,
                                    stage2.valid_points,
                                    stage2.voxel_count);
                        }

                        // -----------------------------------------------------
                        // COPY LATEST DEPTH FRAME
                        // -----------------------------------------------------

                        if (depth_frame) {

                            const int depth_width =
                                    depth_frame.get_width();

                            const int depth_height =
                                    depth_frame.get_height();

                            const size_t depth_pixels =
                                    static_cast<size_t>(
                                            depth_width) *
                                    static_cast<size_t>(
                                            depth_height);

                            std::lock_guard<std::mutex>
                                    depth_lock(
                                            latest_depth_mutex);

                            latest_depth_frame.resize(
                                    depth_pixels);

                            std::memcpy(
                                    latest_depth_frame.data(),
                                    depth_frame.get_data(),
                                    depth_pixels *
                                            sizeof(uint16_t));

                            latest_depth_width =
                                    depth_width;

                            latest_depth_height =
                                    depth_height;

                            latest_depth_timestamp_ms =
                                    depth_frame.get_timestamp();

                            latest_depth_frame_num =
                                    depth_frame.get_frame_number();
                        }

                        // -----------------------------------------------------
                        // COPY LATEST RGB FRAME
                        // -----------------------------------------------------

                        const auto rgb_copy_start =
                                std::chrono::steady_clock::now();

                        if (color_frame) {

                            const int rgb_width =
                                    color_frame.get_width();

                            const int rgb_height =
                                    color_frame.get_height();

                            const size_t rgb_bytes =
                                    static_cast<size_t>(
                                            rgb_width) *
                                    static_cast<size_t>(
                                            rgb_height) *
                                    4;

                            std::lock_guard<std::mutex>
                                    rgb_lock(
                                            latest_rgb_mutex);

                            latest_rgb_frame.resize(
                                    rgb_bytes);

                            std::memcpy(
                                    latest_rgb_frame.data(),
                                    color_frame.get_data(),
                                    rgb_bytes);

                            latest_rgb_width =
                                    rgb_width;

                            latest_rgb_height =
                                    rgb_height;

                            latest_rgb_timestamp_ms =
                                    color_frame.get_timestamp();

                            latest_rgb_frame_num =
                                    color_frame.get_frame_number();
                        }

                        // -----------------------------------------------------
                        // FIXED TEST SEQUENCE RECORDING
                        // -----------------------------------------------------
                        //
                        // Record one RGB + Depth pair per frameset.
                        // The binary files contain raw frame data.
                        // metadata.csv contains the corresponding RealSense
                        // hardware timestamps and frame numbers.
                        //

                        static int fixed_debug_count = 0;
                        if (fixed_debug_count < 10) {
                            LOGI(
                                    "FIXED_DEBUG: recording=%d color=%d depth=%d",
                                    fixed_recording ? 1 : 0,
                                    color_frame ? 1 : 0,
                                    depth_frame ? 1 : 0);
                            ++fixed_debug_count;
                        }

                        if (fixed_recording &&
                            color_frame &&
                            depth_frame) {

                            std::lock_guard<std::mutex>
                                    recorder_lock(recorder_mutex);

                            if (fixed_recording) {

                                const auto recording_now =
                                        std::chrono::steady_clock::now();

                                const double elapsed_ms =
                                        std::chrono::duration<
                                                double,
                                                std::milli>(
                                                recording_now -
                                                fixed_recording_start_time)
                                                .count();

                                if (elapsed_ms <
                                    FIXED_RECORDING_DURATION_SEC * 1000.0) {

                                    const int record_rgb_width =
                                            color_frame.get_width();

                                    const int record_rgb_height =
                                            color_frame.get_height();

                                    const int record_depth_width =
                                            depth_frame.get_width();

                                    const int record_depth_height =
                                            depth_frame.get_height();

                                    const size_t record_rgb_bytes =
                                            static_cast<size_t>(
                                                    record_rgb_width) *
                                            static_cast<size_t>(
                                                    record_rgb_height) *
                                            4;

                                    const size_t record_depth_bytes =
                                            static_cast<size_t>(
                                                    record_depth_width) *
                                            static_cast<size_t>(
                                                    record_depth_height) *
                                            sizeof(uint16_t);

                                    const uint32_t
                                            rgb_size =
                                            static_cast<uint32_t>(
                                                    record_rgb_bytes);

                                    const uint32_t
                                            depth_size =
                                            static_cast<uint32_t>(
                                                    record_depth_bytes);

                                    // Store frame sizes before each raw frame.
                                    fixed_rgb_file.write(
                                            reinterpret_cast<const char*>(
                                                    &rgb_size),
                                            sizeof(rgb_size));

                                    fixed_rgb_file.write(
                                            reinterpret_cast<const char*>(
                                                    color_frame.get_data()),
                                            record_rgb_bytes);

                                    fixed_depth_file.write(
                                            reinterpret_cast<const char*>(
                                                    &depth_size),
                                            sizeof(depth_size));

                                    fixed_depth_file.write(
                                            reinterpret_cast<const char*>(
                                                    depth_frame.get_data()),
                                            record_depth_bytes);

                                    // Record RGB/depth frame timestamps together with
                                    // the latest D455 gyro/accelerometer timestamps.
                                    recordImuFrameSync(
                                            color_frame,
                                            depth_frame);

                                    fixed_metadata_file
                                            << std::fixed
                                            << std::setprecision(6)
                                            << fixed_recording_frame_count
                                            << ","
                                            << color_frame.get_frame_number()
                                            << ","
                                            << color_frame.get_timestamp()
                                            << ","
                                            << depth_frame.get_frame_number()
                                            << ","
                                            << depth_frame.get_timestamp()
                                            << ","
                                            << record_rgb_width
                                            << ","
                                            << record_rgb_height
                                            << ","
                                            << record_depth_width
                                            << ","
                                            << record_depth_height
                                            << ","
                                            << elapsed_ms
                                            << "\n";

                                    ++fixed_recording_frame_count;

                                    if (fixed_recording_frame_count % 30 ==
                                        0) {

                                        LOGI(
                                                "FIXED_RECORDING "
                                                "frames=%llu "
                                                "elapsed=%.1fs",
                                                fixed_recording_frame_count,
                                                elapsed_ms / 1000.0);
                                    }

                                } else {

                                    fixed_recording = false;

                                    if (fixed_rgb_file.is_open())
                                        fixed_rgb_file.close();

                                    if (fixed_depth_file.is_open())
                                        fixed_depth_file.close();

                                    if (fixed_metadata_file.is_open())
                                        fixed_metadata_file.close();

                                    stopImuSyncLogger();

                                    LOGI(
                                            "FIXED_RECORDING COMPLETE "
                                            "frames=%llu "
                                            "duration=%.1fs "
                                            "dir=%s",
                                            fixed_recording_frame_count,
                                            elapsed_ms / 1000.0,
                                            fixed_recording_dir.c_str());
                                }
                            }
                        }

                        const auto rgb_copy_end =
                                std::chrono::steady_clock::now();

                        const double rgb_copy_ms =
                                std::chrono::duration<
                                        double,
                                        std::milli>(
                                        rgb_copy_end -
                                        rgb_copy_start)
                                        .count();

                        // -----------------------------------------------------
                        // DROPPED FRAME TRACKING
                        // -----------------------------------------------------

                        unsigned long long current_frame_num =
                                color_frame.get_frame_number();

                        if (last_frame_num != 0 &&
                            current_frame_num >
                                    last_frame_num + 1) {

                            total_dropped_frames +=
                                    static_cast<int>(
                                            current_frame_num -
                                            last_frame_num -
                                            1);
                        }

                        last_frame_num =
                                current_frame_num;

                        // -----------------------------------------------------
                        // CAMERA-TO-FRAME LATENCY
                        // -----------------------------------------------------

                        double frame_timestamp_ms =
                                color_frame.get_timestamp();

                        auto now_sys =
                                std::chrono::system_clock::now();

                        double sys_time_ms =
                                std::chrono::duration_cast<
                                        std::chrono::milliseconds>(
                                        now_sys.time_since_epoch())
                                        .count();

                        double latency =
                                sys_time_ms -
                                frame_timestamp_ms;

                        if (latency < 0 ||
                            latency > 1000) {

                            latency = 16.6;
                        }

                        // Add this live sample to the rolling latency history.
                        add_latency_sample(latency);

                        // -----------------------------------------------------
                        // FPS
                        // -----------------------------------------------------

                        frame_count++;

                        auto now =
                                std::chrono::steady_clock::now();

                        auto elapsed =
                                std::chrono::duration_cast<
                                        std::chrono::milliseconds>(
                                        now - last_time)
                                        .count();

                        if (elapsed >= 1000) {

                            current_fps =
                                    (frame_count * 1000.0) /
                                    elapsed;

                            frame_count = 0;

                            last_time = now;
                        }

                        // -----------------------------------------------------
                        // RGB RENDER
                        // -----------------------------------------------------

                        double rgb_render_ms = 0.0;

                        if (nativeWindow &&
                            color_frame) {

                            const auto rgb_render_start =
                                    std::chrono::steady_clock::now();

                            ANativeWindow_Buffer buffer;

                            if (ANativeWindow_lock(
                                        nativeWindow,
                                        &buffer,
                                        nullptr) == 0) {

                                int width =
                                        color_frame.get_width();

                                int height =
                                        color_frame.get_height();

                                if (buffer.width >= width &&
                                    buffer.height >= height) {

                                    uint8_t* out =
                                            static_cast<uint8_t*>(
                                                    buffer.bits);

                                    const uint8_t* in =
                                            static_cast<const uint8_t*>(
                                                    color_frame.get_data());

                                    for (int y = 0;
                                         y < height;
                                         ++y) {

                                        memcpy(
                                                out +
                                                y *
                                                        buffer.stride *
                                                        4,

                                                in +
                                                y *
                                                        width *
                                                        4,

                                                width * 4);
                                    }
                                }

                                // -------------------------------------------------
                                // DEPTH
                                // -------------------------------------------------

                                float center_distance =
                                        0.0f;

                                double depth_render_ms =
                                        0.0;

                                if (depth_frame) {

                                    int dwidth =
                                            depth_frame.get_width();

                                    int dheight =
                                            depth_frame.get_height();

                                    // Robust center distance:
                                    // Use an 11x11 ROI and median of valid depth
                                    // samples instead of a single depth pixel.
                                    center_distance = 0.0f;

                                    const int cx = dwidth / 2;
                                    const int cy = dheight / 2;

                                    std::vector<float> center_depths;
                                    center_depths.reserve(121);

                                    for (int dy = -5; dy <= 5; ++dy) {
                                        for (int dx = -5; dx <= 5; ++dx) {

                                            const int x = cx + dx;
                                            const int y = cy + dy;

                                            if (x < 0 || x >= dwidth ||
                                                y < 0 || y >= dheight) {
                                                continue;
                                            }

                                            const float d =
                                                    depth_frame.get_distance(x, y);

                                            // Valid D455 depth only:
                                            // 10 cm to 10 m.
                                            if (std::isfinite(d) &&
                                                d >= 0.10f &&
                                                d <= 10.0f) {
                                                center_depths.push_back(d);
                                            }
                                        }
                                    }

                                    if (!center_depths.empty()) {
                                        std::sort(
                                                center_depths.begin(),
                                                center_depths.end());

                                        center_distance =
                                                center_depths[
                                                        center_depths.size() / 2];
                                    }

                                    if (depthNativeWindow) {

                                        const auto depth_start =
                                                std::chrono::steady_clock::now();

                                        rs2::frame colorized_depth =
                                                color_map.process(
                                                        depth_frame);

                                        ANativeWindow_Buffer dbuffer;

                                        if (ANativeWindow_lock(
                                                    depthNativeWindow,
                                                    &dbuffer,
                                                    nullptr) == 0) {

                                            if (dbuffer.width >= dwidth &&
                                                dbuffer.height >= dheight) {

                                                const uint8_t* in =
                                                        static_cast<
                                                                const uint8_t*>(
                                                                colorized_depth
                                                                        .get_data());

                                                uint8_t* out =
                                                        static_cast<uint8_t*>(
                                                                dbuffer.bits);

                                                for (int y = 0;
                                                     y < dheight;
                                                     ++y) {

                                                    for (int x = 0;
                                                         x < dwidth;
                                                         ++x) {

                                                        int out_idx =
                                                                y *
                                                                        dbuffer.stride *
                                                                        4 +
                                                                x * 4;

                                                        int in_idx =
                                                                y *
                                                                        dwidth *
                                                                        3 +
                                                                x * 3;

                                                        out[out_idx + 0] =
                                                                in[in_idx + 0];

                                                        out[out_idx + 1] =
                                                                in[in_idx + 1];

                                                        out[out_idx + 2] =
                                                                in[in_idx + 2];

                                                        out[out_idx + 3] =
                                                                255;
                                                    }
                                                }
                                            }

                                            ANativeWindow_unlockAndPost(
                                                    depthNativeWindow);
                                        }

                                        const auto depth_end =
                                                std::chrono::steady_clock::now();

                                        depth_render_ms =
                                                std::chrono::duration<
                                                        double,
                                                        std::milli>(
                                                        depth_end -
                                                        depth_start)
                                                        .count();
                                    }
                                }

                                // -------------------------------------------------
                                // TELEMETRY
                                // -------------------------------------------------

                                std::string detections_json =
                                        "[]";

                                std::lock_guard<std::mutex> lock(
                                        telemetry_mutex);

                                std::ostringstream telemetry_stream;
                                telemetry_stream
                                        << "{\"fps\": " << std::fixed << std::setprecision(1)
                                        << current_fps.load()
                                        << ", \"p50\": " << read_latency_p50()
                                        << ", \"p95\": " << read_latency_p95()
                                        << ", \"p99\": " << read_latency_p99()
                                        << ", \"cpuClockMhz\": " << read_cpu_clock_max_mhz()
                                        << ", \"thermal\": " << read_max_thermal_celsius()
                                        << ", \"cpuThermalZones\": "
                                        << read_cpu_thermal_zones_json()
                                        << ", \"battery\": " << read_battery_percent()
                                        << ", \"centerDistance\": " << std::setprecision(2)
                                        << latency
                                        << ", \"droppedFrames\": " << total_dropped_frames
                                        << ", \"imu\": {"
                                        << "\"gyro\": ["
                                        << std::setprecision(5)
                                        << latest_gyro_data.x << ", "
                                        << latest_gyro_data.y << ", "
                                        << latest_gyro_data.z << "], "
                                        << "\"accel\": ["
                                        << latest_accel_data.x << ", "
                                        << latest_accel_data.y << ", "
                                        << latest_accel_data.z << "], "
                                        << "\"gyroTimestampMs\": "
                                        << std::setprecision(3)
                                        << latest_gyro_timestamp_ms
                                        << ", \"accelTimestampMs\": "
                                        << latest_accel_timestamp_ms
                                        << ", \"gyroCount\": "
                                        << static_cast<unsigned long long>(
                                                imu_gyro_count.load())
                                        << ", \"accelCount\": "
                                        << static_cast<unsigned long long>(
                                                imu_accel_count.load())
                                        << "}, "
                                        << "\"detections\": "
                                        << detections_json
                                        << "}";

                                std::string telemetry_string =
                                        telemetry_stream.str();

                                std::snprintf(
                                        telemetry_json,
                                        sizeof(telemetry_json),
                                        "%s",
                                        telemetry_string.c_str());

                                ANativeWindow_unlockAndPost(
                                        nativeWindow);

                                const auto rgb_render_end =
                                        std::chrono::steady_clock::now();

                                rgb_render_ms =
                                        std::chrono::duration<
                                                double,
                                                std::milli>(
                                                rgb_render_end -
                                                rgb_render_start)
                                                .count();

                                // -------------------------------------------------
                                // TOTAL FRAME LOOP TIMING
                                // -------------------------------------------------

                                const auto frame_loop_end =
                                        std::chrono::steady_clock::now();

                                const double total_loop_ms =
                                        std::chrono::duration<
                                                double,
                                                std::milli>(
                                                frame_loop_end -
                                                frame_loop_start)
                                                .count();

                                LOGI(
                                        "FRAME_TIMING "
                                        "wait=%.1fms "
                                        "rgb_copy=%.1fms "
                                        "rgb_render=%.1fms "
                                        "depth_render=%.1fms "
                                        "total=%.1fms "
                                        "fps=%.1f",

                                        wait_ms,

                                        rgb_copy_ms,

                                        rgb_render_ms,

                                        depth_render_ms,

                                        total_loop_ms,

                                        current_fps.load());
                            }
                        }

                    } catch (const std::exception& e) {

                        LOGE(
                                "Frame loop exception: %s",
                                e.what());
                    }
                }
            }

            LOGI(
                    "Native stream thread stopped!");
        });

    } catch (const std::exception& e) {

        LOGE(
                "Failed to start pipeline: %s",
                e.what());
    }
}

// ============================================================================
// CAPTURE CURRENT RGB FRAME
// ============================================================================

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_captureCurrentRgbFrame(
        JNIEnv* env,
        jobject /* this */) {

    std::vector<uint8_t> frame_copy;

    int width = 0;
    int height = 0;

    {
        std::lock_guard<std::mutex> lock(
                latest_rgb_mutex);

        if (latest_rgb_frame.empty()) {

            LOGE(
                    "captureCurrentRgbFrame: "
                    "no latest RGB frame available");

            return nullptr;
        }

        frame_copy =
                latest_rgb_frame;

        width =
                latest_rgb_width;

        height =
                latest_rgb_height;
    }

    const size_t byte_count =
            frame_copy.size();

    jbyteArray result =
            env->NewByteArray(
                    static_cast<jsize>(
                            byte_count));

    if (!result) {

        LOGE(
                "captureCurrentRgbFrame: "
                "failed to allocate byte array");

        return nullptr;
    }

    env->SetByteArrayRegion(
            result,
            0,
            static_cast<jsize>(
                    byte_count),
            reinterpret_cast<const jbyte*>(
                    frame_copy.data()));

    LOGI(
            "captureCurrentRgbFrame: "
            "latest frame %dx%d, %zu bytes",
            width,
            height,
            byte_count);

    return result;
}

// ============================================================================
// STOP PIPELINE
// ============================================================================

extern "C" JNIEXPORT void JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_stopPipeline(
        JNIEnv* env,
        jobject /* this */) {

    if (!isStreaming)
        return;

    isStreaming = false;

    if (streamThread.joinable()) {

        streamThread.join();
    }

    if (rs_pipe) {

        try {

            rs_pipe->stop();

        } catch (...) {}

        rs_pipe.reset();
    }
}

// ============================================================================
// SET STAGE
// ============================================================================

extern "C" JNIEXPORT void JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_setStage(
        JNIEnv* env,
        jobject /* this */,
        jint stage) {

    currentStage = stage;

    LOGI(
            "Pipeline Stage set to %d",
            currentStage);
}

// ============================================================================
// POLL TELEMETRY
// ============================================================================

extern "C" JNIEXPORT jstring JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_pollTelemetry(
        JNIEnv* env,
        jobject /* this */) {

    if (!isStreaming) {

        return env->NewStringUTF("{}");
    }

    std::string current_telemetry;

    {
        std::lock_guard<std::mutex> lock(
                telemetry_mutex);

        current_telemetry =
                telemetry_json;
    }

    return env->NewStringUTF(
            current_telemetry.c_str());
}

// ============================================================================
// SET RGB NATIVE WINDOW
// ============================================================================

extern "C" JNIEXPORT void JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_setNativeWindow(
        JNIEnv* env,
        jobject /* this */,
        jobject surface) {

    if (nativeWindow) {

        ANativeWindow_release(
                nativeWindow);

        nativeWindow = nullptr;
    }

    if (surface) {

        nativeWindow =
                ANativeWindow_fromSurface(
                        env,
                        surface);

        LOGI(
                "ANativeWindow set successfully!");
    }
}

// ============================================================================
// RELEASE RGB NATIVE WINDOW
// ============================================================================

extern "C" JNIEXPORT void JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_releaseNativeWindow(
        JNIEnv* env,
        jobject /* this */) {

    if (nativeWindow) {

        ANativeWindow_release(
                nativeWindow);

        nativeWindow = nullptr;
    }
}

// ============================================================================
// SET DEPTH NATIVE WINDOW
// ============================================================================

extern "C" JNIEXPORT void JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_setDepthNativeWindow(
        JNIEnv* env,
        jobject /* this */,
        jobject surface) {

    if (depthNativeWindow) {

        ANativeWindow_release(
                depthNativeWindow);

        depthNativeWindow = nullptr;
    }

    if (surface) {

        depthNativeWindow =
                ANativeWindow_fromSurface(
                        env,
                        surface);

        LOGI(
                "Depth ANativeWindow set successfully!");
    }
}

// ============================================================================
// RELEASE DEPTH NATIVE WINDOW
// ============================================================================

extern "C" JNIEXPORT void JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_releaseDepthNativeWindow(
        JNIEnv* env,
        jobject /* this */) {

    if (depthNativeWindow) {

        ANativeWindow_release(
                depthNativeWindow);

        depthNativeWindow = nullptr;
    }
}

// ============================================================================
// CAPTURE CURRENT DEPTH FRAME
// ============================================================================

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_hsv2_hsv2_1lite_MainActivity_captureCurrentDepthFrame(
        JNIEnv* env,
        jobject /* this */) {

    std::vector<uint16_t> frame_copy;

    int width = 0;
    int height = 0;

    {
        std::lock_guard<std::mutex> lock(
                latest_depth_mutex);

        if (latest_depth_frame.empty()) {

            LOGE(
                    "captureCurrentDepthFrame: "
                    "no latest depth frame available");

            return nullptr;
        }

        frame_copy =
                latest_depth_frame;

        width =
                latest_depth_width;

        height =
                latest_depth_height;
    }

    const size_t byte_count =
            frame_copy.size() *
            sizeof(uint16_t);

    jbyteArray result =
            env->NewByteArray(
                    static_cast<jsize>(
                            byte_count));

    if (!result) {

        LOGE(
                "captureCurrentDepthFrame: "
                "failed to allocate byte array");

        return nullptr;
    }

    env->SetByteArrayRegion(
            result,
            0,
            static_cast<jsize>(
                    byte_count),
            reinterpret_cast<const jbyte*>(
                    frame_copy.data()));

    LOGI(
            "captureCurrentDepthFrame: "
            "latest frame %dx%d, %zu bytes",
            width,
            height,
            byte_count);

    return result;
}
