namespace eval ::scid_test {}
namespace eval ::scid_test::menu_structure {}

# Extracts a deterministic structural model of captured menu widgets.
#
# This module consumes the menu capture state recorded by
# `::scid_test::menu_capture` and serialises it as a nested Tcl list using a
# stable key order. It is designed for:
#   - baseline comparisons (approved reference structures); and
#   - semantic menu specs (“menu path X must exist”).

proc ::scid_test::menu_structure::defaultDynamicMenus {} {
    # Menus whose contents are expected to be runtime-populated and/or depend on
    # external state (filesystem, installed themes, available languages, etc.).
    #
    # For such menus we record their existence, but do not snapshot their
    # entries. This keeps the baseline stable whilst remaining strict about the
    # UI skeleton.
    return [list \
        .menu.file.bookmarks \
        .menu.file.recent \
        .menu.file.recenttrees \
        .menu.db.copygames \
        .menu.db.importfile \
        .menu.options.language \
        .menu.options.theme \
    ]
}

proc ::scid_test::menu_structure::snapshot {menuPath args} {
    array set opts {
        -dynamicMenus {}
    }
    array set opts $args

    set dynamicSet {}
    foreach m $opts(-dynamicMenus) {
        dict set dynamicSet $m 1
    }

    return [::scid_test::menu_structure::_snapshotMenu $menuPath $dynamicSet]
}

proc ::scid_test::menu_structure::format {snapshot} {
    # Produces a stable, diff-friendly multi-line representation of a snapshot.
    # The output is a valid Tcl list string (with newlines for readability).
    return [join [::scid_test::menu_structure::_formatSnapshotLines $snapshot 0] "\n"]
}

proc ::scid_test::menu_structure::_snapshotMenu {menuPath dynamicSetDict} {
    if {[dict exists $dynamicSetDict $menuPath]} {
        return [list menu $menuPath dynamic 1]
    }

    set entries [::scid_test::menu_capture::entries $menuPath]
    set outEntries {}

    foreach entry $entries {
        set type [dict get $entry type]
        if {$type eq "tearoff"} {
            continue
        }

        set label [dict get $entry -label]
        set state [dict get $entry -state]
        set underline [dict get $entry -underline]

        set acc ""
        if {[dict exists $entry -acc]} {
            set acc [dict get $entry -acc]
        } elseif {[dict exists $entry -accelerator]} {
            set acc [dict get $entry -accelerator]
        }

        set submenuSnapshot {}
        if {$type eq "cascade"} {
            if {![dict exists $entry -menu]} {
                error "cascade entry missing -menu for $menuPath: $entry"
            }
            set submenuPath [dict get $entry -menu]
            set submenuSnapshot [::scid_test::menu_structure::_snapshotMenu $submenuPath $dynamicSetDict]
        }

        lappend outEntries [list \
            type $type \
            label $label \
            acc $acc \
            state $state \
            underline $underline \
            submenu $submenuSnapshot \
        ]
    }

    return [list menu $menuPath dynamic 0 entries $outEntries]
}

proc ::scid_test::menu_structure::_formatSnapshotLines {snapshot depth} {
    set indent [string repeat "  " $depth]

    if {[llength $snapshot] < 4 || [lindex $snapshot 0] ne "menu"} {
        error "Invalid menu snapshot: $snapshot"
    }

    set menuPath [lindex $snapshot 1]
    set attrs [dict create]
    foreach {k v} [lrange $snapshot 2 end] {
        dict set attrs $k $v
    }

    set dynamic [dict get $attrs dynamic]
    if {$dynamic} {
        return [list "${indent}menu $menuPath dynamic 1"]
    }

    if {![dict exists $attrs entries]} {
        error "Non-dynamic menu snapshot missing entries: $snapshot"
    }

    set lines {}
    lappend lines "${indent}menu $menuPath dynamic 0 entries \{"

    foreach entry [dict get $attrs entries] {
        set entryLines [::scid_test::menu_structure::_formatEntryLines $entry [expr {$depth + 1}]]
        foreach line $entryLines {
            lappend lines $line
        }
    }

    lappend lines "${indent}\}"
    return $lines
}

proc ::scid_test::menu_structure::_formatEntryLines {entry depth} {
    set indent [string repeat "  " $depth]

    set attrs [dict create]
    foreach {k v} $entry {
        dict set attrs $k $v
    }

    set type [dict get $attrs type]
    set label [dict get $attrs label]
    set acc [dict get $attrs acc]
    set state [dict get $attrs state]
    set underline [dict get $attrs underline]
    set submenu [dict get $attrs submenu]

    set head [list type $type label $label acc $acc state $state underline $underline]

    if {$submenu eq {}} {
        return [list "${indent}\{${head} submenu \{\}\}"]
    }

    set lines {}
    lappend lines "${indent}\{${head} submenu \{"

    foreach line [::scid_test::menu_structure::_formatSnapshotLines $submenu [expr {$depth + 1}]] {
        lappend lines $line
    }

    lappend lines "${indent}\}\}"
    return $lines
}
