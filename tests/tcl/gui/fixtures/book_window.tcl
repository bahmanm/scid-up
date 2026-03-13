namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::book_window {
    variable bindCalls {}
    variable tempRoot ""
}

proc ::scid_test::gui_fixtures::book_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    set ::scid_test::gui_fixtures::book_window::bindCalls {}

    set ::language E

    array set ::tr {
        ScidUp ScidUp
        Book Book
        OtherBookMoves OtherBookMoves
        OtherBookMovesTooltip OtherBookMovesTooltip
        Close Close
    }

    namespace eval ::win {}
    namespace eval ::utils {}
    namespace eval ::utils::tooltip {}

    set ::scid_test::gui_fixtures::book_window::tempRoot [::scid_test::makeTempRoot "::scid_test::gui_fixtures::book_window"]
    set booksDir [file join $::scid_test::gui_fixtures::book_window::tempRoot books]
    file mkdir $booksDir

    foreach name {a.bin b.bin} {
        set path [file join $booksDir $name]
        set fd [open $path "w"]
        puts $fd "dummy"
        close $fd
    }

    set ::scidBooksDir $booksDir

    # Keep any "last book" selection logic deterministic.
    namespace eval ::book {}
    set ::book::lastBook ""

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

    ::scid_test::mocks::stubCommand stubbedCommands createToplevel {w} {
        if {![llength [info commands $w]]} {
            ::scid_test::widgets::defineWidget $w
        }
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands setTitle {w title} { return }
    ::scid_test::mocks::stubCommand stubbedCommands wm {subcmd args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::book_window::bindCalls [list $w $seq $script]
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
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::frame {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::combobox {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineComboboxWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::button {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }

    ::scid_test::mocks::stubCommand stubbedCommands pack {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands tk_messageBox {args} {
        error "tk_messageBox should not be called in the happy-path book window test"
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::win::closeWindow {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands ::utils::tooltip::Set {args} { return }
}

proc ::scid_test::gui_fixtures::book_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::language
    unset -nocomplain ::scidBooksDir

    catch {unset ::book::lastBook}

    ::scid_test::deleteTempRoot $::scid_test::gui_fixtures::book_window::tempRoot
    set ::scid_test::gui_fixtures::book_window::tempRoot ""

    set ::scid_test::gui_fixtures::book_window::bindCalls {}
}

proc ::scid_test::gui_fixtures::book_window::bindCalls {} {
    return $::scid_test::gui_fixtures::book_window::bindCalls
}

proc ::scid_test::gui_fixtures::book_window::tempRoot {} {
    return $::scid_test::gui_fixtures::book_window::tempRoot
}
