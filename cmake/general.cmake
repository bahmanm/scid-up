set( CMAKE_CXX_EXTENSIONS OFF )
set( CMAKE_CXX_STANDARD 20 )
set( CMAKE_CXX_STANDARD_REQUIRED ON )
set( CMAKE_EXPORT_COMPILE_COMMANDS ON )

set(
    SCIDUP_RELEASE_VERSION
    ""
    CACHE STRING
    "Release version tag embedded into ScidUp (e.g. v1-testing-2026-01-19)." )

set(
    SCIDUP_RELEASE_DATE
    ""
    CACHE STRING
    "Release date (YYYY-MM-DD) embedded into ScidUp." )

set(
    SCIDUP_RELEASE_PLATFORM
    ""
    CACHE STRING
    "Release platform label embedded into ScidUp artefacts (e.g. Windows, macOS (Apple Silicon), Linux)." )

set( SCIDUP_GENERATED_INCLUDE_DIR "${CMAKE_BINARY_DIR}/generated" )
file( MAKE_DIRECTORY "${SCIDUP_GENERATED_INCLUDE_DIR}" )
configure_file(
    "${CMAKE_SOURCE_DIR}/cmake/scidup_release.h.in"
    "${SCIDUP_GENERATED_INCLUDE_DIR}/scidup_release.h"
    @ONLY )
