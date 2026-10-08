# Apply fullscreen bounds in one native update and preserve frameless state.
# window_manager 0.5.2 splits move/resize and resets frameless state on exit.
# Build a patched copy without modifying the shared Pub cache.
function(bangumi_configure_playback_window)
    if(NOT TARGET window_manager_plugin)
        message(FATAL_ERROR "window_manager_plugin is required for playback")
    endif()
    get_target_property(_plugin_dir window_manager_plugin SOURCE_DIR)
    file(READ "${_plugin_dir}/../pubspec.yaml" _pubspec)
    if(NOT _pubspec MATCHES "[\r\n]version: 0\\.5\\.2[\r\n]")
        message(FATAL_ERROR
            "The fullscreen override requires window_manager 0.5.2. "
            "Review the override before upgrading the plugin.")
    endif()

    set(_input "${_plugin_dir}/window_manager.cpp")
    file(READ "${_input}" _upstream)
    string(REPLACE "\r\n" "\n" _upstream "${_upstream}")
    string(SHA256 _actual "${_upstream}")
    if(NOT _actual STREQUAL
            "fe90a377f8d14b37f5643e7db4550ea0fb64a54d8f0a9751cb7ae10744860b53")
        message(FATAL_ERROR
            "Unexpected window_manager source. "
            "Review the fullscreen override before building.")
    endif()
    set(_override "${CMAKE_CURRENT_LIST_DIR}/../playback/window_fullscreen.inc")
    file(READ "${_override}" _fullscreen)
    string(FIND "${_upstream}"
        "void WindowManager::SetFullScreen(const flutter::EncodableMap& args) {"
        _start)
    string(FIND "${_upstream}"
        "void WindowManager::SetAspectRatio(const flutter::EncodableMap& args) {"
        _end)
    if(_start LESS 0 OR _end LESS _start)
        message(FATAL_ERROR "Could not locate the fullscreen implementation")
    endif()
    math(EXPR _length "${_end} - ${_start}")
    string(SUBSTRING "${_upstream}" ${_start} ${_length} _original_fullscreen)
    string(REPLACE "${_original_fullscreen}" "${_fullscreen}\n\n"
        _patched "${_upstream}")
    string(REPLACE "  bool g_is_window_fullscreen = false;"
        "  bool g_is_window_fullscreen = false;\n  bool g_frameless_before_fullscreen = false;\n  WINDOWPLACEMENT g_placement_before_fullscreen{};"
        _patched "${_patched}")

    set(_overlay_dir "${CMAKE_BINARY_DIR}/bangumi_playback_window")
    # The plugin entry point includes window_manager.cpp, so both translation
    # units and their relative public header must resolve to the copied tree.
    configure_file("${_plugin_dir}/window_manager_plugin.cpp"
        "${_overlay_dir}/window_manager_plugin.cpp" COPYONLY)
    configure_file("${_plugin_dir}/include/window_manager/window_manager_plugin.h"
        "${_overlay_dir}/include/window_manager/window_manager_plugin.h" COPYONLY)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        "${_input}" "${_override}")
    set(_output "${_overlay_dir}/window_manager.cpp")
    if(EXISTS "${_output}")
        file(READ "${_output}" _previous)
    endif()
    if(NOT _previous STREQUAL _patched)
        file(WRITE "${_output}" "${_patched}")
    endif()

    get_target_property(_sources window_manager_plugin SOURCES)
    set(_overlay_sources "")
    foreach(_source IN LISTS _sources)
        get_filename_component(_absolute "${_source}" ABSOLUTE
            BASE_DIR "${_plugin_dir}")
        if(_absolute STREQUAL "${_plugin_dir}/window_manager.cpp")
            list(APPEND _overlay_sources "${_overlay_dir}/window_manager.cpp")
        elseif(_absolute STREQUAL "${_plugin_dir}/window_manager_plugin.cpp")
            list(APPEND _overlay_sources "${_overlay_dir}/window_manager_plugin.cpp")
        else()
            list(APPEND _overlay_sources "${_absolute}")
        endif()
    endforeach()
    set_property(TARGET window_manager_plugin PROPERTY SOURCES
        "${_overlay_sources}")
    message(STATUS "Using the project fullscreen bounds override")
endfunction()

bangumi_configure_playback_window()
