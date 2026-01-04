enable_testing()

### gtest
add_subdirectory(gtest)

add_custom_target(scid_test
        COMMAND "${CMAKE_CTEST_COMMAND}" --output-on-failure -R "^gtest$"
        DEPENDS scid_test_bin
        WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
        COMMENT "Building and running GoogleTest (ctest -R gtest)"
)

add_test(
        NAME scid_test
        COMMAND $<TARGET_FILE:scid_test_bin>
)

### tcl_test
set(TCL_TEST_RUNNER "${CMAKE_SOURCE_DIR}/tcl/tests/run_all_tests.tcl")

add_custom_target(tcl_test
        COMMAND
        "${CMAKE_COMMAND}" -E chdir "${CMAKE_SOURCE_DIR}"
        "${TCL_TCLSH}" "${TCL_TEST_RUNNER}"
        COMMENT "Running Tcl tests"
)

add_test(
        NAME tcl_test
        COMMAND
        "${CMAKE_COMMAND}" -E chdir "${CMAKE_SOURCE_DIR}"
        "${TCL_TCLSH}" "${TCL_TEST_RUNNER}"
)
