# Bundle Tcl/Tk DLLs next to the executable for portable archives.
file(
    GLOB
    _scidup_tcl_dlls
    CONFIGURE_DEPENDS
    "${SCIDUP_TCL_TK_PREFIX}/bin/tcl*.dll" )
file(
    GLOB
    _scidup_tk_dlls
    CONFIGURE_DEPENDS
    "${SCIDUP_TCL_TK_PREFIX}/bin/tk*.dll" )

if( NOT _scidup_tcl_dlls )
    message(
        FATAL_ERROR
        "Failed to locate Tcl DLLs under ${SCIDUP_TCL_TK_PREFIX}/bin.\n"
        "Expected a match for: ${SCIDUP_TCL_TK_PREFIX}/bin/tcl*.dll\n" )
endif()
if( NOT _scidup_tk_dlls )
    message(
        FATAL_ERROR
        "Failed to locate Tk DLLs under ${SCIDUP_TCL_TK_PREFIX}/bin.\n"
        "Expected a match for: ${SCIDUP_TCL_TK_PREFIX}/bin/tk*.dll\n" )
endif()

install(
    FILES ${_scidup_tcl_dlls} ${_scidup_tk_dlls}
    DESTINATION "${CMAKE_INSTALL_BINDIR}" )
