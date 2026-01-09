file(
    GLOB SCIDUP_MAIN_SOURCES
    CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/src/*.h"
    "${CMAKE_SOURCE_DIR}/src/*.cpp" )

if( MSVC )
    add_executable(
        scidup_main
        WIN32
        ${SCIDUP_MAIN_SOURCES}
        "${CMAKE_SOURCE_DIR}/resources/win/scid.rc"
        "${CMAKE_SOURCE_DIR}/resources/win/scid.manifest" )
    target_link_options(
        scidup_main
        PRIVATE /ENTRY:mainCRTStartup )
    target_compile_definitions(
        scidup_main
        PRIVATE _CRT_SECURE_NO_WARNINGS _SCL_SECURE_NO_WARNINGS )
    # To run/debug using Visual Studio set "scidup_main" as startup project and add:
    # Command Arguments: ../tcl/start.tcl
    # Environment:       PATH=C:\tcl\bin
else()
    add_executable(
        scidup_main
        ${SCIDUP_MAIN_SOURCES} )
endif()

add_executable(
    ScidUp::Bins::Main
    ALIAS scidup_main )
set_target_properties(
    scidup_main
    PROPERTIES OUTPUT_NAME "scid-up" )

if( DEFINED SCIDUP_BUNDLE_TCL_TK AND SCIDUP_BUNDLE_TCL_TK AND UNIX AND NOT WIN32 )
    file(
        RELATIVE_PATH
        _scidup_relative_library_directory
        "${CMAKE_INSTALL_FULL_BINDIR}"
        "${CMAKE_INSTALL_FULL_LIBDIR}" )

    if( _scidup_relative_library_directory STREQUAL "." )
        set( _scidup_relative_library_directory "" )
    endif()

    if( APPLE )
        set( _scidup_install_rpath "@loader_path/${_scidup_relative_library_directory}" )
    else()
        set( _scidup_install_rpath "$ORIGIN/${_scidup_relative_library_directory}" )
    endif()

    set_target_properties(
        scidup_main
        PROPERTIES INSTALL_RPATH "${_scidup_install_rpath}" )
endif()

set_property(
    TARGET scidup_main
    PROPERTY INTERPROCEDURAL_OPTIMIZATION_RELEASE True )
target_link_libraries(
    scidup_main
    PRIVATE ScidUp::Libs::Polyglot Threads::Threads ScidUp::Libs::Tcl )

option( SPELLCHKVALIDATE "Verify the integrity of spelling files" OFF )
if( SPELLCHKVALIDATE )
    target_compile_definitions( scidup_main PRIVATE SPELLCHKVALIDATE )
endif()
