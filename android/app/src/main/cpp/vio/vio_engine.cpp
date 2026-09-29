#include "vio_engine.h"

#include <chrono>

namespace hsv2 {

VioEngine::VioEngine()
    : imu_buffer_(4000) {}

bool VioEngine::initialize(
    int image_width,
    int image_height,
    double fx,
    double fy,
    double cx,
    double cy) {

    std::lock_guard<std::mutex> lock(mutex_);

    image_width_ = image_width;
    image_height_ = image_height;

    fx_ = fx;
    fy_ = fy;
    cx_ = cx;
    cy_ = cy;

    pose_ = VioPose{};
    timing_ = VioTiming{};

    initialized_ = true;

    return true;
}

void VioEngine::addGyro(
    double timestamp_ms,
    const Vec3& gyro) {

    imu_buffer_.pushGyro(timestamp_ms, gyro);

    std::lock_guard<std::mutex> lock(mutex_);
    ++timing_.imu_count;
}

void VioEngine::addAccel(
    double timestamp_ms,
    const Vec3& accel) {

    imu_buffer_.pushAccel(timestamp_ms, accel);

    std::lock_guard<std::mutex> lock(mutex_);
    ++timing_.imu_count;
}

bool VioEngine::addImage(
    double timestamp_ms,
    const uint8_t* rgba,
    int width,
    int height) {

    if (!initialized_ || rgba == nullptr ||
        width <= 0 || height <= 0) {
        return false;
    }

    const auto start =
        std::chrono::steady_clock::now();

    /*
     * VIO algorithm insertion point.
     *
     * This module currently provides:
     *   - camera calibration input
     *   - timestamped IMU buffering
     *   - timestamped image input
     *   - pose/timing output interface
     *
     * The actual visual-inertial estimator must be
     * connected here before Stage 4 is reported as
     * actual VIO.
     */

    const auto end =
        std::chrono::steady_clock::now();

    const double elapsed_ms =
        std::chrono::duration<double, std::milli>(
            end - start).count();

    std::lock_guard<std::mutex> lock(mutex_);

    pose_.timestamp_ms = timestamp_ms;
    timing_.processing_ms = elapsed_ms;
    ++timing_.image_count;

    return true;
}

VioPose VioEngine::getPose() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return pose_;
}

VioTiming VioEngine::getTiming() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return timing_;
}

bool VioEngine::isInitialized() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return initialized_;
}

}  // namespace hsv2
