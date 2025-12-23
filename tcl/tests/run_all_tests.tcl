package require tcltest 2.5

namespace import ::tcltest::*

set testDir [file dirname [info script]]

set testFilePatterns [list "*.test" "tools/*.test"]

tcltest::configure \
    -testdir $testDir \
    -verbose {start pass skip fail error} \
    -match * \
    -file $testFilePatterns \
    -singleproc 1

set exitCode [expr {[tcltest::runAllTests] != 0}]
tcltest::cleanupTests
exit $exitCode
