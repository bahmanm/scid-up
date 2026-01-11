set( _scidup_default_tcl_tk_prefix "" )
if( DEFINED TCL_TCLSH AND NOT TCL_TCLSH STREQUAL "" )
    get_filename_component( _scidup_tclsh_directory "${TCL_TCLSH}" DIRECTORY )
    get_filename_component( _scidup_default_tcl_tk_prefix "${_scidup_tclsh_directory}/.." ABSOLUTE )
endif()

set(
    SCIDUP_TCL_TK_PREFIX
    "${_scidup_default_tcl_tk_prefix}"
    CACHE PATH
    "Prefix where Tcl/Tk are installed; used when SCIDUP_BUNDLE_TCL_TK is enabled." )

if( SCIDUP_TCL_TK_PREFIX STREQUAL "" )
    message(
        FATAL_ERROR
        "SCIDUP_BUNDLE_TCL_TK is enabled, but SCIDUP_TCL_TK_PREFIX is empty.\n"
    )
endif()

if( NOT IS_DIRECTORY "${SCIDUP_TCL_TK_PREFIX}/lib" )
    message(
        FATAL_ERROR
        "SCIDUP_TCL_TK_PREFIX does not contain a lib/ directory: ${SCIDUP_TCL_TK_PREFIX}\n"
    )
endif()

if( NOT DEFINED TCL_LIBRARY OR TCL_LIBRARY STREQUAL "" )
    message(
        FATAL_ERROR
        "SCIDUP_BUNDLE_TCL_TK is enabled, but TCL_LIBRARY is empty.\n"
        "Please ensure find_package(TCL) succeeded.\n"
    )
endif()

if( NOT DEFINED TK_LIBRARY OR TK_LIBRARY STREQUAL "" )
    message(
        FATAL_ERROR
        "SCIDUP_BUNDLE_TCL_TK is enabled, but TK_LIBRARY is empty.\n"
        "Please ensure find_package(TCL) succeeded.\n"
    )
endif()

function( _scidup_find_unique_runtime_directory output_variable prefix runtime_glob description )
    file(
        GLOB
        _scidup_runtime_candidates
        CONFIGURE_DEPENDS
        "${prefix}/lib/${runtime_glob}" )

    list( LENGTH _scidup_runtime_candidates _scidup_runtime_candidate_count )
    if( _scidup_runtime_candidate_count EQUAL 0 )
        message(
            FATAL_ERROR
            "Failed to locate ${description} under ${prefix}/lib.\n"
            "Expected a match for: ${prefix}/lib/${runtime_glob}\n"
        )
    endif()

    if( _scidup_runtime_candidate_count GREATER 1 )
        string( JOIN "\n" _scidup_runtime_candidates_joined ${_scidup_runtime_candidates} )
        message(
            FATAL_ERROR
            "Found multiple candidates for ${description} under ${prefix}/lib.\n"
            "Matches:\n${_scidup_runtime_candidates_joined}\n"
        )
    endif()

    list( GET _scidup_runtime_candidates 0 _scidup_runtime_entry )
    get_filename_component( _scidup_runtime_directory "${_scidup_runtime_entry}" DIRECTORY )
    set( "${output_variable}" "${_scidup_runtime_directory}" PARENT_SCOPE )
endfunction()

_scidup_find_unique_runtime_directory(
    _scidup_tcl_runtime_directory
    "${SCIDUP_TCL_TK_PREFIX}"
    "tcl*/init.tcl"
    "Tcl runtime scripts" )

_scidup_find_unique_runtime_directory(
    _scidup_tk_runtime_directory
    "${SCIDUP_TCL_TK_PREFIX}"
    "tk*/tk.tcl"
    "Tk runtime scripts" )

set( _scidup_tcl_packages_directory "" )
string( REGEX MATCH "tcl([0-9]+)" _scidup_tcl_major_match "${_scidup_tcl_runtime_directory}" )
if( CMAKE_MATCH_1 )
    set( _scidup_tcl_packages_directory "${SCIDUP_TCL_TK_PREFIX}/lib/tcl${CMAKE_MATCH_1}" )
endif()

if( _scidup_tcl_packages_directory STREQUAL _scidup_tcl_runtime_directory )
    set( _scidup_tcl_packages_directory "" )
endif()

if( _scidup_tcl_packages_directory AND NOT IS_DIRECTORY "${_scidup_tcl_packages_directory}" )
    set( _scidup_tcl_packages_directory "" )
endif()

set(
    _scidup_tcl_tk_runtime_directories
    "${_scidup_tcl_runtime_directory}"
    "${_scidup_tk_runtime_directory}" )
if( _scidup_tcl_packages_directory )
    list( APPEND _scidup_tcl_tk_runtime_directories "${_scidup_tcl_packages_directory}" )
endif()

install(
    DIRECTORY ${_scidup_tcl_tk_runtime_directories}
    DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    USE_SOURCE_PERMISSIONS )
