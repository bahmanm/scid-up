option(
    SCIDUP_PORTABLE_ARCHIVE
    "Configure installation directories for a portable archive (./bin, ./lib, ./share)."
    OFF )

if( NOT SCIDUP_PORTABLE_ARCHIVE )
    return()
endif()

set( CMAKE_INSTALL_PREFIX "/" )
set( CMAKE_INSTALL_BINDIR "/bin" )
set( CMAKE_INSTALL_LIBDIR "/lib" )
set( CMAKE_INSTALL_DATADIR "/share" )

set(
    CMAKE_INSTALL_PREFIX
    "/"
    CACHE PATH
    "Install prefix for portable archives."
    FORCE )

set(
    CMAKE_INSTALL_BINDIR
    "/bin"
    CACHE PATH
    "Executable directory for portable archives."
    FORCE )

set(
    CMAKE_INSTALL_LIBDIR
    "/lib"
    CACHE PATH
    "Library directory for portable archives."
    FORCE )

set(
    CMAKE_INSTALL_DATADIR
    "/share"
    CACHE PATH
    "Data directory for portable archives."
    FORCE )
