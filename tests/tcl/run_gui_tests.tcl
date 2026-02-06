# Entry point for running ScidUp GUI structural tests under plain `tclsh`.
#
# This runner intentionally executes each suite in a fresh interpreter (via
# `run_one_test.tcl`) to maximise isolation.

set testsDir [file dirname [info script]]
set runner [file join $testsDir run_one_test.tcl]
set tclsh [info nameofexecutable]

set patterns [list "gui/baseline/*.test" "gui/spec/*.test"]
set suiteFiles {}

foreach pattern $patterns {
    foreach file [glob -nocomplain -directory $testsDir $pattern] {
        # Tcl 8.5 compatibility: `file relative` does not exist.
        set base [file normalize $testsDir]
        set abs [file normalize $file]
        if {[string first $base $abs] == 0} {
            set rel [string range $abs [expr {[string length $base] + 1}] end]
        } else {
            set rel [file tail $file]
        }

        if {[string match "l.*.test" [file tail $rel]]} {
            continue
        }

        lappend suiteFiles $rel
    }
}

set suiteFiles [lsort -unique $suiteFiles]

set anyFailed 0
foreach rel $suiteFiles {
    set cmd [list $tclsh $runner $rel]
    set rc [catch {exec {*}$cmd >@stdout 2>@stderr} err opts]
    if {$rc != 0} {
        set anyFailed 1

        if {[dict exists $opts -errorcode] && [lindex [dict get $opts -errorcode] 0] eq "CHILDSTATUS"} {
            set status [lindex [dict get $opts -errorcode] 2]
            puts stderr "Suite failed ($status): $rel"
        } else {
            puts stderr "Suite failed: $rel"
            puts stderr $err
        }
    }
}

exit $anyFailed

