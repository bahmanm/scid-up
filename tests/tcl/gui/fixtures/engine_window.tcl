namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::engine_window {
    variable bindCalls {}
}

proc ::scid_test::gui_fixtures::engine_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    set ::scid_test::gui_fixtures::engine_window::bindCalls {}

    set ::language E

    array set ::tr {
        StartEngine StartEngine
    }

    namespace eval ::win {}
    namespace eval ::enginewin {}
    namespace eval ::enginecfg {}
    namespace eval ::engine {}
    namespace eval ::notify {}
    namespace eval ::utils {}
    namespace eval ::utils::tooltip {}

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

    ::scid_test::mocks::stubCommand stubbedCommands ::win::createWindow {w title args} {
        if {[llength [info commands $w]]} { return 0 }
        ::scid_test::widgets::defineWidget $w
        return 1
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::win::makeVisible {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands ::utils::tooltip::Set {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands ::options.store {varName default} {
        if {![info exists $varName]} {
            set $varName $default
        }
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::engine_window::bindCalls [list $w $seq $script]
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands autoscrollBars {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands grid {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands ttk_text {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineTextWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }

    if {![namespace exists ::ttk]} { namespace eval ::ttk {} }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::frame {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::panedwindow {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::definePanedwindowWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }

    # Stubs used by enginewin::Open. Keep behaviour minimal and deterministic.
    ::scid_test::mocks::stubCommand stubbedCommands ::enginecfg::createConfigButtons {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands font {subcmd args} {
        if {$subcmd eq "measure"} {
            return 8
        }
        return "scid_test_font"
    }
}

proc ::scid_test::gui_fixtures::engine_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::language

    set ::scid_test::gui_fixtures::engine_window::bindCalls {}
}

proc ::scid_test::gui_fixtures::engine_window::bindCalls {} {
    return $::scid_test::gui_fixtures::engine_window::bindCalls
}
