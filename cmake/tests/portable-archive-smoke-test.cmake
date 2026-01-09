string( RANDOM LENGTH 8 ALPHABET "abcdefghijklmnopqrstuvwxyz0123456789" _scidup_smoke_suffix )
set( _scidup_staging_root "${SCIDUP_BUILD_DIR}/_portable-archive-smoke-${_scidup_smoke_suffix}" )
file( MAKE_DIRECTORY "${_scidup_staging_root}" )

execute_process(
    COMMAND
    "${SCIDUP_CMAKE_COMMAND}" -E env
    "DESTDIR=${_scidup_staging_root}"
    "${SCIDUP_CMAKE_COMMAND}" --install "${SCIDUP_BUILD_DIR}"
    RESULT_VARIABLE _scidup_install_result
)
if( NOT _scidup_install_result EQUAL 0 )
    message( FATAL_ERROR "Failed to stage the installation tree via 'cmake --install'." )
endif()

set( _scidup_installed_executable "${_scidup_staging_root}/bin/${SCIDUP_INSTALLED_EXECUTABLE_NAME}" )

set( _scidup_smoke_script "${_scidup_staging_root}/smoke.tcl" )
file(
    WRITE
    "${_scidup_smoke_script}"
    "puts \"patchlevel=[info patchlevel]\"\n"
    "puts \"library=[info library]\"\n"
    "puts \"tcl_library=$tcl_library\"\n"
    "if {[info exists tk_library]} { puts \"tk_library=$tk_library\" }\n"
    "if {[info exists env(TCL_LIBRARY)]} { puts \"env(TCL_LIBRARY)=$env(TCL_LIBRARY)\" }\n"
    "if {[info exists env(TK_LIBRARY)]} { puts \"env(TK_LIBRARY)=$env(TK_LIBRARY)\" }\n"
    "exit\n"
)

execute_process(
    COMMAND "${_scidup_installed_executable}" "${_scidup_smoke_script}"
    RESULT_VARIABLE _scidup_smoke_result
    OUTPUT_VARIABLE _scidup_smoke_output
    ERROR_VARIABLE _scidup_smoke_error
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
if( NOT _scidup_smoke_result EQUAL 0 )
    message( FATAL_ERROR "Portable archive smoke-test failed." )
endif()

set( _scidup_combined_output "${_scidup_smoke_output}\n${_scidup_smoke_error}" )

string( REGEX MATCH "(^|[\n\r])patchlevel=([0-9]+\\.[0-9]+\\.[0-9]+)" _scidup_patchlevel_match "${_scidup_combined_output}" )
set( _scidup_patchlevel "${CMAKE_MATCH_2}" )

string( REGEX MATCH "^([0-9]+)\\.([0-9]+)\\." _scidup_patchlevel_components "${_scidup_patchlevel}" )
if(
    NOT DEFINED CMAKE_MATCH_1 OR "${CMAKE_MATCH_1}" STREQUAL ""
    OR NOT DEFINED CMAKE_MATCH_2 OR "${CMAKE_MATCH_2}" STREQUAL ""
)
    message( FATAL_ERROR "Unexpected patchlevel format: ${_scidup_patchlevel}" )
endif()
set( _scidup_tcl_version_major "${CMAKE_MATCH_1}" )
set( _scidup_tcl_version_minor "${CMAKE_MATCH_2}" )

set( _scidup_expected_tcl_library_dir "${_scidup_staging_root}/lib/tcl${_scidup_tcl_version_major}.${_scidup_tcl_version_minor}" )
set( _scidup_expected_tk_library_dir "${_scidup_staging_root}/lib/tk${_scidup_tcl_version_major}.${_scidup_tcl_version_minor}" )

get_filename_component( _scidup_expected_tcl_library_dir "${_scidup_expected_tcl_library_dir}" REALPATH )
get_filename_component( _scidup_expected_tk_library_dir "${_scidup_expected_tk_library_dir}" REALPATH )

function( _scidup_extract_value output_variable key output )
    string( REGEX MATCH "(^|[\n\r])${key}=([^\n\r]*)" _match "${output}" )
    if( NOT CMAKE_MATCH_2 )
        message( FATAL_ERROR "Missing '${key}' in smoke-test output." )
    endif()
    set( "${output_variable}" "${CMAKE_MATCH_2}" PARENT_SCOPE )
endfunction()

_scidup_extract_value( _scidup_value_library "library" "${_scidup_combined_output}" )
_scidup_extract_value( _scidup_value_tcl_library "tcl_library" "${_scidup_combined_output}" )
_scidup_extract_value( _scidup_value_tk_library "tk_library" "${_scidup_combined_output}" )
_scidup_extract_value( _scidup_value_env_tcl_library "env\\(TCL_LIBRARY\\)" "${_scidup_combined_output}" )
_scidup_extract_value( _scidup_value_env_tk_library "env\\(TK_LIBRARY\\)" "${_scidup_combined_output}" )

foreach( _scidup_key IN ITEMS
    _scidup_value_library
    _scidup_value_tcl_library
    _scidup_value_tk_library
    _scidup_value_env_tcl_library
    _scidup_value_env_tk_library
)
    # Values are validated by _scidup_extract_value.
endforeach()

get_filename_component( _scidup_value_library_real "${_scidup_value_library}" REALPATH )
get_filename_component( _scidup_value_tcl_library_real "${_scidup_value_tcl_library}" REALPATH )
get_filename_component( _scidup_value_tk_library_real "${_scidup_value_tk_library}" REALPATH )
get_filename_component( _scidup_value_env_tcl_library_real "${_scidup_value_env_tcl_library}" REALPATH )
get_filename_component( _scidup_value_env_tk_library_real "${_scidup_value_env_tk_library}" REALPATH )

if( NOT _scidup_value_library_real STREQUAL _scidup_expected_tcl_library_dir )
    message( FATAL_ERROR "Unexpected info library." )
endif()
if( NOT _scidup_value_tcl_library_real STREQUAL _scidup_expected_tcl_library_dir )
    message( FATAL_ERROR "Unexpected tcl_library." )
endif()
if( NOT _scidup_value_env_tcl_library_real STREQUAL _scidup_expected_tcl_library_dir )
    message( FATAL_ERROR "Unexpected env(TCL_LIBRARY)." )
endif()
if( NOT _scidup_value_tk_library_real STREQUAL _scidup_expected_tk_library_dir )
    message( FATAL_ERROR "Unexpected tk_library." )
endif()
if( NOT _scidup_value_env_tk_library_real STREQUAL _scidup_expected_tk_library_dir )
    message( FATAL_ERROR "Unexpected env(TK_LIBRARY)." )
endif()

# Best-effort cleanup.
file( REMOVE_RECURSE "${_scidup_staging_root}" )
