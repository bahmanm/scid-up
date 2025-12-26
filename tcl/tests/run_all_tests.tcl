#
# Entry point for running a subset of Scid Tcl tests under plain `tclsh`.
#
# These tests are intentionally executed in a fresh interpreter per test suite
# to maximise isolation (and to reduce the chance of cross-suite state bleed).
#

set testsDir [file dirname [info script]]
set runner [file join $testsDir run_one_test.tcl]
set tclsh [info nameofexecutable]

set patterns [list "*.test" "tools/*.test" "file/*.test"]
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

        # `exec` throws on non-zero exit status. Preserve the signal that a test
        # suite failed but keep running subsequent suites.
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
