#pragma once
#include <d3dcompiler.h>
#include <cstdint>
#include <cstring>
#include <regex>
#include <string>
#include <vector>

void ComputeHashRetail(const BYTE*,UINT,BYTE*);
namespace ac7hud {
inline uint32_t Read32(const uint8_t* data){uint32_t value;std::memcpy(&value,data,4);return value;}
inline void Write32(std::vector<uint8_t>& data,size_t at,uint32_t value){std::memcpy(data.data()+at,&value,4);}
inline bool InstructionChunk(const uint8_t* p){return !std::memcmp(p,"SHEX",4)||!std::memcmp(p,"SHDR",4);}
inline bool FindCoordinate(const std::string& source,uint32_t& reg,uint32_t& component){
    if(source.find("ps_5_0")==std::string::npos) return false;
    static const std::regex aspect(R"(mul\s+r[0-9]+\.[xyzw],\s*cb1\[127\]\.y,\s*l\(1\.77777[0-9]*\))");
    static const std::regex selection(R"(movc\s+r([0-9]{1,4})\.([xyzw]),)");
    std::smatch match;
    if(!std::regex_search(source,match,aspect)) return false;
    const auto start=source.cbegin()+match.position()+match.length();
    if(!std::regex_search(start,source.cend(),match,selection)) return false;
    reg=static_cast<uint32_t>(std::stoul(match[1].str()));
    component=static_cast<uint32_t>(std::string("xyzw").find(match[2].str()));
    return reg<4096;
}
inline bool PatchDxbc(const uint8_t* original,size_t size,const std::string& disassembly,float shift,std::vector<uint8_t>& result){
    uint32_t reg=0,component=0;
    if(!original||size<32||size>UINT32_MAX||std::memcmp(original,"DXBC",4)||Read32(original+24)!=size
        ||!FindCoordinate(disassembly,reg,component)) return false;
    const auto count=Read32(original+28);
    const size_t header=32+size_t(count)*4;
    if(count>128||header>size) return false;
    result.assign(original,original+header);
    bool replaced=false;
    for(uint32_t i=0;i<count;++i){
        const auto at=Read32(original+32+i*4);
        if(at<header||size_t(at)+8>size) return false;
        const auto length=Read32(original+at+4);
        if(length>size-at-8) return false;
        while(result.size()%4) result.push_back(0);
        Write32(result,32+i*4,static_cast<uint32_t>(result.size()));
        if(!InstructionChunk(original+at)){result.insert(result.end(),original+at,original+at+8+length);continue;}
        if(replaced||length<8||length%4) return false;
        std::vector<uint32_t> words(length/4);
        std::memcpy(words.data(),original+at+8,length);
        if(words[0]!=0x50||words[1]!=words.size()) return false;
        size_t insertion=0;uint32_t destination=0;unsigned matches=0;
        for(size_t p=2;p<words.size();){
            const auto instruction=words[p],opcode=instruction&0x7ffu;
            size_t n=(instruction>>24)&0x7fu;
            if(opcode==53){if(p+1>=words.size()||words[p+1]<2) return false;n=words[p+1];}
            if(n==0||n>words.size()-p) return false;
            // MOVC must have one simple, immediate-indexed temp destination.
            if(opcode==55&&n>=3&&!(instruction&0x80000000u)){
                const auto operand=words[p+1];
                if((operand&3u)==2u&&((operand>>2)&3u)==0&&((operand>>12)&0xffu)==0
                    &&((operand>>20)&3u)==1&&((operand>>22)&7u)==0&&!(operand&0x80000000u)
                    &&((operand>>4)&15u)==(1u<<component)&&words[p+2]==reg){
                    insertion=p+n;destination=operand;++matches;
                }
            }
            p+=n;
        }
        if(matches!=1) return false;
        uint32_t immediate;std::memcpy(&immediate,&shift,4);
        const uint32_t source=(destination&~0xffcu)|8u|(component<<4);
        const uint32_t add[]={0x07000000u,destination,reg,source,reg,0x00004001u,immediate};
        words.insert(words.begin()+insertion,add,add+7);words[1]+=7;
        const auto outputAt=result.size();
        result.insert(result.end(),original+at,original+at+8);
        Write32(result,outputAt+4,static_cast<uint32_t>(words.size()*4));
        const auto* bytes=reinterpret_cast<const uint8_t*>(words.data());
        result.insert(result.end(),bytes,bytes+words.size()*4);
        replaced=true;
    }
    if(!replaced) return false;
    Write32(result,24,static_cast<uint32_t>(result.size()));
    ComputeHashRetail(result.data()+20,static_cast<UINT>(result.size()-20),result.data()+4);
    ID3DBlob* checked=nullptr;
    const auto hr=D3DStripShader(result.data(),result.size(),0,&checked);
    if(FAILED(hr)||!checked){if(checked) checked->Release();return false;}
    const auto* bytes=static_cast<const uint8_t*>(checked->GetBufferPointer());
    result.assign(bytes,bytes+checked->GetBufferSize());
    checked->Release();
    return true;
}
}
