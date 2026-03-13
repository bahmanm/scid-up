namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::tree_window {
    variable bindCalls {}
    variable refreshCalls {}
}

proc ::scid_test::gui_fixtures::tree_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    ::scid_test::menu_capture::install stubbedCommands \
        -defaultTearoff 1 \
        -stubBind 0

    set ::scid_test::gui_fixtures::tree_window::bindCalls {}
    set ::scid_test::gui_fixtures::tree_window::refreshCalls {}

    set ::language E

    array set ::tr {
        ScidUp ScidUp
        WindowsTree WindowsTree
        allGames allGames
        Training Training
        Stop Stop
        Close Close
    }

    namespace eval ::tree {}
    namespace eval ::tree::mask {}

    set ::tree::mask::recentMask {mask-one mask-two}

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

    ::scid_test::mocks::stubCommand stubbedCommands ::createToplevel {w} {
        if {![llength [info commands $w]]} {
            ::scid_test::widgets::defineWidget $w
        }
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::createToplevelFinalize {w} { return }
    ::scid_test::mocks::stubCommand stubbedCommands ::setTitle {w title} { return }
    ::scid_test::mocks::stubCommand stubbedCommands ::setMenu {w menuPath} { return }
    ::scid_test::mocks::stubCommand stubbedCommands translateMenuLabels {menuPath} { return }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::tree_window::bindCalls [list $w $seq $script]
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

    ::scid_test::mocks::stubCommand stubbedCommands selection {subcmd args} {
        if {$subcmd ne "handle"} {
            error "selection $subcmd not stubbed in tests"
        }
        return
    }

    if {![namespace exists ::ttk]} { namespace eval ::ttk {} }
    foreach cmd {frame label button checkbutton} {
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

    ::scid_test::mocks::stubCommand stubbedCommands dialogbutton {path args} {
        if {![llength [info commands $path]]} {
            ::scid_test::widgets::defineWidget $path
        }
        if {[llength $args]} {
            $path configure {*}$args
        }
        return $path
    }

    ::scid_test::mocks::stubCommand stubbedCommands canvas {path args} {
        if {![llength [info commands $path]]} {
            ::scid_test::widgets::defineCanvasWidget $path
        }
        if {[llength $args]} {
            $path configure {*}$args
        }
        return $path
    }

    ::scid_test::mocks::stubCommand stubbedCommands pack {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands packbuttons {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands grid {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands wm {subcmd args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands sc_base {subcmd args} {
        if {$subcmd eq "current"} {
            return 1
        }
        error "sc_base $subcmd not stubbed in tests"
    }

    ::scid_test::mocks::stubCommand stubbedCommands sc_tree {subcmd args} {
        if {$subcmd eq "cacheinfo"} {
            return 1000
        }
        error "sc_tree $subcmd not stubbed in tests"
    }
}

proc ::scid_test::gui_fixtures::tree_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::language
    catch {unset ::tree::mask::recentMask}

    set ::scid_test::gui_fixtures::tree_window::bindCalls {}
    set ::scid_test::gui_fixtures::tree_window::refreshCalls {}
}

proc ::scid_test::gui_fixtures::tree_window::bindCalls {} {
    return $::scid_test::gui_fixtures::tree_window::bindCalls
}
