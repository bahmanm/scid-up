set(
    TCL_GUI_TEST_RUNNER
    "${CMAKE_SOURCE_DIR}/tests/tcl/run_gui_tests.tcl" )

if( CMAKE_SYSTEM_NAME STREQUAL "Linux" )
    add_test(
        NAME tcl_gui_test
        COMMAND
        "${CMAKE_COMMAND}" -E chdir "${CMAKE_SOURCE_DIR}"
        "${TCL_TCLSH}" "${TCL_GUI_TEST_RUNNER}" )

    get_filename_component(
        _tcl_bin_dir
        "${TCL_TCLSH}" DIRECTORY )
    get_filename_component(
        _tcl_lib_dir
        "${TCL_LIBRARY}" DIRECTORY )

    set_tests_properties(
        tcl_gui_test
        PROPERTIES
        ENVIRONMENT "PATH=${_tcl_bin_dir}:$ENV{PATH};LD_LIBRARY_PATH=${_tcl_lib_dir}:$ENV{LD_LIBRARY_PATH}"
        LABELS "tcl;gui" )

    add_custom_target(
        tcl_gui_tests
        COMMAND "${CMAKE_CTEST_COMMAND}" -R "^tcl_gui_test$" --output-on-failure
        VERBATIM )
endif()

