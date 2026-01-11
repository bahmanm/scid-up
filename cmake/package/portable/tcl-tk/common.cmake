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

if( NOT DEFINED TCL_TCLSH OR TCL_TCLSH STREQUAL "" )
    message(
        FATAL_ERROR
        "SCIDUP_BUNDLE_TCL_TK is enabled, but TCL_TCLSH is empty.\n"
        "Please ensure find_package(TCL) succeeded.\n"
    )
endif()
if( NOT EXISTS "${TCL_TCLSH}" )
    message(
        FATAL_ERROR
        "SCIDUP_BUNDLE_TCL_TK is enabled, but TCL_TCLSH does not exist: ${TCL_TCLSH}\n"
    )
endif()

set(
    _scidup_tcl_info_script
    "puts \"patchlevel=[info patchlevel]\"\n"
    "puts \"library=[info library]\"\n"
    "puts \"tcl_library=$tcl_library\"\n"
    "exit\n"
)
set( _scidup_tcl_info_script_file "${CMAKE_BINARY_DIR}/scidup-tcl-info.tcl" )
file( WRITE "${_scidup_tcl_info_script_file}" "${_scidup_tcl_info_script}" )

execute_process(
    COMMAND "${TCL_TCLSH}" "${_scidup_tcl_info_script_file}"
    RESULT_VARIABLE _scidup_tcl_info_result
    OUTPUT_VARIABLE _scidup_tcl_info_output
    ERROR_VARIABLE _scidup_tcl_info_error
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
if( NOT _scidup_tcl_info_result EQUAL 0 )
    message(
        FATAL_ERROR
        "Failed to execute TCL_TCLSH to validate the bundled Tcl installation.\n"
        "TCL_TCLSH=${TCL_TCLSH}\n"
        "stdout:\n${_scidup_tcl_info_output}\n"
        "stderr:\n${_scidup_tcl_info_error}\n"
    )
endif()

string( REPLACE "\r" "" _scidup_tcl_info_output "${_scidup_tcl_info_output}" )

string( REGEX MATCH "(^|\n)patchlevel=([0-9]+\\.[0-9]+\\.[0-9]+)" _scidup_patchlevel_match "${_scidup_tcl_info_output}" )
set( _scidup_patchlevel "${CMAKE_MATCH_2}" )

string( REGEX MATCH "(^|\n)library=([^\n]*)" _scidup_library_match "${_scidup_tcl_info_output}" )
set( _scidup_tcl_info_library "${CMAKE_MATCH_2}" )

if( NOT _scidup_patchlevel OR _scidup_patchlevel STREQUAL "" )
    message(
        FATAL_ERROR
        "Failed to parse Tcl patchlevel from TCL_TCLSH output:\n${_scidup_tcl_info_output}\n"
    )
endif()
if( NOT _scidup_tcl_info_library OR _scidup_tcl_info_library STREQUAL "" )
    message(
        FATAL_ERROR
        "Failed to parse 'info library' from TCL_TCLSH output:\n${_scidup_tcl_info_output}\n"
    )
endif()

if( NOT _scidup_tcl_info_library MATCHES "^//zipfs:" )
    message(
        FATAL_ERROR
        "The portable archive assumes zipfs-backed Tcl/Tk, but Tcl reports a non-zipfs library path.\n"
        "patchlevel=${_scidup_patchlevel}\n"
        "info library=${_scidup_tcl_info_library}\n"
    )
endif()

string( REGEX MATCH "^([0-9]+)\\.([0-9]+)\\." _scidup_patchlevel_components "${_scidup_patchlevel}" )
set( _scidup_tcl_version_major "${CMAKE_MATCH_1}" )
set( _scidup_tcl_version_minor "${CMAKE_MATCH_2}" )

set( _scidup_tcl_tk_runtime_directories "" )

set( _scidup_tcl_major_dir "${SCIDUP_TCL_TK_PREFIX}/lib/tcl${_scidup_tcl_version_major}" )
if( IS_DIRECTORY "${_scidup_tcl_major_dir}" )
    list( APPEND _scidup_tcl_tk_runtime_directories "${_scidup_tcl_major_dir}" )
endif()

set( _scidup_tk_version_dir "${SCIDUP_TCL_TK_PREFIX}/lib/tk${_scidup_tcl_version_major}.${_scidup_tcl_version_minor}" )
if( IS_DIRECTORY "${_scidup_tk_version_dir}" )
    list( APPEND _scidup_tcl_tk_runtime_directories "${_scidup_tk_version_dir}" )
endif()

file(
    GLOB
    _scidup_pkgindex_files
    CONFIGURE_DEPENDS
    "${SCIDUP_TCL_TK_PREFIX}/lib/*/pkgIndex.tcl" )
foreach( _scidup_pkgindex_file IN LISTS _scidup_pkgindex_files )
    get_filename_component( _scidup_pkgindex_directory "${_scidup_pkgindex_file}" DIRECTORY )
    list( APPEND _scidup_tcl_tk_runtime_directories "${_scidup_pkgindex_directory}" )
endforeach()
list( REMOVE_DUPLICATES _scidup_tcl_tk_runtime_directories )

if( _scidup_tcl_tk_runtime_directories )
    install(
        DIRECTORY ${_scidup_tcl_tk_runtime_directories}
        DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        USE_SOURCE_PERMISSIONS )
endif()
