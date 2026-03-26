include( cmake/tests/tcl/common.cmake )

set(
    TCL_UNIT_TEST_RUNNER
    "${CMAKE_SOURCE_DIR}/tests/tcl/run_unit_tests.tcl" )

add_test(
    NAME tcl_test
    COMMAND
    "${CMAKE_COMMAND}" -E chdir "${CMAKE_SOURCE_DIR}"
    "${TCL_TCLSH}" "${TCL_UNIT_TEST_RUNNER}" )

scidup_configure_tcl_test( tcl_test "tcl;unit" )

add_custom_target(
    tcl_unit_tests
    COMMAND "${CMAKE_CTEST_COMMAND}" -R "^tcl_test$" --output-on-failure
    VERBATIM )

add_custom_target(
    tcl_all_tests
    COMMAND "${CMAKE_CTEST_COMMAND}" -L "tcl" --output-on-failure
    VERBATIM )
