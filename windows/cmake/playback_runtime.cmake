# media_kit's Windows libmpv has its normalization filters disabled. Bundle a
# pinned LGPL build with dynaudnorm while retaining the plugin's ANGLE DLLs.
set(BANGUMI_LIBMPV_RELEASE "2026-10-03-413ff0b1cd")
set(BANGUMI_LIBMPV_ARCHIVE_NAME
    "mpv-dev-lgpl-x86_64-20261003-git-413ff0b1cd.7z")
set(BANGUMI_LIBMPV_ARCHIVE_SHA256
    "12a9966bad239672c97276f01a9e625504e0b1d1fdcff95256066eeb8ffb1f21")
set(BANGUMI_LIBMPV_DLL_SHA256
    "6209dfe89b45d726bedc3b932e9321e9d1a49b64b2e1fefdf8c2973e384e7001")
set(BANGUMI_LIBMPV_ARCHIVE
    "${CMAKE_BINARY_DIR}/${BANGUMI_LIBMPV_ARCHIVE_NAME}")
set(BANGUMI_LIBMPV_DIR "${CMAKE_BINARY_DIR}/libmpv-lgpl-20261003")
set(BANGUMI_LIBMPV_DLL "${BANGUMI_LIBMPV_DIR}/libmpv-2.dll")

if(DEFINED FLUTTER_TARGET_PLATFORM AND
   NOT FLUTTER_TARGET_PLATFORM STREQUAL "windows-x64")
    message(FATAL_ERROR "The playback runtime is only available for Windows x64")
endif()

set(_bangumi_libmpv_archive_hash "")
if(EXISTS "${BANGUMI_LIBMPV_ARCHIVE}")
    file(SHA256 "${BANGUMI_LIBMPV_ARCHIVE}" _bangumi_libmpv_archive_hash)
endif()
if(NOT _bangumi_libmpv_archive_hash STREQUAL BANGUMI_LIBMPV_ARCHIVE_SHA256)
    file(DOWNLOAD
        "https://github.com/zhongfly/mpv-winbuild/releases/download/${BANGUMI_LIBMPV_RELEASE}/${BANGUMI_LIBMPV_ARCHIVE_NAME}"
        "${BANGUMI_LIBMPV_ARCHIVE}"
        EXPECTED_HASH "SHA256=${BANGUMI_LIBMPV_ARCHIVE_SHA256}"
        TLS_VERIFY ON
        STATUS _bangumi_libmpv_download)
    list(GET _bangumi_libmpv_download 0 _bangumi_libmpv_download_code)
    if(NOT _bangumi_libmpv_download_code EQUAL 0)
        message(FATAL_ERROR "Could not download the playback runtime: ${_bangumi_libmpv_download}")
    endif()
endif()

set(_bangumi_libmpv_dll_hash "")
if(EXISTS "${BANGUMI_LIBMPV_DLL}")
    file(SHA256 "${BANGUMI_LIBMPV_DLL}" _bangumi_libmpv_dll_hash)
endif()
if(NOT _bangumi_libmpv_dll_hash STREQUAL BANGUMI_LIBMPV_DLL_SHA256)
    file(MAKE_DIRECTORY "${BANGUMI_LIBMPV_DIR}")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E tar xf "${BANGUMI_LIBMPV_ARCHIVE}"
        WORKING_DIRECTORY "${BANGUMI_LIBMPV_DIR}"
        RESULT_VARIABLE _bangumi_libmpv_extract_code)
    if(NOT _bangumi_libmpv_extract_code EQUAL 0)
        message(FATAL_ERROR "Could not extract the playback runtime")
    endif()
    file(SHA256 "${BANGUMI_LIBMPV_DLL}" _bangumi_libmpv_dll_hash)
endif()
if(NOT _bangumi_libmpv_dll_hash STREQUAL BANGUMI_LIBMPV_DLL_SHA256)
    message(FATAL_ERROR "The playback runtime DLL failed SHA-256 verification")
endif()

# The generated plugin list already contains the old DLL. Replace only that
# entry so installation never copies two different DLLs to the same filename.
set(_bangumi_playback_bundled_libraries "")
foreach(_bangumi_library IN LISTS PLUGIN_BUNDLED_LIBRARIES)
    get_filename_component(_bangumi_library_name "${_bangumi_library}" NAME)
    if(NOT _bangumi_library_name STREQUAL "libmpv-2.dll")
        list(APPEND _bangumi_playback_bundled_libraries "${_bangumi_library}")
    endif()
endforeach()
set(PLUGIN_BUNDLED_LIBRARIES
    ${_bangumi_playback_bundled_libraries} "${BANGUMI_LIBMPV_DLL}")
