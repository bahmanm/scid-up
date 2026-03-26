set(
    TCL_BRIDGE_TEST_RUNNER
    "${CMAKE_SOURCE_DIR}/tests/tcl/integration/sc_base_smoke.tcl" )

add_test(
    NAME tcl_bridge_test
    COMMAND
    "${CMAKE_COMMAND}" -E chdir "${CMAKE_SOURCE_DIR}"
    "$<TARGET_FILE:ScidUp::Bins::Main>" "${TCL_BRIDGE_TEST_RUNNER}" )

get_filename_component(
    _tcl_bin_dir
    "${TCL_TCLSH}" DIRECTORY )
get_filename_component(
    _tcl_lib_dir
    "${TCL_LIBRARY}" DIRECTORY )
set_tests_properties(
    tcl_bridge_test
    PROPERTIES
    ENVIRONMENT "PATH=${_tcl_bin_dir}:$ENV{PATH};LD_LIBRARY_PATH=${_tcl_lib_dir}:$ENV{LD_LIBRARY_PATH};DYLD_LIBRARY_PATH=${_tcl_lib_dir}:$ENV{DYLD_LIBRARY_PATH}"
    LABELS "tcl;bridge" )

add_custom_target(
    tcl_bridge_tests
    COMMAND "${CMAKE_CTEST_COMMAND}" -R "^tcl_bridge_test$" --output-on-failure
    VERBATIM )
