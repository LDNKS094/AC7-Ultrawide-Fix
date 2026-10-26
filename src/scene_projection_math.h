#pragma once
#include <cmath>

namespace ac7scene {
constexpr float Pi = 3.14159265358979323846f;
inline bool WiderHorizontalFov(float baseFov, float baseAspect, float targetAspect, float& result) {
    if (!std::isfinite(baseFov) || !std::isfinite(baseAspect) || !std::isfinite(targetAspect)
        || baseFov < 1.0f || baseFov >= 170.0f || baseAspect < 1.0f || baseAspect > 4.0f
        || targetAspect <= baseAspect + 0.01f || targetAspect > 8.0f) return false;
    result = 2.0f * std::atan(std::tan(baseFov * Pi / 360.0f) * targetAspect / baseAspect) * 180.0f / Pi;
    return std::isfinite(result) && result > baseFov && result < 179.0f;
}
}
