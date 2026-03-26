if( CMAKE_SYSTEM_NAME STREQUAL "Linux" )
    include( cmake/tests/tcl/common.cmake )

    set(
        TCL_GUI_TEST_RUNNER
        "${CMAKE_SOURCE_DIR}/tests/tcl/run_gui_tests.tcl" )

    add_test(
        NAME tcl_gui_test
        COMMAND
        "${CMAKE_COMMAND}" -E chdir "${CMAKE_SOURCE_DIR}"
        "${TCL_TCLSH}" "${TCL_GUI_TEST_RUNNER}" )

    scidup_configure_tcl_test( tcl_gui_test "tcl;gui" )

    add_custom_target(
        tcl_gui_tests
        COMMAND "${CMAKE_CTEST_COMMAND}" -R "^tcl_gui_test$" --output-on-failure
        VERBATIM )
endif()
