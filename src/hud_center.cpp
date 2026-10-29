// Preserve original HUD shaders; insert only the legacy screen-coordinate centering ADD.
// No Draw/Present hooks, shader-template replacement, camera changes or scene polling.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <MinHook.h>
#include <fstream>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>
#include "hud_shader_transform.h"
namespace {
std::string root;
std::ofstream output;
std::mutex logMutex;
float shift=0;
using CreatePS=HRESULT(STDMETHODCALLTYPE*)(ID3D11Device*,const void*,SIZE_T,ID3D11ClassLinkage*,ID3D11PixelShader**);
CreatePS original=nullptr;
void Log(const std::string& message){
    std::lock_guard<std::mutex> lock(logMutex);
    if(!output.is_open()) output.open(root+"AC7HUDCenter.log",std::ios::trunc);
    output<<message<<'\n'<<std::flush;
}
bool HasAspectLiteral(const void* data,size_t size){
    auto* bytes=static_cast<const uint8_t*>(data);
    const uint32_t expected=0x3fe38e39u;
    for(size_t i=0;i+4<=size;i+=4) if(ac7hud::Read32(bytes+i)==expected) return true;
    return false;
}
HRESULT STDMETHODCALLTYPE Hook(ID3D11Device* device,const void* data,SIZE_T size,ID3D11ClassLinkage* linkage,ID3D11PixelShader** shader){
    if(!data||size<32||size>1024*1024||shift==0||!HasAspectLiteral(data,size)) return original(device,data,size,linkage,shader);
    try {
        ID3DBlob* assembly=nullptr;
        if(FAILED(D3DDisassemble(data,size,0,nullptr,&assembly))||!assembly) return original(device,data,size,linkage,shader);
        std::string text(static_cast<const char*>(assembly->GetBufferPointer()),assembly->GetBufferSize());
        assembly->Release();
        std::vector<uint8_t> replacement;
        if(!ac7hud::PatchDxbc(static_cast<const uint8_t*>(data),size,text,shift,replacement)) return original(device,data,size,linkage,shader);
        const auto hr=original(device,replacement.data(),replacement.size(),linkage,shader);
        if(SUCCEEDED(hr)) return hr;
        std::ostringstream failure;failure<<"HUD shader creation rejected 0x"<<std::hex<<static_cast<unsigned>(hr)<<"; original retained";Log(failure.str());
    } catch(...) { Log("HUD transformation exception; original retained"); }
    return original(device,data,size,linkage,shader);
}
DWORD WINAPI Start(LPVOID){
    // Limitation: HUD uses the primary display's aspect ratio at startup; independent windows and live resolution changes are not tracked.
    const int width=GetSystemMetrics(SM_CXSCREEN),height=GetSystemMetrics(SM_CYSCREEN);
    if(width<=0||height<=0) {Log("Invalid display dimensions; disabled");return 0;}
    const double aspect=double(width)/height;
    if(aspect<=16.0/9.0+0.01||aspect>8) return 0;
    shift=static_cast<float>(-(aspect/(16.0/9.0)-1.0)/2.0);
    ID3D11Device* device=nullptr;ID3D11DeviceContext* context=nullptr;
    const auto result=D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_HARDWARE,nullptr,0,nullptr,0,D3D11_SDK_VERSION,&device,nullptr,&context);
    if(FAILED(result)||!device){Log("D3D11 device setup unavailable; no hook installed");return 0;}
    void* target=(*reinterpret_cast<void***>(device))[15];
    const auto initialized=MH_Initialize();
    if((initialized!=MH_OK&&initialized!=MH_ERROR_ALREADY_INITIALIZED)
        ||MH_CreateHook(target,reinterpret_cast<void*>(Hook),reinterpret_cast<void**>(&original))!=MH_OK
        ||MH_EnableHook(target)!=MH_OK){Log("CreatePixelShader hook setup failed; original shaders retained");}
    if(context)context->Release();device->Release();
    return 0;
}
}
BOOL APIENTRY DllMain(HMODULE module,DWORD reason,LPVOID){
    if(reason==DLL_PROCESS_ATTACH){
        DisableThreadLibraryCalls(module);
        char exe[MAX_PATH]{};GetModuleFileNameA(nullptr,exe,MAX_PATH);root=exe;root=root.substr(0,root.rfind('\\')+1);
        const auto thread=CreateThread(nullptr,0,Start,nullptr,0,nullptr);if(thread)CloseHandle(thread);
    }
    return TRUE;
}
