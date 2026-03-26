proc progressCallBack {done {msg ""}} {
    return 1
}

proc assertEq {expected actual message} {
    if {$expected ne $actual} {
        error "$message\nexpected: <$expected>\nactual:   <$actual>"
    }
}

proc assertListEq {expected actual message} {
    set expectedList [list {*}$expected]
    set actualList [list {*}$actual]
    if {$expectedList ne $actualList} {
        error "$message\nexpected: <$expectedList>\nactual:   <$actualList>"
    }
}

set root [file normalize [file join [pwd] tests tcl _tmp sc_base_bridge__[pid]__[clock clicks -milliseconds]]]
file mkdir $root

set exitCode 0

try {
    set clipbase [sc_base current]
    assertEq 9 $clipbase "clipbase handle should be current at startup"
    assertEq 1 [sc_base inUse $clipbase] "clipbase should be marked in use"
    assertListEq {9} [lsort -integer [sc_base list]] "only clipbase should be open initially"

    set db1 [file join $root db1.si5]
    set db2 [file join $root db2.si5]

    set handle1 [sc_base create SCID5 $db1]
    assertEq 1 $handle1 "first created database should use slot 1"
    assertEq $handle1 [sc_base current] "creating a database should switch current slot"
    assertEq 1 [sc_base inUse] "current slot should report in use"
    assertEq 1 [sc_base inUse $handle1] "first database should be marked in use"
    assertEq $db1 [sc_base filename $handle1] "filename should round-trip for first database"
    assertEq $handle1 [sc_base slot $db1] "slot lookup should find first database"

    set handle2 [sc_base create SCID5 $db2]
    assertEq 2 $handle2 "second created database should use slot 2"
    assertEq $handle2 [sc_base current] "second create should become current"
    assertEq 1 [sc_base inUse $handle2] "second database should be marked in use"
    assertEq $db2 [sc_base filename $handle2] "filename should round-trip for second database"
    assertEq $handle2 [sc_base slot $db2] "slot lookup should find second database"
    assertListEq {1 2 9} [lsort -integer [sc_base list]] "list should include both databases and clipbase"

    sc_base switch $handle1
    assertEq $handle1 [sc_base current] "switch should update current database"

    sc_base close $handle1
    assertEq 0 [sc_base inUse $handle1] "closed slot should report not in use"
    assertEq 0 [sc_base slot $db1] "closed database should no longer be found by slot"
    assertListEq {2 9} [lsort -integer [sc_base list]] "list should drop the closed database"

    set reopened [sc_base open SCID5 $db1]
    assertEq 1 $reopened "reopened database should reuse the freed slot"
    assertEq 1 [sc_base inUse $reopened] "reopened database should be marked in use"
    assertEq $db1 [sc_base filename $reopened] "reopened filename should match original path"
    assertListEq {1 2 9} [lsort -integer [sc_base list]] "list should include reopened database"
} on error {msg opts} {
    puts stderr $msg
    puts stderr [dict get $opts -errorinfo]
    set exitCode 1
} finally {
    foreach handle [sc_base list] {
        if {$handle == 9} {
            continue
        }
        catch {sc_base close $handle}
    }
    file delete -force $root
}

exit $exitCode
