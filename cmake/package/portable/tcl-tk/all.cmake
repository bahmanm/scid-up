include_guard( GLOBAL )

if( NOT SCIDUP_PORTABLE_ARCHIVE )
    return()
endif()

include( cmake/package/portable/tcl-tk/common.cmake )

if( WIN32 )
    include( cmake/package/portable/tcl-tk/windows.cmake )
else()
    include( cmake/package/portable/tcl-tk/unix.cmake )
endif()
