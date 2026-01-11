set( _scidup_tcl_tk_library_destination "${CMAKE_INSTALL_LIBDIR}" )
if( NOT IS_ABSOLUTE "${_scidup_tcl_tk_library_destination}" )
    set( _scidup_tcl_tk_library_destination "${CMAKE_INSTALL_PREFIX}/${_scidup_tcl_tk_library_destination}" )
endif()
cmake_path( NORMAL_PATH _scidup_tcl_tk_library_destination )

install(
    CODE
    "file( INSTALL DESTINATION \"${_scidup_tcl_tk_library_destination}\" TYPE FILE FOLLOW_SYMLINK_CHAIN FILES \"${TCL_LIBRARY}\" \"${TK_LIBRARY}\" )" )
