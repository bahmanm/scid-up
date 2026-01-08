set( SCIDUP_REQUIRED_TCLTK_PATCHLEVEL "9.0.3" )

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
if(APPLE)
    set( CMAKE_FIND_FRAMEWORK "${_scidup_original_cmake_find_framework}" )
endif()
