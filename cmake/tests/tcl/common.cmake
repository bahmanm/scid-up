function( scidup_configure_tcl_test _test_name _labels )
    get_filename_component(
        _tcl_bin_dir
        "${TCL_TCLSH}" DIRECTORY )
    get_filename_component(
        _tcl_lib_dir
        "${TCL_LIBRARY}" DIRECTORY )

    if( WIN32 )
        set( _scidup_test_path "${_tcl_bin_dir};$ENV{PATH}" )
        string( REPLACE ";" "\\;" _scidup_test_path "${_scidup_test_path}" )
        set( _scidup_test_env "PATH=${_scidup_test_path}" )
    elseif( APPLE )
        set(
            _scidup_test_env
            "PATH=${_tcl_bin_dir}:$ENV{PATH}"
            "DYLD_LIBRARY_PATH=${_tcl_lib_dir}:$ENV{DYLD_LIBRARY_PATH}" )
    else()
        set(
            _scidup_test_env
            "PATH=${_tcl_bin_dir}:$ENV{PATH}"
            "LD_LIBRARY_PATH=${_tcl_lib_dir}:$ENV{LD_LIBRARY_PATH}" )
    endif()

    set_tests_properties(
        "${_test_name}"
        PROPERTIES
        ENVIRONMENT "${_scidup_test_env}"
        LABELS "${_labels}" )
endfunction()
