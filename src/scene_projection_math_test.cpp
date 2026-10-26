#include "scene_projection_math.h"
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <initializer_list>

static void Check(bool condition, const char* description) {
    if (!condition) { std::fprintf(stderr, "FAIL: %s\n", description); std::exit(1); }
}
int main() {
    const float standard = 16.0f / 9.0f;
    const float wide = 32.0f / 9.0f;
    float result = 0;
    Check(ac7scene::WiderHorizontalFov(90, standard, wide, result), "32:9 camera is eligible");
    Check(std::fabs(result - 126.8699f) < 0.001f, "90 degree camera expands to expected angle");
    for (float input : {35.4f, 63.0f, 73.73979f, 74.0f, 90.0f}) {
        Check(ac7scene::WiderHorizontalFov(input, standard, wide, result), "observed cinematic/hangar/flight FOV supported");
        const float originalVertical = 2.0f * std::atan(std::tan(input * ac7scene::Pi / 360.0f) / standard);
        const float adjustedVertical = 2.0f * std::atan(std::tan(result * ac7scene::Pi / 360.0f) / wide);
        Check(std::fabs(originalVertical - adjustedVertical) < 0.00001f, "vertical view retained without cropping");
    }
    Check(!ac7scene::WiderHorizontalFov(90, standard, standard, result), "16:9 stays unchanged");
    Check(!ac7scene::WiderHorizontalFov(90, standard, 4.0f/3.0f, result), "narrower views stay unchanged");
    Check(!ac7scene::WiderHorizontalFov(0, standard, wide, result), "zero FOV rejected");
    Check(!ac7scene::WiderHorizontalFov(90, 0, wide, result), "invalid original aspect rejected");
    Check(!ac7scene::WiderHorizontalFov(std::numeric_limits<float>::quiet_NaN(), standard, wide, result), "NaN rejected");
    Check(!ac7scene::WiderHorizontalFov(90, standard, std::numeric_limits<float>::infinity(), result), "infinite viewport rejected");
    std::puts("PASS: observed flight/hangar/cinematic FOVs, vertical-view preservation, 16:9 passthrough and invalid-input rejection.");
}
