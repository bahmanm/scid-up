include_guard( GLOBAL )

if( NOT WIN32 )
    return()
endif()

###############################################################################
# Bundle MSVC runtime DLLs (e.g. VCRUNTIME140_1.dll) into the portable archive.
###############################################################################

set( CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION "${CMAKE_INSTALL_BINDIR}" )
set( CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_NO_WARNINGS ON )
set( CMAKE_INSTALL_DEBUG_LIBRARIES OFF )

include( InstallRequiredSystemLibraries )

###############################################################################