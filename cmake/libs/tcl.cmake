find_package( TCL REQUIRED )

add_library( scidup_libs_tcl INTERFACE )
add_library(
    ScidUp::Libs::Tcl
    ALIAS scidup_libs_tcl )

if( TARGET TCL::TCL )
    target_link_libraries(
        scidup_libs_tcl
        INTERFACE TCL::TCL )
else()
    target_include_directories(
        scidup_libs_tcl
        INTERFACE ${TCL_INCLUDE_PATH} )
    target_link_libraries(
        scidup_libs_tcl
        INTERFACE ${TCL_LIBRARY} )
endif()

