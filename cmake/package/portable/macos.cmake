include_guard( GLOBAL )

if( NOT APPLE )
    return()
endif()

if( NOT SCIDUP_BUNDLE_TCL_TK )
    return()
endif()

###############################################################################
# Dylib install-name fixups for the application binary.
#
# Ensure the installed binary uses a relative install name for the bundled Tcl/Tk.
#
# Note: The bundled Tcl/Tk are built with zipfs; their Mach-O binaries include a
# trailing zip archive, which makes them unsuitable for patching with
# install_name_tool. Instead, patch the application binary to load the bundled
# dylibs via @rpath.
###############################################################################

if( SCIDUP_BUNDLE_TCL_TK )
    get_filename_component( _scidup_tcl_library_name "${TCL_LIBRARY}" NAME )
    get_filename_component( _scidup_tk_library_name "${TK_LIBRARY}" NAME )

    install(
        CODE
        "
        set( _scidup_destdir \"\$ENV{DESTDIR}\" )

        # Note: CMAKE_INSTALL_BINDIR is not reliably available at install time.
        # Capture its configured value now and embed it into the install script.
        set( _scidup_install_bindir \"${CMAKE_INSTALL_BINDIR}\" )

        set( _scidup_exe_path \"\${_scidup_destdir}\${CMAKE_INSTALL_PREFIX}\${_scidup_install_bindir}/scid-up\" )
        cmake_path( NORMAL_PATH _scidup_exe_path )

        if( NOT EXISTS \"\${_scidup_exe_path}\" )
            message( FATAL_ERROR \"Expected installed executable does not exist: \${_scidup_exe_path}\\n\" )
        endif()

        execute_process(
            COMMAND otool -L \"\${_scidup_exe_path}\"
            RESULT_VARIABLE _scidup_otool_result
            OUTPUT_VARIABLE _scidup_otool_output
            ERROR_VARIABLE _scidup_otool_error
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        if( NOT _scidup_otool_result EQUAL 0 )
            message(
                FATAL_ERROR
                \"Failed to inspect dylib dependencies for: \${_scidup_exe_path}\\n\"
                \"stderr:\\n\${_scidup_otool_error}\\n\"
            )
        endif()

        set( _scidup_fixups
            \"${TCL_LIBRARY}|@rpath/${_scidup_tcl_library_name}\"
            \"${TK_LIBRARY}|@rpath/${_scidup_tk_library_name}\"
        )

        foreach( _scidup_fixup IN LISTS _scidup_fixups )
            string( REPLACE \"|\" \";\" _scidup_fixup_parts \"\${_scidup_fixup}\" )
            list( GET _scidup_fixup_parts 0 _scidup_old_install_name )
            list( GET _scidup_fixup_parts 1 _scidup_new_install_name )

            string( FIND \"\${_scidup_otool_output}\" \"\${_scidup_old_install_name}\" _scidup_dep_index )
            if( _scidup_dep_index EQUAL -1 )
                continue()
            endif()

            execute_process(
                COMMAND install_name_tool -change \"\${_scidup_old_install_name}\" \"\${_scidup_new_install_name}\" \"\${_scidup_exe_path}\"
                RESULT_VARIABLE _scidup_install_name_tool_result
                ERROR_VARIABLE _scidup_install_name_tool_error
                OUTPUT_STRIP_TRAILING_WHITESPACE
            )
            if( NOT _scidup_install_name_tool_result EQUAL 0 )
                message(
                    FATAL_ERROR
                    \"Failed to rewrite dylib install name in: \${_scidup_exe_path}\\n\"
                    \"old=\${_scidup_old_install_name}\\n\"
                    \"new=\${_scidup_new_install_name}\\n\"
                    \"stderr:\\n\${_scidup_install_name_tool_error}\\n\"
                )
            endif()
        endforeach()
        "
    )
endif()

###############################################################################