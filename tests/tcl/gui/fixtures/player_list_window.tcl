namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::player_list_window {
    variable bindCalls {}
    variable focusCalls {}
}

proc ::scid_test::gui_fixtures::player_list_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    set ::scid_test::gui_fixtures::player_list_window::bindCalls {}
    set ::scid_test::gui_fixtures::player_list_window::focusCalls {}

    set ::language E

    array set ::tr {
        ScidUp ScidUp
        WindowsPList WindowsPList
        Player: Player:
        Defaults Defaults
        Search Search
        TmtLimit: TmtLimit:
    }

    namespace eval ::utils {}
    namespace eval ::utils::history {}
    namespace eval ::utils::validate {}

    ::scid_test::mocks::stubCommand stubbedCommands tr {tag {lang ""}} {
        if {[info exists ::tr($tag)]} { return $::tr($tag) }
        return $tag
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::utils::history::SetCombobox {varName widgetPath} {
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::utils::validate::Integer {max min name1 name2 op} {
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands winfo {subcmd args} {
        if {$subcmd ne "exists"} {
            error "winfo $subcmd not stubbed in tests"
        }
        set w [lindex $args 0]
        expr {[llength [info commands $w]] > 0}
    }

    ::scid_test::mocks::stubCommand stubbedCommands createToplevel {w} {
        if {![llength [info commands $w]]} {
            ::scid_test::widgets::defineWidget $w
        }
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands setTitle {w title} { return }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::player_list_window::bindCalls [list $w $seq $script]
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands focus {w} {
        lappend ::scid_test::gui_fixtures::player_list_window::focusCalls $w
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands autoscrollText {bars frame widget style} {
        if {![llength [info commands $frame]]} {
            ::scid_test::widgets::defineWidget $frame
        }
        if {![llength [info commands $widget]]} {
            ::scid_test::widgets::defineTextWidget $widget
        }
        return
    }

    if {![namespace exists ::ttk]} { namespace eval ::ttk {} }
    foreach cmd {frame label entry combobox} {
        ::scid_test::mocks::stubCommand stubbedCommands ::ttk::$cmd {path args} {
            if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
            if {[llength $args]} { $path configure {*}$args }
            return $path
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands dialogbutton {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }

    ::scid_test::mocks::stubCommand stubbedCommands pack {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands packbuttons {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands grid {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands font {subcmd args} {
        if {$subcmd eq "measure"} {
            return 8
        }
        return "scid_test_font"
    }
}

proc ::scid_test::gui_fixtures::player_list_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::language

    set ::scid_test::gui_fixtures::player_list_window::bindCalls {}
    set ::scid_test::gui_fixtures::player_list_window::focusCalls {}
}

proc ::scid_test::gui_fixtures::player_list_window::bindCalls {} {
    return $::scid_test::gui_fixtures::player_list_window::bindCalls
}

proc ::scid_test::gui_fixtures::player_list_window::focusCalls {} {
    return $::scid_test::gui_fixtures::player_list_window::focusCalls
}
