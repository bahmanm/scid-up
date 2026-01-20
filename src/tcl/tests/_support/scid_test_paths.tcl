namespace eval ::scid_test {}

if {![info exists ::scid_test::testsDir]} {
    set ::scid_test::testsDir [file dirname [file dirname [info script]]]
}

if {![info exists ::scid_test::repoRoot]} {
    set ::scid_test::repoRoot [file normalize [file join $::scid_test::testsDir .. ..]]
}

if {![info exists ::scid_test::tclDir]} {
    set ::scid_test::tclDir [file normalize [file join $::scid_test::repoRoot tcl]]
}

proc ::scid_test::repoRoot {} {
    return $::scid_test::repoRoot
}

proc ::scid_test::tclDir {} {
    return $::scid_test::tclDir
}

proc ::scid_test::tempDir {} {
    set dir [file normalize [file join $::scid_test::testsDir _tmp]]
    file mkdir $dir
    return $dir
}
