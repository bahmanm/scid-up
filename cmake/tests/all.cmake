if( NOT DEFINED BUILD_TESTING )
    set( BUILD_TESTING OFF CACHE BOOL "Build tests" )
endif()

include( CTest )
if( NOT BUILD_TESTING )
    return()
endif()

include( cmake/tests/cpptest.cmake )
include( cmake/tests/tcl.cmake )
include( cmake/tests/portable.cmake )
