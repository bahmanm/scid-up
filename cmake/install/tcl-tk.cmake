option(
    SCIDUP_BUNDLE_TCL_TK
    "Bundle Tcl/Tk into the installation tree (intended for portable archives)."
    OFF )

###############################################################################
if( NOT SCIDUP_BUNDLE_TCL_TK )
    return()
endif()

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

###############################################################################
install(
    DIRECTORY "${SCIDUP_TCL_TK_PREFIX}/lib/"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    USE_SOURCE_PERMISSIONS )

