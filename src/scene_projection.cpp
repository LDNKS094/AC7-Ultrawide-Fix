// Per-call perspective projection adjustment. No scene polling, shared FOV constants or D3D shader replacements.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <MinHook.h>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <mutex>
#include <string>
#include "scene_projection_math.h"

namespace {
std::string root;
std::ofstream output;
std::mutex logMutex;
using Project = void(__fastcall*)(void*, const uint8_t*, void*, void*);
Project original = nullptr;

void Log(const std::string& text) {
    std::lock_guard<std::mutex> lock(logMutex);
    if (!output.is_open()) output.open(root + "AC7SceneProjection.log", std::ios::trunc);
    output << text << '\n' << std::flush;
}

struct CameraFields {
    uint8_t* view;
    float fov, aspect;
    uint8_t flags;
    explicit CameraFields(void* data) : view(static_cast<uint8_t*>(data)) {
        std::memcpy(&fov, view + 0x18, sizeof(fov));
        std::memcpy(&aspect, view + 0x28, sizeof(aspect));
        flags = view[0x2c];
    }
    ~CameraFields() {
        std::memcpy(view + 0x18, &fov, sizeof(fov));
        std::memcpy(view + 0x28, &aspect, sizeof(aspect));
        view[0x2c] = flags;
    }
};

void __fastcall Projection(void* view, const uint8_t* axis, void* viewport, void* data) {
    if (!view || !data) {
        original(view, axis, viewport, data);
        return;
    }
    auto* camera = static_cast<uint8_t*>(view);
    // This build's FMinimalViewInfo layout is checked by the unique code fingerprint.
    // Perspective only. An already unconstrained view is left untouched.
    if (camera[0x30] != 0 || (camera[0x2c] & 1) == 0) {
        original(view, axis, viewport, data);
        return;
    }
    int32_t rectangle[4];
    std::memcpy(rectangle, static_cast<uint8_t*>(data) + 0xc0, sizeof(rectangle));
    const int64_t width = int64_t(rectangle[2]) - rectangle[0];
    const int64_t height = int64_t(rectangle[3]) - rectangle[1];
    if (width < 640 || height < 360 || width > 32768 || height > 16384) {
        original(view, axis, viewport, data);
        return;
    }
    CameraFields saved(view);
    const float aspect = static_cast<float>(width) / static_cast<float>(height);
    float fov = 0;
    if (!ac7scene::WiderHorizontalFov(saved.fov, saved.aspect, aspect, fov)) {
        original(view, axis, viewport, data);
        return;
    }
    std::memcpy(camera + 0x18, &fov, sizeof(fov));
    std::memcpy(camera + 0x28, &aspect, sizeof(aspect));
    camera[0x2c] = static_cast<uint8_t>(saved.flags & ~1u);
    // GetProjectionData initially sets both rectangles to the full view.
    // Explicitly keep the full view as this call's constrained output.
    std::memcpy(static_cast<uint8_t*>(data) + 0xd0, rectangle, sizeof(rectangle));
    // Value 1 preserves the horizontal FOV.
    const uint8_t maintainHorizontal = 1;
    original(view, &maintainHorizontal, viewport, data);
    // CameraFields restores the original camera data even when other consumers use it later.
}

bool Readable(const MEMORY_BASIC_INFORMATION& memory) {
    return memory.State == MEM_COMMIT && !(memory.Protect & (PAGE_GUARD | PAGE_NOACCESS))
        && (memory.Protect & (PAGE_READONLY | PAGE_READWRITE | PAGE_WRITECOPY |
            PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY));
}

uint8_t* FindProjection() {
    auto* base = reinterpret_cast<uint8_t*>(GetModuleHandleW(nullptr));
    auto* dos = reinterpret_cast<IMAGE_DOS_HEADER*>(base);
    auto* nt = reinterpret_cast<IMAGE_NT_HEADERS64*>(base + dos->e_lfanew);
    const size_t size = nt->OptionalHeader.SizeOfImage;
    const uint8_t signature[] = {0x48,0x81,0xec,0xd0,0,0,0,0xf6,0x41,0x2c,1};
    const uint8_t prefix[] = {0x48,0x8b,0xc4,0x48,0x89,0x58,8,0x48,0x89,0x78,0x10,0x55,0x48,0x8d,0x68,0xa1};
    uint8_t* found = nullptr;
    unsigned matches = 0;
    for (size_t offset = 0; offset < size;) {
        MEMORY_BASIC_INFORMATION info{};
        if (!VirtualQuery(base + offset, &info, sizeof(info))) break;
        const auto start = reinterpret_cast<uintptr_t>(base + offset);
        auto end = reinterpret_cast<uintptr_t>(info.BaseAddress) + info.RegionSize;
        const auto imageEnd = reinterpret_cast<uintptr_t>(base) + size;
        if (end > imageEnd) end = imageEnd;
        if (end <= start) break;
        if (Readable(info)) {
            for (auto at = start; at + sizeof(signature) <= end; ++at) {
                if (*reinterpret_cast<const uint8_t*>(at) != signature[0]) continue;
                if (!std::memcmp(reinterpret_cast<void*>(at), signature, sizeof(signature))) {
                    found = reinterpret_cast<uint8_t*>(at);
                    ++matches;
                }
            }
        }
        offset = end - reinterpret_cast<uintptr_t>(base);
    }
    if (matches != 1 || found < base + sizeof(prefix)) return nullptr;
    DWORD64 imageBase = 0;
    auto* unwind = RtlLookupFunctionEntry(reinterpret_cast<DWORD64>(found), &imageBase, nullptr);
    if (!unwind) return nullptr;
    auto* entry = reinterpret_cast<uint8_t*>(imageBase + unwind->BeginAddress);
    if (entry + sizeof(prefix) != found || std::memcmp(entry, prefix, sizeof(prefix))) {
        Log("Projection fingerprint/unwind mismatch; refusing to hook");
        return nullptr;
    }
    return entry;
}

DWORD WINAPI Main(LPVOID) {
    Sleep(1000);
    uint8_t* target = nullptr;
    for (unsigned retry = 0; retry < 20 && !target; ++retry) {
        target = FindProjection();
        if (!target) Sleep(500);
    }
    if (!target) { Log("No supported unique projection function; all views remain stock"); return 0; }
    if (MH_Initialize() != MH_OK || MH_CreateHook(target, reinterpret_cast<void*>(Projection), reinterpret_cast<void**>(&original)) != MH_OK) {
        Log("Projection hook creation failed; all views remain stock"); return 0;
    }
    if (MH_EnableHook(target) != MH_OK) { Log("Projection hook enable failed; all views remain stock"); return 0; }
    return 0;
}
}

#ifndef AC7_PROJECTION_TEST
BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(module);
        char exe[MAX_PATH]{};
        GetModuleFileNameA(nullptr, exe, MAX_PATH);
        root=exe; root=root.substr(0,root.rfind('\\')+1);
        const auto thread=CreateThread(nullptr,0,Main,nullptr,0,nullptr);
        if(thread) CloseHandle(thread);
    }
    return TRUE;
}
#endif
