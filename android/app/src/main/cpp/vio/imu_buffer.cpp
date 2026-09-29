#include "imu_buffer.h"

#include <algorithm>

namespace hsv2 {

ImuBuffer::ImuBuffer(std::size_t max_samples)
    : max_samples_(max_samples) {}

void ImuBuffer::pushGyro(
    double timestamp_ms,
    const Vec3& gyro) {

    std::lock_guard<std::mutex> lock(mutex_);

    ImuSample sample;
    sample.timestamp_ms = timestamp_ms;
    sample.gyro = gyro;
    sample.has_gyro = true;

    samples_.push_back(sample);

    while (samples_.size() > max_samples_) {
        samples_.pop_front();
    }
}

void ImuBuffer::pushAccel(
    double timestamp_ms,
    const Vec3& accel) {

    std::lock_guard<std::mutex> lock(mutex_);

    ImuSample sample;
    sample.timestamp_ms = timestamp_ms;
    sample.accel = accel;
    sample.has_accel = true;

    samples_.push_back(sample);

    while (samples_.size() > max_samples_) {
        samples_.pop_front();
    }
}

std::vector<ImuSample> ImuBuffer::getRange(
    double start_timestamp_ms,
    double end_timestamp_ms) const {

    std::lock_guard<std::mutex> lock(mutex_);

    std::vector<ImuSample> result;

    for (const auto& sample : samples_) {
        if (sample.timestamp_ms >= start_timestamp_ms &&
            sample.timestamp_ms <= end_timestamp_ms) {
            result.push_back(sample);
        }
    }

    return result;
}

std::size_t ImuBuffer::size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return samples_.size();
}

void ImuBuffer::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    samples_.clear();
}

}  // namespace hsv2
