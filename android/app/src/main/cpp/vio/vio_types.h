#pragma once

#include <cstdint>

namespace hsv2 {

struct Vec3 {
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
};

struct ImuSample {
    double timestamp_ms = 0.0;
    Vec3 gyro;
    Vec3 accel;
    bool has_gyro = false;
    bool has_accel = false;
};

struct VioPose {
    double timestamp_ms = 0.0;

    Vec3 position;
    Vec3 velocity;

    // Quaternion: x, y, z, w
    double qx = 0.0;
    double qy = 0.0;
    double qz = 0.0;
    double qw = 1.0;

    bool valid = false;
};

struct VioTiming {
    double processing_ms = 0.0;
    uint64_t image_count = 0;
    uint64_t imu_count = 0;
};

}  // namespace hsv2
