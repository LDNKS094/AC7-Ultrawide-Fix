// Exercise the actual projection wrapper with an engine-function stub.
#define AC7_PROJECTION_TEST
#include "scene_projection.cpp"
#include <array>
#include <cstdio>
#include <cstdlib>

namespace {
unsigned calls = 0;
float observedFov = 0, observedAspect = 0;
uint8_t observedFlags = 0, observedAxis = 255;
void* observedView = nullptr;

void __fastcall FakeProject(void* view, const uint8_t* axis, void*, void*) {
    ++calls;
    observedView = view;
    observedAxis = axis ? *axis : 255;
    if (view) {
        auto* bytes = static_cast<uint8_t*>(view);
        std::memcpy(&observedFov, bytes + 0x18, sizeof(float));
        std::memcpy(&observedAspect, bytes + 0x28, sizeof(float));
        observedFlags = bytes[0x2c];
    }
}
void Check(bool condition, const char* text) {
    if (!condition) { std::fprintf(stderr, "FAIL: %s\n", text); std::exit(1); }
}
}
int main() {
    original = FakeProject;
    std::array<uint8_t, 0x600> view{};
    std::array<uint8_t, 0x100> data{};
    auto setup = [&](int w, int h, uint8_t mode=0, uint8_t flags=5) {
        view.fill(0); data.fill(0);
        float fov=90, aspect=16.0f/9.0f;
        std::memcpy(view.data()+0x18,&fov,4);
        std::memcpy(view.data()+0x28,&aspect,4);
        view[0x2c]=flags; view[0x30]=mode;
        int32_t rectangle[4]={0,0,w,h};
        std::memcpy(data.data()+0xc0,rectangle,sizeof(rectangle));
        calls=0;
    };
    const uint8_t incomingAxis=2;
    setup(5120,1440);
    const auto originalView=view;
    Projection(view.data(),&incomingAxis,nullptr,data.data());
    Check(calls==1,"engine projection called once");
    Check(std::fabs(observedFov-126.8699f)<0.001f,"wide perspective gets correct horizontal FOV");
    Check(std::fabs(observedAspect-32.0f/9.0f)<0.00001f,"actual view rectangle determines aspect");
    Check(observedFlags==4,"only constraint bit cleared during call");
    Check(observedAxis==1,"horizontal projection rule used during call");
    Check(view==originalView,"all original camera bytes restored after call");
    Check(!std::memcmp(data.data()+0xc0,data.data()+0xd0,16),"full view rectangle emitted");
    Check(incomingAxis==2,"caller's axis rule unchanged");

    setup(2560,1440);
    auto stock=view;
    Projection(view.data(),&incomingAxis,nullptr,data.data());
    Check(calls==1 && observedFov==90 && observedAxis==2 && view==stock,"16:9 view passes through");
    setup(5120,1440,1);
    stock=view;
    Projection(view.data(),&incomingAxis,nullptr,data.data());
    Check(calls==1 && observedFlags==5 && observedAxis==2 && view==stock,"orthographic UI view passes through");
    setup(5120,1440,0,4);
    stock=view;
    Projection(view.data(),&incomingAxis,nullptr,data.data());
    Check(calls==1 && observedFov==90 && observedAxis==2 && view==stock,"already-unconstrained view passes through");
    setup(200,100);
    stock=view;
    Projection(view.data(),&incomingAxis,nullptr,data.data());
    Check(calls==1 && observedFov==90 && observedAxis==2 && view==stock,"small utility viewport passes through");
    calls=0;
    Projection(nullptr,&incomingAxis,nullptr,nullptr);
    Check(calls==1 && observedView==nullptr,"missing view is delegated without access");
    std::puts("PASS: actual wrapper uses viewport-specific perspective correction, restores camera data, and preserves orthographic/16:9/unconstrained/small/null views without scene state.");
}
