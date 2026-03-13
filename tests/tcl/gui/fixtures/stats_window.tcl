namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::stats_window {
    variable bindCalls {}
}

proc ::scid_test::gui_fixtures::stats_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    set ::scid_test::gui_fixtures::stats_window::bindCalls {}

    set ::language E

    array set ::tr {
        ScidUp ScidUp
        FilterStatistic FilterStatistic
        Year Year
        Rating Rating
    }

    namespace eval ::win {}
    namespace eval ::windows {}
    namespace eval ::windows::stats {}

    ::scid_test::mocks::stubCommand stubbedCommands tr {tag {lang ""}} {
        if {[info exists ::tr($tag)]} { return $::tr($tag) }
        return $tag
    }

    ::scid_test::mocks::stubCommand stubbedCommands winfo {subcmd args} {
        if {$subcmd ne "exists"} {
            error "winfo $subcmd not stubbed in tests"
        }
        set w [lindex $args 0]
        expr {[llength [info commands $w]] > 0}
    }

    ::scid_test::mocks::stubCommand stubbedCommands focus {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands destroy {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands win::createDialog {w} {
        if {![llength [info commands $w]]} {
            ::scid_test::widgets::defineWidget $w
        }
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands wm {subcmd args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::stats_window::bindCalls [list $w $seq $script]
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands setWinLocation {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands recordWinSize {args} { return }

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
    foreach cmd {frame button checkbutton} {
        ::scid_test::mocks::stubCommand stubbedCommands ::ttk::$cmd {path args} {
            if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
            if {[llength $args]} { $path configure {*}$args }
            return $path
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands pack {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands image {subcmd args} {
        if {$subcmd ne "create"} {
            error "image $subcmd not stubbed in tests"
        }
        return "scid_test_image"
    }
}

proc ::scid_test::gui_fixtures::stats_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::language

    set ::scid_test::gui_fixtures::stats_window::bindCalls {}
}

proc ::scid_test::gui_fixtures::stats_window::bindCalls {} {
    return $::scid_test::gui_fixtures::stats_window::bindCalls
}
