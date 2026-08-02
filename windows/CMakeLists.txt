# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(bangumi_today LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "bangumi_today")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if (IS_MULTICONFIG)
    set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
            CACHE STRING "" FORCE)
else ()
    if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
        set(CMAKE_BUILD_TYPE "Debug" CACHE
                STRING "Flutter build mode" FORCE)
        set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
                "Debug" "Profile" "Release")
    endif ()
endif ()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
    target_compile_features(${TARGET} PUBLIC cxx_std_17)
    target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
    target_compile_options(${TARGET} PRIVATE /EHsc)
    target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
    target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif ()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
        COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
        COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        COMPONENT Runtime)

if (PLUGIN_BUNDLED_LIBRARIES)
    install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
            DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
            COMPONENT Runtime)
endif ()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
        DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
        COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
        DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
        CONFIGURATIONS Profile;Release
        COMPONENT Runtime)

# bt_download sidecar runtime. The complete engine install directory is kept in
# its own folder so its native dependencies do not pollute the Flutter runner's
# DLL search path. Set BT_DOWNLOAD_RUNTIME_DIR in the environment before running
# `flutter build windows`, or pass it as a CMake cache variable.
set(BT_DOWNLOAD_RUNTIME_DIR "" CACHE PATH
        "Path to the installed bt_download runtime directory")
if (DEFINED ENV{BT_DOWNLOAD_RUNTIME_DIR}
        AND NOT "$ENV{BT_DOWNLOAD_RUNTIME_DIR}" STREQUAL "")
    file(TO_CMAKE_PATH "$ENV{BT_DOWNLOAD_RUNTIME_DIR}"
            BT_DOWNLOAD_RUNTIME_DIR)
endif ()

set(BT_DOWNLOAD_BUNDLE_DIR
        "${INSTALL_BUNDLE_LIB_DIR}/bt_download")
install(CODE "
  file(REMOVE_RECURSE \"${BT_DOWNLOAD_BUNDLE_DIR}\")
  " COMPONENT Runtime)

if (BT_DOWNLOAD_RUNTIME_DIR)
    get_filename_component(BT_DOWNLOAD_RUNTIME_DIR
            "${BT_DOWNLOAD_RUNTIME_DIR}" ABSOLUTE)

    set(BT_DOWNLOAD_REQUIRED_FILES
            bt_download.exe
            torrent-rasterbar.dll
            libcrypto-3-x64.dll
            libssl-3-x64.dll
            msvcp140.dll
            vcruntime140.dll
            sbom.spdx.json
            THIRD_PARTY_NOTICES.txt
            licenses/boost.txt
            licenses/libtorrent.txt
            licenses/nlohmann-json.txt
            licenses/openssl.txt)
    foreach (REQUIRED_FILE IN LISTS BT_DOWNLOAD_REQUIRED_FILES)
        if (NOT EXISTS "${BT_DOWNLOAD_RUNTIME_DIR}/${REQUIRED_FILE}")
            message(FATAL_ERROR
                    "Incomplete bt_download runtime: missing ${REQUIRED_FILE} "
                    "from ${BT_DOWNLOAD_RUNTIME_DIR}")
        endif ()
    endforeach ()

    install(DIRECTORY "${BT_DOWNLOAD_RUNTIME_DIR}/"
            DESTINATION "${BT_DOWNLOAD_BUNDLE_DIR}"
            COMPONENT Runtime)
    message(STATUS
            "Bundling bt_download runtime from ${BT_DOWNLOAD_RUNTIME_DIR}")
else ()
    message(STATUS
            "BT_DOWNLOAD_RUNTIME_DIR is not set; bt_download will not be bundled")
endif ()

# Sqlite
include(FetchContent)

FetchContent_Declare(sqlite3
        URL "https://www.sqlite.org/2023/sqlite-dll-win64-x64-3420000.zip"
        URL_HASH SHA3_256=2425efa95556793a20761dfdab0d3b56a52e61716e8bb65e6a0a3590d41c97c0
        DOWNLOAD_EXTRACT_TIMESTAMP true
)
find_file(SQLITE3 sqlite3)
if(NOT SQLITE3)
    message("sqlite3.dll not found, trying to download or use cached version.")
    FetchContent_MakeAvailable(sqlite3)
    set(SQLITE3 ${sqlite3_SOURCE_DIR}/sqlite3.dll)
endif()

install(FILES "${SQLITE3}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
