include_guard( GLOBAL )

option(
    SCIDUP_BUNDLE_TCL_TK
    "Bundle Tcl/Tk into the installation tree (intended for portable archives)."
    OFF )

if( NOT SCIDUP_BUNDLE_TCL_TK )
    return()
endif()

include( cmake/package/portable/tcl-tk/common.cmake )

if( WIN32 )
    include( cmake/package/portable/tcl-tk/windows.cmake )
else()
    include( cmake/package/portable/tcl-tk/unix.cmake )
endif()
