namespace eval ::scid_test {}
namespace eval ::scid_test::baseline_io {}

# Simple file I/O helpers for baseline artefacts stored as Tcl list strings.
#
# The baseline format is intentionally plain:
#   - any line whose first non-whitespace character is `#` is a comment;
#   - blank lines are ignored;
#   - the remaining lines are concatenated as-is.
#
# This keeps baseline files readable whilst allowing exact string comparisons in
# tests (after comment/blank stripping).

# Reads a baseline file, stripping comments and blank lines.
proc ::scid_test::baseline_io::readListFile {path} {
    if {![file exists $path]} {
        error "Baseline file does not exist: $path"
    }

    set ch [open $path r]
    set raw [read $ch]
    close $ch

    set kept {}
    foreach line [split $raw "\n"] {
        set trimmed [string trim $line]
        if {$trimmed eq ""} { continue }
        if {[string match "#*" $trimmed]} { continue }
        lappend kept $line
    }

    return [string trim [join $kept "\n"]]
}

# Writes a baseline file, optionally prefixing it with comment header lines.
proc ::scid_test::baseline_io::writeListFile {path value {headerLines {}}} {
    file mkdir [file dirname $path]

    set ch [open $path w]

    foreach line $headerLines {
        puts $ch "# $line"
    }
    if {[llength $headerLines]} {
        puts $ch ""
    }

    puts $ch $value
    close $ch
}

proc ::scid_test::baseline_io::unifiedDiff {expected actual} {
    set dir [::scid_test::tempDir]
    set pid [pid]
    set ts [clock seconds]

    set expectedFile [file join $dir "baseline_expected_${pid}_${ts}.txt"]
    set actualFile [file join $dir "baseline_actual_${pid}_${ts}.txt"]

    ::scid_test::baseline_io::writeListFile $expectedFile $expected
    ::scid_test::baseline_io::writeListFile $actualFile $actual

    set rc [catch {exec diff -u $expectedFile $actualFile} out]
    if {$rc == 0} {
        return ""
    }

    # When `diff` exits with status 1, Tcl appends "child process exited
    # abnormally" to the captured output. Strip it for readability.
    set suffix "\nchild process exited abnormally"
    if {[string match "*$suffix" $out]} {
        set out [string range $out 0 end-[string length $suffix]]
    }

    return [string trim $out]
}
