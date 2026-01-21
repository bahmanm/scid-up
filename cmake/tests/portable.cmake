option(
    SCIDUP_TEST_PORTABLE_ARCHIVE
    "Enable optional smoke-tests for the portable archive layout."
    OFF )

if( NOT SCIDUP_TEST_PORTABLE_ARCHIVE )
    return()
endif()

if( NOT SCIDUP_PORTABLE_ARCHIVE )
    message(
        STATUS
        "SCIDUP_TEST_PORTABLE_ARCHIVE is enabled, but SCIDUP_PORTABLE_ARCHIVE is off; skipping portable archive smoke-tests." )
    return()
endif()

add_test(
    NAME portable_archive_smoke
    COMMAND
    "${CMAKE_COMMAND}"
    -D "SCIDUP_CMAKE_COMMAND=${CMAKE_COMMAND}"
    -D "SCIDUP_BUILD_DIR=${CMAKE_BINARY_DIR}"
    -D "SCIDUP_INSTALLED_EXECUTABLE_NAME=$<TARGET_FILE_NAME:ScidUp::Bins::Main>"
    -P "${CMAKE_SOURCE_DIR}/cmake/tests/portable-archive-smoke-test.cmake" )

set_tests_properties(
    portable_archive_smoke
    PROPERTIES
    LABELS "smoke" )
