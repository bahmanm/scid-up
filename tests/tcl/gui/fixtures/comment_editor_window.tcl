namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::comment_editor_window {
    variable bindCalls {}
    variable afterCalls {}
    variable tooltipCalls {}
    variable winCreateCalls {}
}

proc ::scid_test::gui_fixtures::comment_editor_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    set ::scid_test::gui_fixtures::comment_editor_window::bindCalls {}
    set ::scid_test::gui_fixtures::comment_editor_window::afterCalls {}
    set ::scid_test::gui_fixtures::comment_editor_window::tooltipCalls {}
    set ::scid_test::gui_fixtures::comment_editor_window::winCreateCalls {}

    set ::language E
    array set ::tr {
        WindowsComment WindowsComment
        AnnotationSymbols AnnotationSymbols
        Comment Comment
        Clear Clear
    }

    namespace eval ::win {}
    namespace eval ::utils {}
    namespace eval ::utils::tooltip {}

    ::scid_test::mocks::stubCommand stubbedCommands tr {tag {lang ""}} {
        if {[info exists ::tr($tag)]} { return $::tr($tag) }
        return $tag
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::win::createWindow {w title args} {
        lappend ::scid_test::gui_fixtures::comment_editor_window::winCreateCalls [list $w $title {*}$args]
        if {[llength [info commands $w]]} {
            return 0
        }
        ::scid_test::widgets::defineWidget $w
        return 1
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::win::makeVisible {w} { return }
    ::scid_test::mocks::stubCommand stubbedCommands ::win::closeWindow {w} { return }

    ::scid_test::mocks::stubCommand stubbedCommands grid {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands bind {args} {
        lappend ::scid_test::gui_fixtures::comment_editor_window::bindCalls $args
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands after {args} {
        lappend ::scid_test::gui_fixtures::comment_editor_window::afterCalls $args
        return "after#scid_test"
    }

    ::scid_test::mocks::stubCommand stubbedCommands winfo {subcmd args} {
        switch -- $subcmd {
            exists {
                set w [lindex $args 0]
                expr {[llength [info commands $w]] > 0}
            }
            children {
                set w [lindex $args 0]
                set result {}
                foreach c [info commands "${w}.*"] {
                    set dotIdx [string last "." $c]
                    if {$dotIdx <= 0} {
                        continue
                    }
                    set parent [string range $c 0 [expr {$dotIdx - 1}]]
                    if {$parent eq $w} {
                        lappend result $c
                    }
                }
                return [lsort $result]
            }
            default {
                error "winfo $subcmd not stubbed in tests"
            }
        }
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

    ::scid_test::mocks::stubCommand stubbedCommands ::utils::tooltip::Set {w msg} {
        lappend ::scid_test::gui_fixtures::comment_editor_window::tooltipCalls [list $w $msg]
        return
    }

    if {![namespace exists ::ttk]} { namespace eval ::ttk {} }
    foreach cmd {frame label button} {
        ::scid_test::mocks::stubCommand stubbedCommands ::ttk::$cmd {path args} {
            if {![llength [info commands $path]]} {
                ::scid_test::widgets::defineWidget $path
            }
            if {[llength $args]} { $path configure {*}$args }
            return $path
        }
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::entry {path args} {
        if {![llength [info commands $path]]} {
            ::scid_test::widgets::defineEntryWidget $path
        }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }

    ::scid_test::mocks::stubCommand stubbedCommands sc_pos {subcmd args} {
        switch -- $subcmd {
            getComment { return "sample comment" }
            getNags { return "!!" }
            isAt { return 0 }
            default { error "sc_pos $subcmd not stubbed in tests" }
        }
    }
}

proc ::scid_test::gui_fixtures::comment_editor_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::language

    set ::scid_test::gui_fixtures::comment_editor_window::bindCalls {}
    set ::scid_test::gui_fixtures::comment_editor_window::afterCalls {}
    set ::scid_test::gui_fixtures::comment_editor_window::tooltipCalls {}
    set ::scid_test::gui_fixtures::comment_editor_window::winCreateCalls {}
}

proc ::scid_test::gui_fixtures::comment_editor_window::bindCalls {} {
    return $::scid_test::gui_fixtures::comment_editor_window::bindCalls
}

proc ::scid_test::gui_fixtures::comment_editor_window::afterCalls {} {
    return $::scid_test::gui_fixtures::comment_editor_window::afterCalls
}

proc ::scid_test::gui_fixtures::comment_editor_window::winCreateCalls {} {
    return $::scid_test::gui_fixtures::comment_editor_window::winCreateCalls
}
