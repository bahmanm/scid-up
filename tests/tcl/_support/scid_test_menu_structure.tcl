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
        .menu.options.lang \
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

