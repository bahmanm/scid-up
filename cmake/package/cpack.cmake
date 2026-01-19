set( CPACK_PACKAGE_NAME "scid-up" )
if( SCIDUP_PORTABLE_ARCHIVE )
    if( NOT DEFINED SCIDUP_RELEASE_VERSION OR SCIDUP_RELEASE_VERSION STREQUAL "" )
        message(
            FATAL_ERROR
            "SCIDUP_PORTABLE_ARCHIVE is enabled, but SCIDUP_RELEASE_VERSION is empty.\n"
            "Please set SCIDUP_RELEASE_VERSION (e.g. -DSCIDUP_RELEASE_VERSION=v1-testing-2026-01-18).\n" )
    endif()

    set( CPACK_PACKAGE_VERSION "${SCIDUP_RELEASE_VERSION}" )
else()
    set( CPACK_PACKAGE_VERSION "0" )
endif()
set( CPACK_PACKAGE_DESCRIPTION_SUMMARY "Cross-Platform Chess Database and Analysis GUI" )

include( CPack )

