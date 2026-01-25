include_guard( GLOBAL )

if( NOT SCIDUP_PORTABLE_ARCHIVE )
    return()
endif()

set( SCIDUP_RELEASE_DATE_LINE "${SCIDUP_RELEASE_DATE}" )

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
