namespace eval ::scid_test {}

if {![info exists ::scid_test::testsDir]} {
    set ::scid_test::testsDir [file dirname [file dirname [info script]]]
}

if {![info exists ::scid_test::repoRoot]} {
    set ::scid_test::repoRoot [file normalize [file join $::scid_test::testsDir .. ..]]
}

if {![info exists ::scid_test::tclDir]} {
    set ::scid_test::tclDir [file normalize [file join $::scid_test::repoRoot src tcl]]
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

proc ::scid_test::makeTempRoot {suiteName} {
    # Creates a per-suite temp root under `tests/tcl/_tmp` and returns it.
    # The caller is responsible for deleting it (typically in suite cleanup).
    set base [::scid_test::tempDir]
    set safeName [string map {:: _ / _ \\ _ " " _ : _} $suiteName]
    set root [file join $base ${safeName}__[pid]__[clock clicks -milliseconds]]
    file mkdir $root
    return $root
}

proc ::scid_test::deleteTempRoot {path} {
    if {$path eq ""} {
        return
    }
    if {![file exists $path]} {
        return
    }

    set base [file normalize [::scid_test::tempDir]]
    set normPath [file normalize $path]
    set basePrefix "${base}[file separator]"
    if {$normPath ne $base && ![string match "${basePrefix}*" $normPath]} {
        error "Refusing to delete temp path outside $base: $path"
    }

    file delete -force $normPath
}
