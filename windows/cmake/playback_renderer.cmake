# Keep the Windows renderer fix in the project, never in the shared Pub cache.
# Every translation unit uses the same copied headers so VideoOutput's layout
# remains consistent with video_output_manager and the plugin entry point.
function(bangumi_configure_playback_renderer)
    if(NOT TARGET media_kit_video_plugin)
        message(FATAL_ERROR "media_kit_video_plugin is required for playback")
    endif()
    get_target_property(_plugin_dir media_kit_video_plugin SOURCE_DIR)
    file(READ "${_plugin_dir}/../pubspec.yaml" _pubspec)
    if(NOT _pubspec MATCHES "[\r\n]version: 2\\.0\\.1[\r\n]")
        message(FATAL_ERROR
            "The playback renderer override requires media_kit_video 2.0.1. "
            "Review the override before upgrading the plugin.")
    endif()

    set(_override_dir "${CMAKE_CURRENT_LIST_DIR}/../playback")
    set(_overlay_dir "${CMAKE_BINARY_DIR}/bangumi_playback_renderer")
    set(_patched_files
        video_output.cc video_output.h
        angle_surface_manager.cc angle_surface_manager.h)
    set(_upstream_hashes
        198cb59a97070b61df5ee8ae35ac3e0bc344f3174f6e4aaf7b77e7357d606548
        e276c8b80e9e117d60713b3b25b12ddb0df1878a2c076fe946847ac7eec7c17a
        04eadbea88ce1d825a732c8ea96f9557bb19c275330f4abf7836950e7efd2e2a
        3c7f24a94a8f7e8b551877142ea12b92d1543d4f8384370d55c3b5147eefe6ef)
    foreach(_index RANGE 0 3)
        list(GET _patched_files ${_index} _name)
        list(GET _upstream_hashes ${_index} _expected)
        file(READ "${_plugin_dir}/${_name}" _upstream)
        string(REPLACE "\r\n" "\n" _upstream "${_upstream}")
        string(SHA256 _actual "${_upstream}")
        if(NOT _actual STREQUAL _expected)
            message(FATAL_ERROR
                "Unexpected media_kit_video source: ${_name}. "
                "Review the playback renderer override before building.")
        endif()
    endforeach()

    file(GLOB _native_files CONFIGURE_DEPENDS
        "${_plugin_dir}/*.cc" "${_plugin_dir}/*.h")
    file(GLOB_RECURSE _public_headers CONFIGURE_DEPENDS
        "${_plugin_dir}/include/*")
    foreach(_file IN LISTS _native_files _public_headers)
        file(RELATIVE_PATH _relative "${_plugin_dir}" "${_file}")
        if(_relative IN_LIST _patched_files)
            set(_input "${_override_dir}/${_relative}")
        else()
            set(_input "${_file}")
        endif()
        configure_file("${_input}" "${_overlay_dir}/${_relative}" COPYONLY)
    endforeach()
    configure_file("${_override_dir}/render_queue.h"
        "${_overlay_dir}/render_queue.h" COPYONLY)

    get_target_property(_sources media_kit_video_plugin SOURCES)
    set(_overlay_sources "")
    foreach(_source IN LISTS _sources)
        get_filename_component(_absolute "${_source}" ABSOLUTE
            BASE_DIR "${_plugin_dir}")
        file(RELATIVE_PATH _relative "${_plugin_dir}" "${_absolute}")
        if(_absolute IN_LIST _native_files)
            list(APPEND _overlay_sources "${_overlay_dir}/${_relative}")
        else()
            list(APPEND _overlay_sources "${_source}")
        endif()
    endforeach()
    set_property(TARGET media_kit_video_plugin PROPERTY SOURCES
        "${_overlay_sources}")
    message(STATUS "Using the project playback renderer override")
endfunction()

bangumi_configure_playback_renderer()
