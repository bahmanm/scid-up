namespace eval ::scid_test {}
namespace eval ::scid_test::menu_capture {}

# Lightweight capture of Tk `menu` widgets for headless Tcl tests.
#
# This module provides a `menu` command stub that records menu entries and
# configuration so test suites can extract a deterministic structural model of
# menu trees without requiring Tk.
#
# Intended usage:
#   - In suite setup: `::scid_test::menu_capture::reset`
#   - In suite setup: `::scid_test::menu_capture::install stubbedCommands ...`
#   - Then `source` the Tcl module that builds menus (e.g. `src/tcl/menus.tcl`).
#
namespace eval ::scid_test::menu_capture {
    variable created {}
    variable defaultTearoff 1

    variable menuEntries
    variable menuOptions
    array set menuEntries {}
    array set menuOptions {}
}

# Resets all captured menu widgets and recorded state.
proc ::scid_test::menu_capture::reset {} {
    variable created
    variable menuEntries
    variable menuOptions

    foreach m $created {
        catch {rename $m ""}
    }

    set created {}
    array unset menuEntries
    array unset menuOptions
}

# Installs the `menu` stub (and optionally other small stubs) into the current
# interpreter via `::scid_test::mocks::stubCommand`.
#
# Parameters:
#   - registryVar: Suite-local stub registry variable name (passed through).
#
# Options:
#   - `-defaultTearoff 0|1`:
#       Default `-tearoff` value when the caller does not specify it.
#   - `-stubBind 0|1`:
#       When enabled, stubs `bind` as a no-op (useful when sourcing menu code
#       that registers bindings at file scope).
proc ::scid_test::menu_capture::install {registryVar args} {
    variable defaultTearoff

    array set opts {
        -defaultTearoff 1
        -stubBind 1
    }
    array set opts $args

    set defaultTearoff $opts(-defaultTearoff)

    ::scid_test::mocks::stubCommand $registryVar menu {path args} {
        return [::scid_test::menu_capture::createMenu $path {*}$args]
    }

    if {$opts(-stubBind)} {
        ::scid_test::mocks::stubCommand $registryVar bind {args} { return }
    }
}

# Creates (stubs) a menu widget command at `path`, recording all subsequent
# operations.
proc ::scid_test::menu_capture::createMenu {path args} {
    variable created
    variable defaultTearoff
    variable menuEntries
    variable menuOptions

    if {[llength [info commands $path]]} {
        return $path
    }

    set tearoff $defaultTearoff
    set idx [lsearch -exact $args -tearoff]
    if {$idx != -1 && ($idx + 1) < [llength $args]} {
        set tearoff [lindex $args [expr {$idx + 1}]]
    }

    interp alias {} $path {} ::scid_test::menu_capture::dispatchMenu $path
    lappend created $path

    set menuOptions($path,-tearoff) $tearoff
    if {$tearoff} {
        # Mimic Tk's implicit tearoff entry at index 0.
        lappend menuEntries($path) [dict create type tearoff -label "" -underline 0 -state normal -menu "" -command ""]
    } else {
        set menuEntries($path) {}
    }

    if {[llength $args]} {
        $path configure {*}$args
    }

    return $path
}

# Resolves a menu index in the same spirit as Tk’s `index` subcommand.
proc ::scid_test::menu_capture::menuIndex {menu index} {
    variable menuEntries

    set entries $menuEntries($menu)
    if {$index eq "end" || $index eq "last"} {
        set n [llength $entries]
        if {$n == 0} { return "none" }
        return [expr {$n - 1}]
    }

    if {[string is integer -strict $index]} {
        return $index
    }

    error "Unsupported menu index: $index"
}

# Resolves either an integer index or an entry label to an integer index.
proc ::scid_test::menu_capture::resolveEntryIndex {menu indexOrLabel} {
    variable menuEntries

    if {[string is integer -strict $indexOrLabel]} {
        return $indexOrLabel
    }

    if {$indexOrLabel eq "end" || $indexOrLabel eq "last"} {
        return [::scid_test::menu_capture::menuIndex $menu $indexOrLabel]
    }

    set idx 0
    foreach entry $menuEntries($menu) {
        if {[dict get $entry -label] eq $indexOrLabel} {
            return $idx
        }
        incr idx
    }

    error "Menu $menu has no entry labelled: $indexOrLabel"
}

# Dispatch for captured menu widget commands (e.g. `.menu.file add ...`).
proc ::scid_test::menu_capture::dispatchMenu {menu subcmd args} {
    variable menuEntries
    variable menuOptions

    switch -- $subcmd {
        configure {
            if {[llength $args] % 2 != 0} {
                error "menu $menu configure expects option/value pairs, got: $args"
            }
            foreach {opt val} $args {
                set menuOptions($menu,$opt) $val
            }
            return
        }
        cget {
            set opt [lindex $args 0]
            if {![info exists menuOptions($menu,$opt)]} {
                error "menu $menu missing option $opt"
            }
            return $menuOptions($menu,$opt)
        }
        add {
            set type [lindex $args 0]
            set opts [lrange $args 1 end]
            set entry [dict create type $type -label "" -underline 0 -state normal -menu "" -command ""]

            if {[llength $opts] % 2 != 0} {
                error "menu $menu add expects option/value pairs, got: $opts"
            }
            foreach {opt val} $opts {
                dict set entry $opt $val
            }

            lappend menuEntries($menu) $entry
            return
        }
        insert {
            set index [lindex $args 0]
            set type [lindex $args 1]
            set opts [lrange $args 2 end]

            set entry [dict create type $type -label "" -underline 0 -state normal -menu "" -command ""]
            if {[llength $opts] % 2 != 0} {
                error "menu $menu insert expects option/value pairs, got: $opts"
            }
            foreach {opt val} $opts {
                dict set entry $opt $val
            }

            if {$index eq "end"} {
                lappend menuEntries($menu) $entry
            } else {
                set idx [::scid_test::menu_capture::resolveEntryIndex $menu $index]
                set menuEntries($menu) [linsert $menuEntries($menu) $idx $entry]
            }
            return
        }
        delete {
            set first [lindex $args 0]
            set last [lindex $args 1]
            if {$last eq ""} {
                set last $first
            }

            set firstIdx [::scid_test::menu_capture::resolveEntryIndex $menu $first]
            if {$last eq "end"} {
                set lastIdx [expr {[llength $menuEntries($menu)] - 1}]
            } else {
                set lastIdx [::scid_test::menu_capture::resolveEntryIndex $menu $last]
            }

            set menuEntries($menu) [lreplace $menuEntries($menu) $firstIdx $lastIdx]
            return
        }
        index {
            set what [lindex $args 0]
            return [::scid_test::menu_capture::menuIndex $menu $what]
        }
        type {
            set idx [::scid_test::menu_capture::resolveEntryIndex $menu [lindex $args 0]]
            return [dict get [lindex $menuEntries($menu) $idx] type]
        }
        entrycget {
            set idx [::scid_test::menu_capture::resolveEntryIndex $menu [lindex $args 0]]
            set opt [lindex $args 1]
            return [dict get [lindex $menuEntries($menu) $idx] $opt]
        }
        entryconfig -
        entryconfigure {
            set idx [::scid_test::menu_capture::resolveEntryIndex $menu [lindex $args 0]]
            set opts [lrange $args 1 end]
            if {[llength $opts] % 2 != 0} {
                error "menu $menu entryconfig expects option/value pairs, got: $opts"
            }

            set entry [lindex $menuEntries($menu) $idx]
            foreach {opt val} $opts {
                dict set entry $opt $val
            }
            set menuEntries($menu) [lreplace $menuEntries($menu) $idx $idx $entry]
            return
        }
        default {
            error "menu $menu subcommand $subcmd not stubbed"
        }
    }
}

# Returns the recorded entries list for a captured menu widget.
proc ::scid_test::menu_capture::entries {menu} {
    variable menuEntries
    if {![info exists menuEntries($menu)]} {
        error "Menu $menu does not exist"
    }
    return $menuEntries($menu)
}
