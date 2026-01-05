if(NOT DEFINED CMAKE_SCRIPT_MODE_FILE)
  option(SCIDUP_BUILD_LINTING "Build developer lint targets" OFF)
  if(NOT SCIDUP_BUILD_LINTING)
    return()
  endif()

  add_custom_target(tcl_lint
          COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_LIST_FILE}"
          WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
          COMMENT "Running Tcl lint (tclint via uvx) on ../tcl"
          VERBATIM
  )
  return()
endif()

###############################################################################

find_program(UVX_EXECUTABLE uvx REQUIRED)

	get_filename_component(_tcl_dir "${CMAKE_CURRENT_LIST_DIR}/../../tcl" ABSOLUTE)
file(GLOB_RECURSE _tcl_files
        LIST_DIRECTORIES false
        "${_tcl_dir}/*.tcl"
        "${_tcl_dir}/*.test"
)
list(FILTER _tcl_files EXCLUDE REGEX "([/\\\\])tcl([/\\\\])lang([/\\\\])")
list(FILTER _tcl_files EXCLUDE REGEX "([/\\\\])tcl([/\\\\])help([/\\\\])")
list(SORT _tcl_files)

set(_violations "")
foreach(_f IN LISTS _tcl_files)
  execute_process(
          COMMAND "${UVX_EXECUTABLE}" tclint "${_f}"
          RESULT_VARIABLE _rv
          COMMAND_ECHO STDOUT
  )
  if(NOT _rv EQUAL 0)
    string(APPEND _violations "  ${_f}\n")
  endif()
endforeach()

if(NOT _violations STREQUAL "")
  message(WARNING "Tcl linting failed on violations.")
endif()
