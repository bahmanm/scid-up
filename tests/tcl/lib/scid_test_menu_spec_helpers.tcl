namespace eval ::scid_test {}
namespace eval ::scid_test::menu_spec {}

# Shared helpers for GUI/menu "spec" suites that reason about menu-structure
# snapshots produced by `::scid_test::menu_structure`.

proc ::scid_test::menu_spec::attrs {snapshot} {
    if {[llength $snapshot] < 4 || [lindex $snapshot 0] ne "menu"} {
        error "Invalid menu snapshot: $snapshot"
    }

    set attrs [dict create path [lindex $snapshot 1]]
    foreach {k v} [lrange $snapshot 2 end] {
        dict set attrs $k $v
    }
    return $attrs
}

proc ::scid_test::menu_spec::path {snapshot} {
    return [dict get [::scid_test::menu_spec::attrs $snapshot] path]
}

proc ::scid_test::menu_spec::entries {menuSnapshot} {
    set attrs [::scid_test::menu_spec::attrs $menuSnapshot]
    if {[dict get $attrs dynamic]} {
        return {}
    }
    return [dict get $attrs entries]
}

proc ::scid_test::menu_spec::entryDict {entryKvList} {
    return [dict create {*}$entryKvList]
}

proc ::scid_test::menu_spec::findEntryByLabel {menuSnapshot label} {
    foreach entry [::scid_test::menu_spec::entries $menuSnapshot] {
        set d [::scid_test::menu_spec::entryDict $entry]
        if {[dict get $d label] eq $label} {
            return $d
        }
    }
    error "Menu [::scid_test::menu_spec::path $menuSnapshot] has no entry labelled: $label"
}

proc ::scid_test::menu_spec::submenuOfCascade {menuSnapshot label} {
    set entry [::scid_test::menu_spec::findEntryByLabel $menuSnapshot $label]
    if {[dict get $entry type] ne "cascade"} {
        error "Entry '$label' is not a cascade (got: [dict get $entry type])"
    }
    return [dict get $entry submenu]
}

proc ::scid_test::menu_spec::entryState {menuSnapshot label} {
    set entry [::scid_test::menu_spec::findEntryByLabel $menuSnapshot $label]
    return [dict get $entry state]
}

proc ::scid_test::menu_spec::typeLabelPairs {menuSnapshot} {
    set out {}
    foreach entry [::scid_test::menu_spec::entries $menuSnapshot] {
        set d [::scid_test::menu_spec::entryDict $entry]
        lappend out [list [dict get $d type] [dict get $d label]]
    }
    return $out
}

proc ::scid_test::menu_spec::assertCommandAcc {menuSnapshot label expectedAcc} {
    set entry [::scid_test::menu_spec::findEntryByLabel $menuSnapshot $label]
    if {[dict get $entry type] ne "command"} {
        error "Entry '$label' is not a command (got: [dict get $entry type])"
    }
    set actual [dict get $entry acc]
    if {$actual ne $expectedAcc} {
        error "Entry '$label' accelerator mismatch (expected '$expectedAcc', got '$actual')"
    }
}

