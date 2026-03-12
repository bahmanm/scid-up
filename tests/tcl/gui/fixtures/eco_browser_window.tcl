namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::eco_browser_window {
    variable bindCalls {}
}

proc ::scid_test::gui_fixtures::eco_browser_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    set ::scid_test::gui_fixtures::eco_browser_window::bindCalls {}

    set ::language E
    set ::MB3 3

    array set ::tr {
        ScidUp ScidUp
        WindowsECO WindowsECO
        Help Help
        Close Close
        ReclassifyGames ReclassifyGames
    }

    namespace eval ::windows {}
    namespace eval ::windows::eco {}

    namespace eval ::utils {}
    namespace eval ::utils::pane {}
    namespace eval ::utils::graph {}
    namespace eval ::htext {}

    ::scid_test::mocks::stubCommand stubbedCommands tr {tag {lang ""}} {
        if {[info exists ::tr($tag)]} { return $::tr($tag) }
        return $tag
    }

    ::scid_test::mocks::stubCommand stubbedCommands winfo {subcmd args} {
        switch -- $subcmd {
            exists {
                set w [lindex $args 0]
                expr {[llength [info commands $w]] > 0}
            }
            width -
            height {
                # Used only inside bind scripts; provide a deterministic value.
                return 500
            }
            default {
                error "winfo $subcmd not stubbed in tests"
            }
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands createToplevel {w} {
        if {![llength [info commands $w]]} {
            ::scid_test::widgets::defineWidget $w
        }
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands createToplevelFinalize {w} { return }
    ::scid_test::mocks::stubCommand stubbedCommands setTitle {w title} { return }
    ::scid_test::mocks::stubCommand stubbedCommands wm {subcmd args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::eco_browser_window::bindCalls [list $w $seq $script]
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands focus {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands classifyAllGames {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands applyThemeColor_background {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands autoscrollText {bars frame widget style} {
        if {![llength [info commands $frame]]} {
            ::scid_test::widgets::defineWidget $frame
        }
        if {![llength [info commands $widget]]} {
            ::scid_test::widgets::defineTextWidget $widget
        }
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands canvas {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::htext::init {widgetPath} { return }

    ::scid_test::mocks::stubCommand stubbedCommands ::utils::pane::Create {panePath leftName rightName width height ratio} {
        if {![llength [info commands $panePath]]} { ::scid_test::widgets::defineWidget $panePath }
        set leftPath "${panePath}.${leftName}"
        set rightPath "${panePath}.${rightName}"
        if {![llength [info commands $leftPath]]} { ::scid_test::widgets::defineWidget $leftPath }
        if {![llength [info commands $rightPath]]} { ::scid_test::widgets::defineWidget $rightPath }
        return $panePath
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::utils::pane::SetRange {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands ::utils::pane::SetDrag {args} { return }

    foreach cmd {create configure redraw} {
        ::scid_test::mocks::stubCommand stubbedCommands ::utils::graph::$cmd {args} { return }
    }

    if {![namespace exists ::ttk]} { namespace eval ::ttk {} }
    foreach cmd {entry frame button} {
        ::scid_test::mocks::stubCommand stubbedCommands ::ttk::$cmd {path args} {
            if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
            if {[llength $args]} { $path configure {*}$args }
            return $path
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::style {subcmd args} {
        if {$subcmd ne "lookup"} {
            error "ttk::style $subcmd not stubbed in tests"
        }
        return "scid_test_foreground"
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

proc ::scid_test::gui_fixtures::eco_browser_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::language
    unset -nocomplain ::MB3

    set ::scid_test::gui_fixtures::eco_browser_window::bindCalls {}
}

proc ::scid_test::gui_fixtures::eco_browser_window::bindCalls {} {
    return $::scid_test::gui_fixtures::eco_browser_window::bindCalls
}
