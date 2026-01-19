include_guard( GLOBAL )

if( NOT SCIDUP_PORTABLE_ARCHIVE )
    return()
endif()

set(
    SCIDUP_RELEASE_VERSION
    ""
    CACHE STRING
    "Release version string embedded into the portable README.txt (e.g. v2 or v4-testing-2026-01-18)." )

if( SCIDUP_RELEASE_VERSION STREQUAL "" )
    message(
        FATAL_ERROR
        "SCIDUP_PORTABLE_ARCHIVE is enabled, but SCIDUP_RELEASE_VERSION is empty.\n"
        "Please set SCIDUP_RELEASE_VERSION (e.g. -DSCIDUP_RELEASE_VERSION=v1-testing-2026-01-18).\n" )
endif()

set(
    SCIDUP_RELEASE_PLATFORM
    ""
    CACHE STRING
    "Platform string embedded into the portable README.txt (e.g. Windows, macOS (Apple Silicon), Linux)." )

set(
    SCIDUP_RELEASE_DATE
    ""
    CACHE STRING
    "Release date string embedded into the portable README.txt (e.g. 2026-01-18)." )

set( SCIDUP_RELEASE_DATE_LINE "" )
if( NOT SCIDUP_RELEASE_DATE STREQUAL "" )
    set( SCIDUP_RELEASE_DATE_LINE "${SCIDUP_RELEASE_DATE}" )
endif()

if( SCIDUP_RELEASE_PLATFORM STREQUAL "" )
    if( WIN32 )
        set( SCIDUP_RELEASE_PLATFORM "Windows" )
    elseif( APPLE )
        set( SCIDUP_RELEASE_PLATFORM "macOS" )
    else()
        set( SCIDUP_RELEASE_PLATFORM "Linux" )
    endif()
endif()

set( _scidup_readme_template "" )
if( WIN32 )
    set( _scidup_readme_template "${CMAKE_CURRENT_LIST_DIR}/README-windows.txt.in" )
elseif( APPLE )
    set( _scidup_readme_template "${CMAKE_CURRENT_LIST_DIR}/README-macos.txt.in" )
else()
    set( _scidup_readme_template "${CMAKE_CURRENT_LIST_DIR}/README-linux.txt.in" )
endif()

set( _scidup_readme_output "${CMAKE_BINARY_DIR}/README.txt" )
configure_file(
    "${_scidup_readme_template}"
    "${_scidup_readme_output}"
    @ONLY )

install(
    FILES "${_scidup_readme_output}"
    DESTINATION "."
    RENAME "README.txt" )
