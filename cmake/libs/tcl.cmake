set( SCIDUP_REQUIRED_TCLTK_PATCHLEVEL "9.0.3" )

###############################################################################
# Exclusively use DEPS_INSTALL_PREFIX to avoid mixing installation
# from different providers, e.g. OS.
set( _scidup_dependencies_install_prefix "" )
if( DEFINED ENV{DEPS_INSTALL_PREFIX} AND NOT "$ENV{DEPS_INSTALL_PREFIX}" STREQUAL "" )
    set( _scidup_dependencies_install_prefix "$ENV{DEPS_INSTALL_PREFIX}" )
endif()

if( _scidup_dependencies_install_prefix )
    find_program(
        _scidup_tclsh_from_prefix
        NAMES tclsh tclsh9.0 tclsh90
        HINTS "${_scidup_dependencies_install_prefix}/bin"
        NO_DEFAULT_PATH )
    if( _scidup_tclsh_from_prefix )
        set( TCL_TCLSH "${_scidup_tclsh_from_prefix}" CACHE FILEPATH "Path to tclsh" FORCE )
    endif()

    find_program(
        _scidup_wish_from_prefix
        NAMES wish wish9.0 wish90
        HINTS "${_scidup_dependencies_install_prefix}/bin"
        NO_DEFAULT_PATH )
    if( _scidup_wish_from_prefix )
        set( TK_WISH "${_scidup_wish_from_prefix}" CACHE FILEPATH "Path to wish" FORCE )
    endif()

    find_path(
        _scidup_tcl_include_from_prefix
        NAMES tcl.h
        HINTS
        "${_scidup_dependencies_install_prefix}/include"
        "${_scidup_dependencies_install_prefix}/include/tcl-tk"
        NO_DEFAULT_PATH )
    if( _scidup_tcl_include_from_prefix )
        set( TCL_INCLUDE_PATH "${_scidup_tcl_include_from_prefix}" CACHE PATH "Path to Tcl headers" FORCE )
    endif()

    find_path(
        _scidup_tk_include_from_prefix
        NAMES tk.h
        HINTS
        "${_scidup_dependencies_install_prefix}/include"
        "${_scidup_dependencies_install_prefix}/include/tcl-tk"
        NO_DEFAULT_PATH )
    if( _scidup_tk_include_from_prefix )
        set( TK_INCLUDE_PATH "${_scidup_tk_include_from_prefix}" CACHE PATH "Path to Tk headers" FORCE )
    endif()

    find_library(
        _scidup_tcl_library_from_prefix
        NAMES tcl9.0 tcl90 tcl9 tcl
        HINTS
        "${_scidup_dependencies_install_prefix}/lib"
        "${_scidup_dependencies_install_prefix}/bin"
        NO_DEFAULT_PATH )
    if( _scidup_tcl_library_from_prefix )
        set( TCL_LIBRARY "${_scidup_tcl_library_from_prefix}" CACHE FILEPATH "Path to Tcl library" FORCE )
    endif()

    find_library(
        _scidup_tk_library_from_prefix
        NAMES tk9.0 tk90 tcl9tk9.0 tcl9tk90 tk9 tk
        HINTS
        "${_scidup_dependencies_install_prefix}/lib"
        "${_scidup_dependencies_install_prefix}/bin"
        NO_DEFAULT_PATH )
    if( _scidup_tk_library_from_prefix )
        set( TK_LIBRARY "${_scidup_tk_library_from_prefix}" CACHE FILEPATH "Path to Tk library" FORCE )
    endif()
endif()

###############################################################################
set( _scidup_original_cmake_find_framework "${CMAKE_FIND_FRAMEWORK}" )
if( APPLE )
    set( CMAKE_FIND_FRAMEWORK LAST )
endif()

###############################################################################

find_package( TCL REQUIRED )

if( NOT TCL_TCLSH )
    message( FATAL_ERROR "Need tclsh ${SCIDUP_REQUIRED_TCLTK_PATCHLEVEL}, but TCL_TCLSH was not found." )
endif()
if( NOT TK_WISH )
    message( FATAL_ERROR "Need wish ${SCIDUP_REQUIRED_TCLTK_PATCHLEVEL}, but TK_WISH was not found." )
endif()

get_filename_component( _scidup_tclsh_directory "${TCL_TCLSH}" DIRECTORY )
get_filename_component( _scidup_tclsh_prefix "${_scidup_tclsh_directory}/.." ABSOLUTE )

set( _scidup_tclsh_patchlevel "" )
if( NOT CMAKE_CROSSCOMPILING )
    set( _scidup_tclsh_probe_script "${CMAKE_CURRENT_BINARY_DIR}/scidup_probe_tclsh_patchlevel.tcl" )
    file( WRITE "${_scidup_tclsh_probe_script}" "puts [info patchlevel]\n" )
    execute_process(
        COMMAND "${TCL_TCLSH}" "${_scidup_tclsh_probe_script}"
        RESULT_VARIABLE _scidup_tclsh_result
        OUTPUT_VARIABLE _scidup_tclsh_output
        ERROR_VARIABLE _scidup_tclsh_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if( NOT _scidup_tclsh_result EQUAL 0 )
        message(
            FATAL_ERROR
            "Failed to execute tclsh.\n"
            "TCL_TCLSH=${TCL_TCLSH}\n"
            "stderr:\n${_scidup_tclsh_error}\n\n"
        )
    endif()
    set( _scidup_tclsh_patchlevel "${_scidup_tclsh_output}" )
    if( NOT _scidup_tclsh_patchlevel STREQUAL "${SCIDUP_REQUIRED_TCLTK_PATCHLEVEL}" )
        message(
            FATAL_ERROR
            "Need tclsh ${SCIDUP_REQUIRED_TCLTK_PATCHLEVEL}, but got ${_scidup_tclsh_patchlevel}.\n"
            "TCL_TCLSH=${TCL_TCLSH}\n\n"
        )
    endif()
endif()

###############################################################################
function( _scidup_extract_patchlevel output_variable header_path macro_name )
    if( NOT EXISTS "${header_path}" )
        message(
            FATAL_ERROR
            "Header was not found: ${header_path}"
        )
    endif()

    file( READ "${header_path}" _header_contents )
    string(
        REGEX MATCH
        "#[ \t]*define[ \t]+${macro_name}[ \t]+\"([0-9]+\\.[0-9]+\\.[0-9]+)\""
        _macro_match
        "${_header_contents}"
    )
    if( NOT CMAKE_MATCH_1 )
        message(
            FATAL_ERROR
            "Failed to parse ${macro_name} in ${header_path}."
        )
    endif()

    set( "${output_variable}" "${CMAKE_MATCH_1}" PARENT_SCOPE )
endfunction()

_scidup_extract_patchlevel( _scidup_tcl_patchlevel "${TCL_INCLUDE_PATH}/tcl.h" "TCL_PATCH_LEVEL" )
_scidup_extract_patchlevel( _scidup_tk_patchlevel "${TK_INCLUDE_PATH}/tk.h" "TK_PATCH_LEVEL" )

if( NOT _scidup_tcl_patchlevel STREQUAL "${SCIDUP_REQUIRED_TCLTK_PATCHLEVEL}" )
    message(
        FATAL_ERROR
        "Need Tcl ${SCIDUP_REQUIRED_TCLTK_PATCHLEVEL}, but got ${_scidup_tcl_patchlevel}.\n"
        "TCL_INCLUDE_PATH=${TCL_INCLUDE_PATH}\n"
        "TCL_LIBRARY=${TCL_LIBRARY}\n"
        "TCL_TCLSH=${TCL_TCLSH}\n\n"
    )
endif()

if( NOT _scidup_tk_patchlevel STREQUAL "${SCIDUP_REQUIRED_TCLTK_PATCHLEVEL}" )
    message(
        FATAL_ERROR
        "Need Tk ${SCIDUP_REQUIRED_TCLTK_PATCHLEVEL}, but got ${_scidup_tk_patchlevel}.\n"
        "TK_INCLUDE_PATH=${TK_INCLUDE_PATH}\n"
        "TK_LIBRARY=${TK_LIBRARY}\n"
        "TK_WISH=${TK_WISH}\n\n"
    )
endif()

if( NOT _scidup_tcl_patchlevel STREQUAL _scidup_tk_patchlevel )
    message(
        FATAL_ERROR
        "Mismatching versions: Tcl ${_scidup_tcl_patchlevel} and Tk ${_scidup_tk_patchlevel}.\n"
        "TCL_LIBRARY=${TCL_LIBRARY}\n"
        "TK_LIBRARY=${TK_LIBRARY}\n\n"
    )
endif()

###############################################################################
add_library( scidup_libs_tcl INTERFACE )
add_library( ScidUp::Libs::Tcl ALIAS scidup_libs_tcl )

if( TARGET TCL::TCL )
    target_link_libraries( scidup_libs_tcl INTERFACE TCL::TCL )
else()
    target_include_directories( scidup_libs_tcl INTERFACE ${TCL_INCLUDE_PATH} )
    target_link_libraries( scidup_libs_tcl INTERFACE ${TCL_LIBRARY} )
endif()

###############################################################################
if( APPLE )
    set( CMAKE_FIND_FRAMEWORK "${_scidup_original_cmake_find_framework}" )
endif()
