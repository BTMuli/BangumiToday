# The bundled Windows libmpv must carry the AnimeJaNai filter (`vf_animejanai`),
# which only exists in the pinned `the-database/mpv` fork, and its normalization
# filters (`dynaudnorm`) which media_kit's own libmpv build disables. The
# published `mpv-dev` package of `the-database/mpv-winbuild` is a GPL build
# (mpv with rubberband / x264 / x265); see windows/licenses/libmpv/NOTICE.md.
# The LGPL variant (`mpv-dev-lgpl-*`, produced by that repository's workflow
# with `lgpl=true`) can replace these constants once it exists.
# This build matches the mpvfork pinned in mpv-AnimeJaNai 3.7.0's manifest.json.
set(BANGUMI_LIBMPV_RELEASE "2026-10-07-d6d93599d5")
set(BANGUMI_LIBMPV_ARCHIVE_NAME
    "mpv-dev-x86_64-20261007-git-d6d93599d5.7z")
set(BANGUMI_LIBMPV_ARCHIVE_SHA256
    "077cb75fed47b185428f97224e1d798e2d4c2f4063fd8cda2662b74f2892327c")
set(BANGUMI_LIBMPV_DLL_SHA256
    "90de8f89fa1421eaec510e5cfe11de75846b445489864220ec811fd0f08b4649")
set(BANGUMI_LIBMPV_ARCHIVE
    "${CMAKE_BINARY_DIR}/${BANGUMI_LIBMPV_ARCHIVE_NAME}")
set(BANGUMI_LIBMPV_DIR "${CMAKE_BINARY_DIR}/libmpv-ajan-20261007")
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
        "https://github.com/the-database/mpv-winbuild/releases/download/${BANGUMI_LIBMPV_RELEASE}/${BANGUMI_LIBMPV_ARCHIVE_NAME}"
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
if(NOT _bangumi_libmpv_dll_hash STREQUAL BANGUMI_LIBMPV_DLL_SHA256 OR
   NOT EXISTS "${BANGUMI_LIBMPV_DIR}/include/mpv/client.h" OR
   NOT EXISTS "${BANGUMI_LIBMPV_DIR}/include/mpv/render.h" OR
   NOT EXISTS "${BANGUMI_LIBMPV_DIR}/libmpv.dll.a")
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

# Compile and link against the same pinned runtime we ship. The plugin's older
# SDK lacks mpv_get_time_ns, needed for this runtime's nanosecond deadlines.
target_include_directories(media_kit_video_plugin BEFORE PRIVATE
    "${BANGUMI_LIBMPV_DIR}/include/mpv")
get_target_property(_bangumi_playback_link_libraries
    media_kit_video_plugin LINK_LIBRARIES)
set(_bangumi_playback_runtime_links "")
foreach(_bangumi_library IN LISTS _bangumi_playback_link_libraries)
    get_filename_component(_bangumi_library_name "${_bangumi_library}" NAME)
    if(NOT _bangumi_library_name STREQUAL "libmpv.dll.a")
        list(APPEND _bangumi_playback_runtime_links "${_bangumi_library}")
    endif()
endforeach()
set_property(TARGET media_kit_video_plugin PROPERTY LINK_LIBRARIES
    ${_bangumi_playback_runtime_links} "${BANGUMI_LIBMPV_DIR}/libmpv.dll.a")

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
