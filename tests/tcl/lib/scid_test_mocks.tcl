namespace eval ::scid_test {}
namespace eval ::scid_test::mocks {}

if {![info exists ::scid_test::mocks::counter]} {
    set ::scid_test::mocks::counter 0
}

if {![info exists ::scid_test::mocks::allowRenameRealCommands]} {
    # When set to 0, `stubCommand` will refuse to rename an existing command (it
    # will error instead). This can be useful when running tests inside a richer
    # interpreter (e.g. `wish`) where renaming real commands is undesirable.
    set ::scid_test::mocks::allowRenameRealCommands 1
}

# `stubCommand` / `restoreStubs`
#
# Intended usage pattern (per test suite):
#   - Keep a suite-local registry variable (e.g. `variable stubbedCommands {}`).
#   - In per-test setup: `::scid_test::mocks::restoreStubs stubbedCommands`.
#   - During test bodies: `::scid_test::mocks::stubCommand stubbedCommands ...`.
#   - In per-test cleanup: `::scid_test::mocks::restoreStubs stubbedCommands`.
#
# This avoids clobbering real commands in richer environments and keeps stubs
# isolated between test suites.

proc ::scid_test::mocks::stubCommand {registryVar commandName argList body} {
    upvar 1 $registryVar registry

    set fqName $commandName
    if {![string match "::*" $fqName]} {
        set fqName "::$fqName"
    }

    if {[llength [info commands $fqName]]} {
        if {!$::scid_test::mocks::allowRenameRealCommands} {
            error "Refusing to rename existing command $fqName; set ::scid_test::mocks::allowRenameRealCommands to 1 to override"
        }
        incr ::scid_test::mocks::counter
        set orig "${fqName}__scid_test_orig$::scid_test::mocks::counter"
        rename $fqName $orig
        lappend registry [list $fqName $orig]
    } else {
        lappend registry [list $fqName ""]
    }

    proc $fqName $argList $body
}

proc ::scid_test::mocks::restoreStubs {registryVar} {
    upvar 1 $registryVar registry

    # Restore in reverse order (LIFO) so repeated stubbing of the same command
    # unwinds correctly to the original implementation.
    for {set i [expr {[llength $registry] - 1}]} {$i >= 0} {incr i -1} {
        lassign [lindex $registry $i] name orig
        if {[llength [info commands $name]]} {
            rename $name ""
        }
        if {$orig ne ""} {
            rename $orig $name
        }
    }

    set registry {}
}
