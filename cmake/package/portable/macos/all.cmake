include_guard( GLOBAL )

if( NOT APPLE )
    return()
endif()

###############################################################################
# Dylib install-name fixups for the application binary.
#
# Ensure the installed binary uses a relative install name for the bundled Tcl/Tk.
#
# Note: The bundled Tcl/Tk are built with zipfs; their Mach-O binaries include a
# trailing zip archive, which makes them unsuitable for patching with
# install_name_tool. Instead, patch the application binary to load the bundled
# dylibs via @rpath.
###############################################################################

set(
    _scidup_macos_fixups_script
    "${CMAKE_CURRENT_BINARY_DIR}/scidup-portable-macos-fix-dylib-install-name.cmake" )

configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/fix-dylib-install-name.cmake.in"
    "${_scidup_macos_fixups_script}"
    @ONLY )

install( SCRIPT "${_scidup_macos_fixups_script}" )

###############################################################################