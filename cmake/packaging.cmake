set(
    CPACK_PACKAGE_VERSION
    "${PROJECT_VERSION}" )
set(
    CPACK_PACKAGE_DESCRIPTION_SUMMARY
    "chess database application with play and training functionality" )
set(
    CPACK_DEBIAN_PACKAGE_DEPENDS
    "tk9 (>= 9)" )
set(
    CPACK_DEBIAN_PACKAGE_SHLIBDEPS
    ON )

include( CPack )

