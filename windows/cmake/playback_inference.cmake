# AnimeJaNai upscaling wiring: the inference shim, its pinned base package and the
# filter configuration file.
#
# The pinned mpv runtime (see cmake/playback_runtime.cmake) contains
# vf_animejanai, which loads a shim DLL at run time over a strict C ABI. This
# project builds that shim from windows/playback/inference and installs it as
# `aji.dll`, the name the filter looks up in the player directory, together with
# `animejanai.conf`. Default realtime AI requires configured TensorRT resources;
# DirectML remains an explicit diagnostic route. The shim needs the pinned base
# inference package (ONNX Runtime, DirectML, the ONNX models, their
# licenses and the app-local C++ runtime) that
# scripts/prepare_playback_inference.ps1 produces.
#
# Missing or modified assets fail configuration before compiling the shim.

set(BANGUMI_PLAYBACK_INFERENCE_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/../.dart_tool/playback_inference/base/runtime"
    CACHE PATH "Prepared AnimeJaNai inference base package")
set(BANGUMI_PLAYBACK_INFERENCE_SDK_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/../.dart_tool/playback_inference/base/sdk"
    CACHE PATH "Pinned ONNX Runtime and DirectML SDK extractions")
set(BANGUMI_PLAYBACK_INFERENCE_SOURCE_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/playback/inference"
    CACHE PATH "AnimeJaNai inference and shim sources")

get_filename_component(BANGUMI_PLAYBACK_INFERENCE_DIR
    "${BANGUMI_PLAYBACK_INFERENCE_DIR}" ABSOLUTE)
get_filename_component(BANGUMI_PLAYBACK_INFERENCE_SDK_DIR
    "${BANGUMI_PLAYBACK_INFERENCE_SDK_DIR}" ABSOLUTE)
get_filename_component(BANGUMI_PLAYBACK_INFERENCE_SOURCE_DIR
    "${BANGUMI_PLAYBACK_INFERENCE_SOURCE_DIR}" ABSOLUTE)

find_program(_bangumi_inference_powershell NAMES pwsh powershell)
if(NOT _bangumi_inference_powershell)
    message(FATAL_ERROR "PowerShell is required to verify inference assets")
endif()
execute_process(
    COMMAND "${_bangumi_inference_powershell}" -NoProfile -ExecutionPolicy Bypass
        -File "${CMAKE_CURRENT_SOURCE_DIR}/../scripts/verify_playback_inference_prerequisites.ps1"
        -RuntimeDirectory "${BANGUMI_PLAYBACK_INFERENCE_DIR}"
    RESULT_VARIABLE _bangumi_inference_verified
    OUTPUT_VARIABLE _bangumi_inference_verification_log
    ERROR_VARIABLE _bangumi_inference_verification_error)
if(NOT _bangumi_inference_verified EQUAL 0)
    message(FATAL_ERROR
        "Inference package verification failed. Run scripts/prepare_playback_inference.ps1.\n"
        "${_bangumi_inference_verification_log}${_bangumi_inference_verification_error}")
endif()

set(_bangumi_inference_runtime_files
    onnxruntime.dll
    DirectML.dll
    manifest.json
    THIRD_PARTY_NOTICES.txt
    msvcp140.dll
    msvcp140_1.dll
    vcruntime140.dll
    vcruntime140_1.dll)
foreach(_bangumi_inference_runtime_file IN LISTS _bangumi_inference_runtime_files)
    if(NOT EXISTS
       "${BANGUMI_PLAYBACK_INFERENCE_DIR}/${_bangumi_inference_runtime_file}")
        message(FATAL_ERROR
            "Incomplete AnimeJaNai inference package: "
            "${BANGUMI_PLAYBACK_INFERENCE_DIR}/${_bangumi_inference_runtime_file} "
            "is missing. Run scripts/prepare_playback_inference.ps1 first.")
    endif()
endforeach()
foreach(_bangumi_inference_directory IN ITEMS models licenses)
    if(NOT IS_DIRECTORY "${BANGUMI_PLAYBACK_INFERENCE_DIR}/${_bangumi_inference_directory}")
        message(FATAL_ERROR
            "Incomplete AnimeJaNai inference package: "
            "${BANGUMI_PLAYBACK_INFERENCE_DIR}/${_bangumi_inference_directory} "
            "is missing. Run scripts/prepare_playback_inference.ps1 first.")
    endif()
endforeach()

# Slot 1 is the smooth (Performance) model, slot 2 the high quality (Balanced)
# one; the file names are pinned by windows/playback/inference/dependencies.lock.json.
file(GLOB _bangumi_performance_models
    "${BANGUMI_PLAYBACK_INFERENCE_DIR}/models/*Performance*.onnx")
file(GLOB _bangumi_balanced_models
    "${BANGUMI_PLAYBACK_INFERENCE_DIR}/models/*Balanced*.onnx")
if(NOT _bangumi_performance_models OR NOT _bangumi_balanced_models)
    message(FATAL_ERROR
        "The AnimeJaNai inference package needs both the Performance and the "
        "Balanced ONNX model in ${BANGUMI_PLAYBACK_INFERENCE_DIR}/models")
endif()
list(GET _bangumi_performance_models 0 _bangumi_performance_model)
list(GET _bangumi_balanced_models 0 _bangumi_balanced_model)
get_filename_component(_bangumi_performance_model_name
    "${_bangumi_performance_model}" NAME)
get_filename_component(_bangumi_balanced_model_name
    "${_bangumi_balanced_model}" NAME)

# Build the shim from the same sources as the standalone P0 project, compiled by
# the same pinned SDK headers and asset digests.
set(PLAYBACK_ORT_SDK_DIR "${BANGUMI_PLAYBACK_INFERENCE_SDK_DIR}/onnxruntime")
set(PLAYBACK_DML_SDK_DIR "${BANGUMI_PLAYBACK_INFERENCE_SDK_DIR}/directml")
set(PLAYBACK_TRT_SDK_DIR "${BANGUMI_PLAYBACK_INFERENCE_SDK_DIR}/tensorrt")
add_subdirectory("${BANGUMI_PLAYBACK_INFERENCE_SOURCE_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}/playback_inference")
set_target_properties(bangumi_ajishim PROPERTIES OUTPUT_NAME aji)

# The filter resolves the default shim name in the player directory, and the
# shim's own import of the C++ runtime has to resolve there too, so the shim and
# the app-local runtime go next to the executable.
list(APPEND PLUGIN_BUNDLED_LIBRARIES
    "$<TARGET_FILE:bangumi_ajishim>"
    "${BANGUMI_PLAYBACK_INFERENCE_DIR}/msvcp140.dll"
    "${BANGUMI_PLAYBACK_INFERENCE_DIR}/msvcp140_1.dll"
    "${BANGUMI_PLAYBACK_INFERENCE_DIR}/vcruntime140.dll"
    "${BANGUMI_PLAYBACK_INFERENCE_DIR}/vcruntime140_1.dll")

# The configuration file sits next to aji.dll. Paths in it are relative to that
# file, so the bundle stays portable and no Windows path has to travel through
# mpv's `:`-separated filter option syntax. `stats` is omitted on purpose: the
# shim writes its low-frequency status snapshot under the per-user local
# application data directory when the configuration does not name a path.
set(_bangumi_animejanai_conf "${CMAKE_CURRENT_BINARY_DIR}/animejanai.conf")
file(WRITE "${_bangumi_animejanai_conf}"
"# AnimeJaNai shim configuration - generated by windows/cmake/playback_inference.cmake
backend=tensorrt
runtime_dir=playback_inference
model_dir=playback_inference/models
default_slot=1
slot1=${_bangumi_performance_model_name}
slot2=${_bangumi_balanced_model_name}
")
install(FILES "${_bangumi_animejanai_conf}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)

# Retain the separate TRT configuration as an alias of the default policy.
# Selecting an AI quality never authorizes a component download.
set(_bangumi_trt_conf "${CMAKE_CURRENT_BINARY_DIR}/animejanai-trt.conf")
file(READ "${_bangumi_animejanai_conf}" _bangumi_base_conf)
file(WRITE "${_bangumi_trt_conf}" "${_bangumi_base_conf}")
install(FILES "${_bangumi_trt_conf}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
install(FILES "${BANGUMI_PLAYBACK_INFERENCE_SOURCE_DIR}/trt-components.lock.json"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" RENAME tensorrt-components.json
    COMPONENT Runtime)

set(_bangumi_inference_bundle_dir
    "${INSTALL_BUNDLE_LIB_DIR}/playback_inference")
# Re-copy the package on each install so a previous version cannot leave stale
# DLLs or models behind.
install(CODE "
  file(REMOVE_RECURSE \"${_bangumi_inference_bundle_dir}\")
  " COMPONENT Runtime)
install(DIRECTORY "${BANGUMI_PLAYBACK_INFERENCE_DIR}/"
    DESTINATION "${_bangumi_inference_bundle_dir}"
    COMPONENT Runtime)

message(STATUS
    "Bundling the AnimeJaNai inference package from ${BANGUMI_PLAYBACK_INFERENCE_DIR} "
    "with the shim at ${INSTALL_BUNDLE_LIB_DIR}/aji.dll")
