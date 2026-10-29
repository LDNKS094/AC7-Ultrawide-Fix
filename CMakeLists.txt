cmake_minimum_required(VERSION 3.20)
cmake_policy(SET CMP0091 NEW)
project(AC7UltrawideFix VERSION 1.2.3 LANGUAGES C CXX)
if(NOT WIN32 OR NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "Build with the x64 MSVC toolchain on Windows.")
endif()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# Dependencies are vendored: no network access or submodules needed.
add_library(minhook STATIC
    third_party/minhook/src/buffer.c
    third_party/minhook/src/hook.c
    third_party/minhook/src/trampoline.c
    third_party/minhook/src/hde/hde64.c)
target_include_directories(minhook PUBLIC third_party/minhook/include)
add_library(dxbc_hash STATIC third_party/dxbc-hash/DxilHash.cpp)

add_library(ac7sceneprojection SHARED src/scene_projection.cpp)
set_target_properties(ac7sceneprojection PROPERTIES OUTPUT_NAME AC7SceneProjection PREFIX "" SUFFIX ".asi")
target_link_libraries(ac7sceneprojection PRIVATE minhook)
add_library(ac7hudcenter SHARED src/hud_center.cpp)
set_target_properties(ac7hudcenter PROPERTIES OUTPUT_NAME AC7HUDCenter PREFIX "" SUFFIX ".asi")
target_link_libraries(ac7hudcenter PRIVATE minhook dxbc_hash d3d11 d3dcompiler)
foreach(target IN ITEMS ac7sceneprojection ac7hudcenter)
    set_target_properties(${target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/payload")
    target_compile_options(${target} PRIVATE /W4 /O2)
endforeach()
