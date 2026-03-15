namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::game_browser_window {
    variable bindCalls {}
    variable mouseWheelBindings {}
    variable boardUpdateCalls {}
}

proc ::scid_test::gui_fixtures::game_browser_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    set ::scid_test::gui_fixtures::game_browser_window::bindCalls {}
    set ::scid_test::gui_fixtures::game_browser_window::mouseWheelBindings {}
    set ::scid_test::gui_fixtures::game_browser_window::boardUpdateCalls {}

    set ::language E
    set ::autoplayDelay 250

    array set ::tr {
        ScidUp ScidUp
        BrowseGame BrowseGame
        LoadGame LoadGame
        MergeGame MergeGame
        Close Close
    }

    namespace eval ::gbrowser {}
    namespace eval ::board {}
    namespace eval ::game {}

    ::scid_test::mocks::stubCommand stubbedCommands tr {tag {lang ""}} {
        if {[info exists ::tr($tag)]} { return $::tr($tag) }
        return $tag
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::trans {text} {
        return $text
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::options.store {varName default} {
        if {![info exists $varName]} {
            set $varName $default
        }
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands winfo {subcmd args} {
        if {$subcmd ne "exists"} {
            error "winfo $subcmd not stubbed in tests"
        }
        set w [lindex $args 0]
        expr {[llength [info commands $w]] > 0}
    }

    ::scid_test::mocks::stubCommand stubbedCommands toplevel {w args} {
        if {![llength [info commands $w]]} {
            ::scid_test::widgets::defineWidget $w
        }
        return $w
    }

    ::scid_test::mocks::stubCommand stubbedCommands wm {subcmd args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands applyThemeColor_background {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands event {subcmd args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands after {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::game_browser_window::bindCalls [list $w $seq $script]
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands bindMouseWheel {w script} {
        lappend ::scid_test::gui_fixtures::game_browser_window::mouseWheelBindings [list $w $script]
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

    ::scid_test::mocks::stubCommand stubbedCommands ::board::new {w size} {
        if {![llength [info commands $w]]} {
            ::scid_test::widgets::defineWidget $w
        }
        ::scid_test::widgets::setState $w -size $size
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::board::update {w board show} {
        lappend ::scid_test::gui_fixtures::game_browser_window::boardUpdateCalls [list $w $board $show]
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::board::isFlipped {w} {
        return 0
    }

    if {![namespace exists ::ttk]} { namespace eval ::ttk {} }
    foreach cmd {frame button} {
        ::scid_test::mocks::stubCommand stubbedCommands ::ttk::$cmd {path args} {
            if {![llength [info commands $path]]} {
                ::scid_test::widgets::defineWidget $path
            }
            if {[llength $args]} {
                $path configure {*}$args
            }
            return $path
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands pack {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands sc_base {subcmd args} {
        switch -- $subcmd {
            current {
                return 1
            }
            filename {
                return "/tmp/testbase.si5"
            }
            gamesummary {
                return [list "Header" {b0 b1 b2} {e4 e5 Nf3}]
            }
            switch {
                return
            }
            default {
                error "sc_base $subcmd not stubbed in tests"
            }
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands sc_game {subcmd args} {
        if {$subcmd eq "number"} {
            return 1
        }
        error "sc_game $subcmd not stubbed in tests"
    }
}

proc ::scid_test::gui_fixtures::game_browser_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::language
    unset -nocomplain ::autoplayDelay
    catch {array unset ::gbrowser::boards}
    catch {array unset ::gbrowser::autoplay}
    catch {array unset ::gbrowser::ply}

    set ::scid_test::gui_fixtures::game_browser_window::bindCalls {}
    set ::scid_test::gui_fixtures::game_browser_window::mouseWheelBindings {}
    set ::scid_test::gui_fixtures::game_browser_window::boardUpdateCalls {}
}

proc ::scid_test::gui_fixtures::game_browser_window::bindCalls {} {
    return $::scid_test::gui_fixtures::game_browser_window::bindCalls
}

proc ::scid_test::gui_fixtures::game_browser_window::mouseWheelBindings {} {
    return $::scid_test::gui_fixtures::game_browser_window::mouseWheelBindings
}

proc ::scid_test::gui_fixtures::game_browser_window::boardUpdateCalls {} {
    return $::scid_test::gui_fixtures::game_browser_window::boardUpdateCalls
}
