#pragma once

#include <cstdint>
#include <mutex>

#include "imu_buffer.h"
#include "vio_types.h"

namespace hsv2 {

class VioEngine {
public:
    VioEngine();

    bool initialize(
        int image_width,
        int image_height,
        double fx,
        double fy,
        double cx,
        double cy);

    void addGyro(
        double timestamp_ms,
        const Vec3& gyro);

    void addAccel(
        double timestamp_ms,
        const Vec3& accel);

    bool addImage(
        double timestamp_ms,
        const uint8_t* rgba,
        int width,
        int height);

    VioPose getPose() const;

    VioTiming getTiming() const;

    bool isInitialized() const;

private:
    bool initialized_ = false;

    int image_width_ = 0;
    int image_height_ = 0;

    double fx_ = 0.0;
    double fy_ = 0.0;
    double cx_ = 0.0;
    double cy_ = 0.0;

    ImuBuffer imu_buffer_;

    VioPose pose_;
    VioTiming timing_;

    mutable std::mutex mutex_;
};

}  // namespace hsv2
