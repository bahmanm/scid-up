if( NOT SCIDUP_PORTABLE_ARCHIVE )
    return()
endif()

# The portable archive should extract directly into ./bin, ./lib, ./share, ...
set( CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF )
set( CPACK_PACKAGING_INSTALL_PREFIX "/" )
set( CPACK_SET_DESTDIR ON )

include( cmake/package/portable/tcl-tk/all.cmake )
