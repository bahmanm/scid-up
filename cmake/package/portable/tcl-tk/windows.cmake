###############################################################################
# Bundle Tcl/Tk DLLs next to the executable for portable archives.
#
# The DLL names are derived from the import libraries as reported by find_package(TCL).
# For instance, based on ".../lib/tcl9tk90.lib", the ".../bin/tcl9tk90.dll" name is assumed.
###############################################################################

get_filename_component( _scidup_tcl_import_library_name "${TCL_LIBRARY}" NAME_WE )
set( _scidup_tcl_dll "${SCIDUP_TCL_TK_PREFIX}/bin/${_scidup_tcl_import_library_name}.dll" )
if( NOT EXISTS "${_scidup_tcl_dll}" )
    message(
        FATAL_ERROR
        "Failed to locate Tcl DLL: ${_scidup_tcl_dll}\n"
        "TCL_LIBRARY=${TCL_LIBRARY}\n"
        "SCIDUP_TCL_TK_PREFIX=${SCIDUP_TCL_TK_PREFIX}\n" )
endif()

get_filename_component( _scidup_tk_import_library_name "${TK_LIBRARY}" NAME_WE )
set( _scidup_tk_dll "${SCIDUP_TCL_TK_PREFIX}/bin/${_scidup_tk_import_library_name}.dll" )
if( NOT EXISTS "${_scidup_tk_dll}" )
    message(
        FATAL_ERROR
        "Failed to locate Tk DLL: ${_scidup_tk_dll}\n"
        "TK_LIBRARY=${TK_LIBRARY}\n"
        "SCIDUP_TCL_TK_PREFIX=${SCIDUP_TCL_TK_PREFIX}\n" )
endif()

install(
    FILES "${_scidup_tcl_dll}" "${_scidup_tk_dll}"
    DESTINATION "${CMAKE_INSTALL_BINDIR}" )

###############################################################################
# Bundle DLL dependencies of Tcl/Tk (e.g. zlib1.dll, libtommath.dll).
###############################################################################

set( _scidup_tcl_tk_bin_dir "${SCIDUP_TCL_TK_PREFIX}/bin" )
cmake_path( NORMAL_PATH _scidup_tcl_tk_bin_dir )

file(
    GET_RUNTIME_DEPENDENCIES
    LIBRARIES "${_scidup_tcl_dll}" "${_scidup_tk_dll}"
    DIRECTORIES "${_scidup_tcl_tk_bin_dir}"
    RESOLVED_DEPENDENCIES_VAR _scidup_tcl_tk_resolved_dependencies
    UNRESOLVED_DEPENDENCIES_VAR _scidup_tcl_tk_unresolved_dependencies )

set( _scidup_tcl_tk_dependency_dlls "" )
foreach( _scidup_dependency IN LISTS _scidup_tcl_tk_resolved_dependencies )
    cmake_path( NORMAL_PATH _scidup_dependency )
    cmake_path( IS_PREFIX "${_scidup_tcl_tk_bin_dir}" "${_scidup_dependency}" _scidup_is_tcl_tk_bin_dependency )
    if( _scidup_is_tcl_tk_bin_dependency )
        list( APPEND _scidup_tcl_tk_dependency_dlls "${_scidup_dependency}" )
    endif()
endforeach()

list( REMOVE_ITEM _scidup_tcl_tk_dependency_dlls "${_scidup_tcl_dll}" "${_scidup_tk_dll}" )
list( REMOVE_DUPLICATES _scidup_tcl_tk_dependency_dlls )

if( _scidup_tcl_tk_dependency_dlls )
    install(
        FILES ${_scidup_tcl_tk_dependency_dlls}
        DESTINATION "${CMAKE_INSTALL_BINDIR}" )
endif()
