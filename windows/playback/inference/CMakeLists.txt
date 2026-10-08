cmake_minimum_required(VERSION 3.24)
project(bangumi_playback_inference LANGUAGES CXX)

# Build standalone for native checks, or as an application subdirectory.
if(NOT WIN32 OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "Playback inference requires Windows x64")
endif()
set(PLAYBACK_ORT_SDK_DIR "" CACHE PATH "Pinned ORT DirectML NuGet extraction")
set(PLAYBACK_DML_SDK_DIR "" CACHE PATH "Pinned DirectML NuGet extraction")
set(PLAYBACK_TRT_SDK_DIR "${PLAYBACK_ORT_SDK_DIR}/../tensorrt" CACHE PATH
    "Pinned TensorRT and CUDA headers (no runtime libraries)")
if(NOT EXISTS "${PLAYBACK_ORT_SDK_DIR}/build/native/include/onnxruntime_c_api.h" OR
   NOT EXISTS "${PLAYBACK_DML_SDK_DIR}/include/DirectML.h")
  message(FATAL_ERROR "Prepare the pinned ORT and DirectML headers first")
endif()

set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${CMAKE_CURRENT_SOURCE_DIR}/dependencies.lock.json")
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/dependencies.lock.json" _asset_lock)
string(JSON _header_count LENGTH "${_asset_lock}" headers)
math(EXPR _last_header "${_header_count} - 1")
foreach(_index RANGE 0 ${_last_header})
  string(JSON _package GET "${_asset_lock}" headers ${_index} package)
  string(JSON _relative GET "${_asset_lock}" headers ${_index} path)
  string(JSON _expected GET "${_asset_lock}" headers ${_index} sha256)
  if(_package STREQUAL "directml")
    set(_header "${PLAYBACK_DML_SDK_DIR}/${_relative}")
  elseif(_package STREQUAL "onnxruntime-directml")
    set(_header "${PLAYBACK_ORT_SDK_DIR}/${_relative}")
  else()
    message(FATAL_ERROR "Unknown inference SDK package: ${_package}")
  endif()
  file(SHA256 "${_header}" _actual)
  if(NOT _actual STREQUAL _expected)
    message(FATAL_ERROR "Pinned inference SDK header mismatch: ${_header}")
  endif()
endforeach()
string(JSON _file_count LENGTH "${_asset_lock}" files)
math(EXPR _last_file "${_file_count} - 1")
foreach(_index RANGE 0 ${_last_file})
  string(JSON _id GET "${_asset_lock}" files ${_index} id)
  if(NOT _id MATCHES "^(performance|balanced|onnxruntime|directml)$")
    continue()
  endif()
  string(JSON ${_id}_bytes GET "${_asset_lock}" files ${_index} bytes)
  string(JSON ${_id}_sha256 GET "${_asset_lock}" files ${_index} sha256)
  string(JSON ${_id}_path GET "${_asset_lock}" files ${_index} path)
  string(LENGTH "${${_id}_sha256}" _hash_length)
  if(NOT _hash_length EQUAL 64 OR NOT ${_id}_sha256 MATCHES "^[0-9a-f]+$")
    message(FATAL_ERROR "Invalid locked inference digest for ${_id}")
  endif()
endforeach()
foreach(_id performance balanced onnxruntime directml)
  if(NOT DEFINED ${_id}_bytes OR NOT DEFINED ${_id}_sha256)
    message(FATAL_ERROR "Missing locked inference asset: ${_id}")
  endif()
endforeach()
configure_file(trusted_assets_data.h.in trusted_assets_data.h @ONLY)

# TensorRT/CUDA are loaded lazily, never linked into aji or libmpv. Only pinned
# SDK headers are needed to compile the optional route; preparation downloads
# no NVIDIA runtime into the application bundle.
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/trt-sdk.lock.json" _trt_sdk_lock)
string(JSON _trt_header_count LENGTH "${_trt_sdk_lock}" headers)
math(EXPR _trt_header_last "${_trt_header_count} - 1")
foreach(_index RANGE 0 ${_trt_header_last})
  string(JSON _name GET "${_trt_sdk_lock}" headers ${_index} name)
  string(JSON _sha GET "${_trt_sdk_lock}" headers ${_index} sha256)
  if(NOT EXISTS "${PLAYBACK_TRT_SDK_DIR}/include/${_name}")
    message(FATAL_ERROR "Prepare TensorRT headers: scripts/prepare_playback_tensorrt.ps1 -HeadersOnly")
  endif()
  file(SHA256 "${PLAYBACK_TRT_SDK_DIR}/include/${_name}" _actual)
  if(NOT _actual STREQUAL _sha)
    message(FATAL_ERROR "Pinned TensorRT header mismatch: ${_name}")
  endif()
endforeach()
string(JSON _cuda_header_count LENGTH "${_trt_sdk_lock}" cudaHeaders)
math(EXPR _cuda_header_last "${_cuda_header_count} - 1")
foreach(_index RANGE 0 ${_cuda_header_last})
  string(JSON _name GET "${_trt_sdk_lock}" cudaHeaders ${_index} name)
  string(JSON _sha GET "${_trt_sdk_lock}" cudaHeaders ${_index} sha256)
  file(SHA256 "${PLAYBACK_TRT_SDK_DIR}/cuda/include/${_name}" _actual)
  if(NOT _actual STREQUAL _sha)
    message(FATAL_ERROR "Pinned CUDA header mismatch: ${_name}")
  endif()
endforeach()
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/trt-components.lock.json" _trt_lock)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${CMAKE_CURRENT_SOURCE_DIR}/trt-components.lock.json"
  "${CMAKE_CURRENT_SOURCE_DIR}/trt-sdk.lock.json")
string(JSON _trt_count LENGTH "${_trt_lock}" files)
math(EXPR _trt_last "${_trt_count} - 1")
set(_trt_assets "")
foreach(_index RANGE 0 ${_trt_last})
  string(JSON _name GET "${_trt_lock}" files ${_index} name)
  string(JSON _bytes GET "${_trt_lock}" files ${_index} bytes)
  string(JSON _sha GET "${_trt_lock}" files ${_index} sha256)
  string(APPEND _trt_assets "  {L\"${_name}\", ${_bytes}ULL, \"${_sha}\"},\n")
endforeach()
foreach(_field trtVersion cudaVersion minimumDriver supportedSm)
  string(JSON _trt_${_field} GET "${_trt_lock}" ${_field})
endforeach()
configure_file(trt_assets_data.h.in trt_assets_data.h @ONLY)

# Frame conversion kernels: compiled by the pinned SDK shader compiler at build
# time so the player needs no runtime shader compiler.
if(NOT PLAYBACK_FXC_EXECUTABLE)
  set(_fxc_candidates
    "$ENV{WindowsSdkVerBinPath}x64/fxc.exe"
    "$ENV{WindowsSdkDir}bin/${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}/x64/fxc.exe"
    "C:/Program Files (x86)/Windows Kits/10/bin/${CMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION}/x64/fxc.exe")
  foreach(_candidate IN LISTS _fxc_candidates)
    if(EXISTS "${_candidate}")
      set(PLAYBACK_FXC_EXECUTABLE "${_candidate}")
      break()
    endif()
  endforeach()
endif()
if(NOT PLAYBACK_FXC_EXECUTABLE)
  message(FATAL_ERROR
    "fxc.exe from the Windows SDK is required for the frame shaders; "
    "pass -DPLAYBACK_FXC_EXECUTABLE=<path>")
endif()
set(_frame_shader "${CMAKE_CURRENT_SOURCE_DIR}/shaders/frame_shaders.hlsl")
add_custom_command(
  OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/frame_shaders_data.h"
  COMMAND ${CMAKE_COMMAND}
    -DFXC=${PLAYBACK_FXC_EXECUTABLE}
    -DSHADER_SOURCE=${_frame_shader}
    -DOUTPUT_HEADER=${CMAKE_CURRENT_BINARY_DIR}/frame_shaders_data.h
    -DGENERATED_DIR=${CMAKE_CURRENT_BINARY_DIR}/shaders
    -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/embed_frame_shaders.cmake"
  DEPENDS "${_frame_shader}" "${CMAKE_CURRENT_SOURCE_DIR}/cmake/embed_frame_shaders.cmake"
  COMMENT "Compiling AnimeJaNai frame shaders"
  VERBATIM)
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/shaders")

add_library(bangumi_dml_session STATIC
  dml_session.cc trusted_assets.cc gpu_capabilities.cc frame_contract.cc
  frame_budget.cc node_placement.cc interop.cc frame_converter.cc
  frame_pipeline.cc
  cuda_api.cc trt_session.cc trt_engine_cache.cc
  "${CMAKE_CURRENT_BINARY_DIR}/frame_shaders_data.h")
target_compile_features(bangumi_dml_session PUBLIC cxx_std_17)
target_compile_definitions(bangumi_dml_session PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_compile_options(bangumi_dml_session PRIVATE /W4 /WX /EHsc /utf-8)
target_include_directories(bangumi_dml_session PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_include_directories(bangumi_dml_session PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_include_directories(bangumi_dml_session SYSTEM PRIVATE
  "${PLAYBACK_ORT_SDK_DIR}/build/native/include" "${PLAYBACK_DML_SDK_DIR}/include"
  "${PLAYBACK_TRT_SDK_DIR}/include" "${PLAYBACK_TRT_SDK_DIR}/cuda/include")
target_link_libraries(bangumi_dml_session PUBLIC d3d12 d3d11 dxgi bcrypt shell32)

# The shim loaded by the pinned mpv filter (see aji_abi.h).
add_library(bangumi_ajishim SHARED aji_bridge.cc aji_abi.h
  trt_precompile.cc trt_precompile.h)
target_compile_features(bangumi_ajishim PRIVATE cxx_std_17)
target_compile_definitions(bangumi_ajishim PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_compile_options(bangumi_ajishim PRIVATE /W4 /WX /EHsc /utf-8)
target_include_directories(bangumi_ajishim PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_include_directories(bangumi_ajishim PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(bangumi_ajishim PRIVATE bangumi_dml_session)
