# Entry point for running a subset of Scid Tcl tests under plain `tclsh`
# (i.e. without Tk and without the C++ `sc_*` command bridge).

namespace eval ::scid_test {}

set _supportDir [file dirname [info script]]

source [file join $_supportDir scid_test_paths.tcl]
source [file join $_supportDir scid_test_stubs.tcl]
source [file join $_supportDir scid_test_fixtures.tcl]
source [file join $_supportDir scid_test_mocks.tcl]
source [file join $_supportDir scid_test_widgets.tcl]
source [file join $_supportDir scid_test_menu_capture.tcl]
source [file join $_supportDir scid_test_baseline_io.tcl]

unset _supportDir
