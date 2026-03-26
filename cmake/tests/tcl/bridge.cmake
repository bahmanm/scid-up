set(
    TCL_BRIDGE_TEST_RUNNER
    "${CMAKE_SOURCE_DIR}/tests/tcl/integration/sc_base_smoke.tcl" )
set(
    TCL_BRIDGE_FILTER_TREE_TEST_RUNNER
    "${CMAKE_SOURCE_DIR}/tests/tcl/integration/sc_filter_tree_state.tcl" )
set(
    TCL_BRIDGE_GAME_STATE_TEST_RUNNER
    "${CMAKE_SOURCE_DIR}/tests/tcl/integration/sc_game_state.tcl" )

add_test(
    NAME tcl_bridge_test
    COMMAND
    "${CMAKE_COMMAND}" -E chdir "${CMAKE_SOURCE_DIR}"
    "$<TARGET_FILE:ScidUp::Bins::Main>" "${TCL_BRIDGE_TEST_RUNNER}" )
add_test(
    NAME tcl_bridge_filter_tree_test
    COMMAND
    "${CMAKE_COMMAND}" -E chdir "${CMAKE_SOURCE_DIR}"
    "$<TARGET_FILE:ScidUp::Bins::Main>" "${TCL_BRIDGE_FILTER_TREE_TEST_RUNNER}" )
add_test(
    NAME tcl_bridge_game_state_test
    COMMAND
    "${CMAKE_COMMAND}" -E chdir "${CMAKE_SOURCE_DIR}"
    "$<TARGET_FILE:ScidUp::Bins::Main>" "${TCL_BRIDGE_GAME_STATE_TEST_RUNNER}" )

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
set_tests_properties(
    tcl_bridge_filter_tree_test
    PROPERTIES
    ENVIRONMENT "PATH=${_tcl_bin_dir}:$ENV{PATH};LD_LIBRARY_PATH=${_tcl_lib_dir}:$ENV{LD_LIBRARY_PATH};DYLD_LIBRARY_PATH=${_tcl_lib_dir}:$ENV{DYLD_LIBRARY_PATH}"
    LABELS "tcl;bridge" )
set_tests_properties(
    tcl_bridge_game_state_test
    PROPERTIES
    ENVIRONMENT "PATH=${_tcl_bin_dir}:$ENV{PATH};LD_LIBRARY_PATH=${_tcl_lib_dir}:$ENV{LD_LIBRARY_PATH};DYLD_LIBRARY_PATH=${_tcl_lib_dir}:$ENV{DYLD_LIBRARY_PATH}"
    LABELS "tcl;bridge" )

add_custom_target(
    tcl_bridge_tests
    COMMAND "${CMAKE_CTEST_COMMAND}" -L "bridge" --output-on-failure
    VERBATIM )
