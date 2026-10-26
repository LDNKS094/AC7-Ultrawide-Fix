#include "hud_shader_transform.h"
#include <d3d11.h>
#include <cstdio>
#include <cstdlib>
static void Check(bool value,const char* text){if(!value){std::fprintf(stderr,"FAIL: %s\n",text);std::exit(1);}}
int main(){
    uint32_t reg=0,component=0;
    const std::string assembly="ps_5_0\nmul r0.y, cb1[127].y, l(1.77777779)\ndiv r0.y, cb1[127].x, r0.y\nmovc r1.x, r0.x, r0.y, r1.y\nret\n";
    Check(ac7hud::FindCoordinate(assembly,reg,component)&&reg==1&&component==0,"select the coordinate after aspect calculation");
    Check(!ac7hud::FindCoordinate("ps_5_0\nmov o0.xyzw, l(1,1,1,1)\nret",reg,component),"unrelated shader untouched");
    const char* hlsl="cbuffer cb1:register(b1){float4 cb1[129];}; Texture2D img:register(t0);SamplerState smp:register(s0);float4 main(float2 uv:TEXCOORD):SV_Target {float altered=uv.x*cb1[127].x/(1.77777779*cb1[127].y);float x=cb1[127].y>1?altered:uv.x;return img.Sample(smp,float2(x,uv.y));}";
    ID3DBlob *shader=nullptr,*error=nullptr,*disassembly=nullptr;
    const auto compiled=D3DCompile(hlsl,std::strlen(hlsl),"test",nullptr,nullptr,"main","ps_5_0",D3DCOMPILE_OPTIMIZATION_LEVEL3,0,&shader,&error);
    if(error){std::fprintf(stderr,"%s",static_cast<const char*>(error->GetBufferPointer()));error->Release();}
    Check(SUCCEEDED(compiled)&&shader,"sample compiles");
    Check(SUCCEEDED(D3DDisassemble(shader->GetBufferPointer(),shader->GetBufferSize(),0,nullptr,&disassembly)),"sample disassembles");
    const std::string text(static_cast<const char*>(disassembly->GetBufferPointer()),disassembly->GetBufferSize());
    Check(ac7hud::FindCoordinate(text,reg,component),"actual compiler signature matched");
    const auto* original=static_cast<const uint8_t*>(shader->GetBufferPointer());
    const auto size=shader->GetBufferSize();
    std::vector<uint8_t> rebuilt;
    Check(ac7hud::PatchDxbc(original,size,text,-0.5f,rebuilt),"direct instruction insertion validated");
    Check(rebuilt.size()==size+28,"exactly one seven-word ADD inserted");
    for(uint32_t i=0;i<ac7hud::Read32(original+28);++i){
        const auto oldAt=ac7hud::Read32(original+32+i*4),newAt=ac7hud::Read32(rebuilt.data()+32+i*4);
        if(!ac7hud::InstructionChunk(original+oldAt))
            Check(!std::memcmp(original+oldAt,rebuilt.data()+newAt,8+ac7hud::Read32(original+oldAt+4)),"signature/reflection/other chunks byte-identical");
    }
    ID3DBlob* patchedText=nullptr;
    Check(SUCCEEDED(D3DDisassemble(rebuilt.data(),rebuilt.size(),0,nullptr,&patchedText)),"patched shader disassembles");
    const std::string patched(static_cast<const char*>(patchedText->GetBufferPointer()),patchedText->GetBufferSize());
    const std::string target="r"+std::to_string(reg)+"."+std::string(1,"xyzw"[component]);
    const auto selection=patched.find("movc "+target+",");
    const auto following=patched.find('\n',selection);
    Check(selection!=std::string::npos&&patched.compare(following+1,4+target.size(),"add "+target)==0,"ADD follows the coordinate selection");
    Check(patched.find("l(-0.500000)",following)!=std::string::npos,"centering shift preserved");
    std::vector<uint8_t> malformed(original,original+size),unused;
    ac7hud::Write32(malformed,28,129);
    Check(!ac7hud::PatchDxbc(malformed.data(),malformed.size(),text,-0.5f,unused),"oversized chunk table rejected");
    malformed.assign(original,original+size);ac7hud::Write32(malformed,32,static_cast<uint32_t>(size));
    Check(!ac7hud::PatchDxbc(malformed.data(),malformed.size(),text,-0.5f,unused),"out-of-bounds chunk rejected");
    Check(!ac7hud::PatchDxbc(original,size-1,text,-0.5f,unused),"truncated container rejected");
    ID3D11Device* device=nullptr;ID3D11DeviceContext* context=nullptr;
    Check(SUCCEEDED(D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_WARP,nullptr,0,nullptr,0,D3D11_SDK_VERSION,&device,nullptr,&context)),"WARP device available");
    ID3D11PixelShader* pixel=nullptr;
    Check(SUCCEEDED(device->CreatePixelShader(rebuilt.data(),rebuilt.size(),nullptr,&pixel))&&pixel,"D3D11 accepts bytecode/checksum");
    pixel->Release();context->Release();device->Release();patchedText->Release();disassembly->Release();shader->Release();
    std::puts("PASS: one post-selection ADD, unchanged metadata, malformed-input protection and D3D11 WARP validation.");
}
