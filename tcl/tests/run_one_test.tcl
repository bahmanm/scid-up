package require tcltest 2.5

namespace import ::tcltest::*

set testDir [file dirname [info script]]
set testFile [lindex $argv 0]

if {$testFile eq ""} {
    puts stderr "Usage: tclsh tcl/tests/run_one_test.tcl <testFileRelativeToTestsDir>"
    exit 2
}

tcltest::configure \
    -testdir $testDir \
    -verbose {start pass skip fail error} \
    -match * \
    -file [list $testFile] \
    -singleproc 1

set exitCode [expr {[tcltest::runAllTests] != 0}]
tcltest::cleanupTests
exit $exitCode

