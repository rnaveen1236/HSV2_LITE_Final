#pragma once

#include <cstddef>
#include <deque>
#include <mutex>
#include <vector>

#include "vio_types.h"

namespace hsv2 {

class ImuBuffer {
public:
    explicit ImuBuffer(std::size_t max_samples = 4000);

    void pushGyro(double timestamp_ms, const Vec3& gyro);
    void pushAccel(double timestamp_ms, const Vec3& accel);

    std::vector<ImuSample> getRange(
        double start_timestamp_ms,
        double end_timestamp_ms) const;

    std::size_t size() const;
    void clear();

private:
    std::deque<ImuSample> samples_;
    std::size_t max_samples_;
    mutable std::mutex mutex_;
};

}  // namespace hsv2
