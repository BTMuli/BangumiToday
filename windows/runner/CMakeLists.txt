cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "crash_handler.cpp"
  "flutter_window.cpp"
  "playback_plugin_registrant.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# The crash handler uses the C++ terminate hook. Flutter's template disables
# STL exception handling, which makes std::terminate bypass that hook in MSVC.
get_target_property(_runner_definitions ${BINARY_NAME} COMPILE_DEFINITIONS)
list(FILTER _runner_definitions EXCLUDE REGEX "^_HAS_EXCEPTIONS=")
set_property(TARGET ${BINARY_NAME} PROPERTY COMPILE_DEFINITIONS
  "${_runner_definitions}")
target_compile_definitions(${BINARY_NAME} PRIVATE _HAS_EXCEPTIONS=1)

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Keep the SDK identity with crash dumps even when they outlive an SDK upgrade.
# Read the generated configuration in a function so its environment lists stay
# scoped here. The template's flutter subdirectory does not export FLUTTER_ROOT.
function(configure_native_diagnostics target)
  include("${FLUTTER_MANAGED_DIR}/ephemeral/generated_config.cmake")
  set(_version_file "${FLUTTER_ROOT}/bin/cache/flutter.version.json")
  if(NOT EXISTS "${_version_file}")
    message(WARNING "Flutter SDK identity unavailable for native diagnostics")
    return()
  endif()
  file(READ "${_version_file}" _sdk_identity)
  foreach(_entry "frameworkVersion;BANGUMI_FLUTTER_SDK_VERSION"
                 "engineRevision;BANGUMI_FLUTTER_ENGINE_REVISION")
    list(GET _entry 0 _key)
    list(GET _entry 1 _definition)
    string(REGEX MATCH "\"${_key}\"[ \t\r\n]*:[ \t\r\n]*\"([^\"]+)\""
      _match "${_sdk_identity}")
    if(_match)
      target_compile_definitions(${target} PRIVATE
        "${_definition}=\"${CMAKE_MATCH_1}\"")
    endif()
  endforeach()
endfunction()
configure_native_diagnostics(${BINARY_NAME})

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
# PlaybackWindowFramePlugin uses PluginRegistrar from the plugin wrapper.
target_link_libraries(${BINARY_NAME} PRIVATE
  flutter flutter_wrapper_app flutter_wrapper_plugin)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib" "dbghelp.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
