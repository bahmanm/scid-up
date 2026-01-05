if(NOT DEFINED BUILD_TESTING)
  set(BUILD_TESTING OFF CACHE BOOL "Build tests")
endif()

include(CTest)
if(NOT BUILD_TESTING)
  return()
endif()

### cpp_test
add_subdirectory(gtest)

add_test(
  NAME cpp_test
  COMMAND $<TARGET_FILE:ScidUp::Tests::Bins::CppTest>
)
set_tests_properties(
  cpp_test
  PROPERTIES
  LABELS "cpp"
)

### tcl_test
set(TCL_TEST_RUNNER "${CMAKE_SOURCE_DIR}/tcl/tests/run_all_tests.tcl")

add_test(
  NAME tcl_test
  COMMAND
  "${CMAKE_COMMAND}" -E chdir "${CMAKE_SOURCE_DIR}"
  "${TCL_TCLSH}" "${TCL_TEST_RUNNER}"
)

get_filename_component(_tcl_bin_dir "${TCL_TCLSH}" DIRECTORY)
get_filename_component(_tcl_lib_dir "${TCL_LIBRARY}" DIRECTORY)
set_tests_properties(tcl_test
  PROPERTIES
  ENVIRONMENT "PATH=${_tcl_bin_dir}:$ENV{PATH};LD_LIBRARY_PATH=${_tcl_lib_dir}:$ENV{LD_LIBRARY_PATH}"
  LABELS "tcl"
)
