cmake_minimum_required(VERSION 3.24)
project(playback_gpu_regression LANGUAGES CXX)
if(NOT WIN32)
  message(FATAL_ERROR "These non-UI native checks require Windows")
endif()
get_filename_component(REPO_ROOT "../../.." ABSOLUTE)
add_executable(playback_gpu_regression
  gpu_regression.cc
  "${REPO_ROOT}/windows/playback/inference/frame_budget.cc")
target_compile_features(playback_gpu_regression PRIVATE cxx_std_17)
target_compile_definitions(playback_gpu_regression PRIVATE
  NOMINMAX WIN32_LEAN_AND_MEAN)
target_compile_options(playback_gpu_regression PRIVATE /W4 /WX /EHsc /utf-8)
target_include_directories(playback_gpu_regression PRIVATE
  "${REPO_ROOT}/windows/playback")
target_link_libraries(playback_gpu_regression PRIVATE d3d11 d3d12 dxgi)
enable_testing()
add_executable(warm_cache_regression warm_cache_regression.cc)
target_compile_features(warm_cache_regression PRIVATE cxx_std_17)
target_compile_options(warm_cache_regression PRIVATE /W4 /WX /EHsc /utf-8)
target_include_directories(warm_cache_regression PRIVATE
  "${REPO_ROOT}/windows/playback")
add_test(NAME warm_cache_regression COMMAND warm_cache_regression)
set_tests_properties(warm_cache_regression PROPERTIES TIMEOUT 15)

add_executable(stats_writer_regression stats_writer_regression.cc)
target_compile_features(stats_writer_regression PRIVATE cxx_std_17)
target_compile_definitions(stats_writer_regression PRIVATE
  NOMINMAX WIN32_LEAN_AND_MEAN)
target_compile_options(stats_writer_regression PRIVATE /W4 /WX /EHsc /utf-8)
target_include_directories(stats_writer_regression PRIVATE
  "${REPO_ROOT}/windows/playback")
add_test(NAME stats_writer_regression COMMAND stats_writer_regression)
set_tests_properties(stats_writer_regression PROPERTIES TIMEOUT 15)

add_test(NAME playback_gpu_regression COMMAND playback_gpu_regression)
set_tests_properties(playback_gpu_regression PROPERTIES TIMEOUT 30)

add_executable(frame_scheduler_regression frame_scheduler_regression.cc)
target_compile_features(frame_scheduler_regression PRIVATE cxx_std_17)
target_compile_definitions(frame_scheduler_regression PRIVATE
  NOMINMAX WIN32_LEAN_AND_MEAN)
target_compile_options(frame_scheduler_regression PRIVATE /W4 /WX /EHsc /utf-8)
target_include_directories(frame_scheduler_regression PRIVATE
  "${REPO_ROOT}/windows/playback")
add_test(NAME frame_scheduler_regression COMMAND frame_scheduler_regression)
set_tests_properties(frame_scheduler_regression PROPERTIES TIMEOUT 10)

set(ANGLE_ROOT "${REPO_ROOT}/build/windows/x64/ANGLE" CACHE PATH "ANGLE SDK")
set(RENDERER_HEADERS "${REPO_ROOT}/build/windows/x64/bangumi_playback_renderer"
  CACHE PATH "Prepared renderer headers")
if(EXISTS "${ANGLE_ROOT}/lib/libEGL.dll.lib" AND
   EXISTS "${RENDERER_HEADERS}/utils.h")
  foreach(target angle_surface_regression angle_surface_legacy_regression)
    add_executable(${target} angle_surface_regression.cc
      "${REPO_ROOT}/windows/playback/angle_surface_manager.cc")
    target_compile_features(${target} PRIVATE cxx_std_17)
    target_compile_definitions(${target} PRIVATE
      NOMINMAX WIN32_LEAN_AND_MEAN)
    target_compile_options(${target} PRIVATE /W4 /WX /EHsc /utf-8
      "/FI${CMAKE_CURRENT_SOURCE_DIR}/angle_test_support.h")
    target_include_directories(${target} PRIVATE
      "${REPO_ROOT}/windows/playback" "${ANGLE_ROOT}/include" "${RENDERER_HEADERS}")
    target_link_libraries(${target} PRIVATE d3d11 d3d12 dxgi
      "${ANGLE_ROOT}/lib/libEGL.dll.lib" "${ANGLE_ROOT}/lib/libGLESv2.dll.lib")
    if(target STREQUAL "angle_surface_legacy_regression")
      target_compile_definitions(${target} PRIVATE ANGLE_TEST_DISABLE_DEVICE_CREATION)
    endif()
    add_test(NAME ${target} COMMAND ${target})
    set_tests_properties(${target} PROPERTIES
      WORKING_DIRECTORY "${ANGLE_ROOT}" TIMEOUT 45)
  endforeach()
endif()
