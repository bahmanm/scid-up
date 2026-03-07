namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::file_finder_window {}

proc ::scid_test::gui_fixtures::file_finder_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    ::scid_test::menu_capture::install stubbedCommands \
        -defaultTearoff 1 \
        -stubBind 0

    set ::windowsOS 0
    set ::language E

    array set ::tr {
        FileFinder FileFinder
        FinderSortType FinderSortType
        FinderTypesScid FinderTypesScid
        FinderTypesOld FinderTypesOld
        FinderTypesPGN FinderTypesPGN
        FinderTypesRep FinderTypesRep
        FinderTypesEPD FinderTypesEPD
        Stop Stop
        FinderFileSubdirs FinderFileSubdirs
        FinderDir FinderDir
    }

    array set ::menuLabel {
        E,FinderSortType FinderSortType
        E,FinderTypesScid FinderTypesScid
        E,FinderTypesOld FinderTypesOld
        E,FinderTypesPGN FinderTypesPGN
        E,FinderTypesRep FinderTypesRep
        E,FinderTypesEPD FinderTypesEPD
    }

    namespace eval ::file {}
    namespace eval ::file::finder {}
    namespace eval ::win {}
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

    ::scid_test::mocks::stubCommand stubbedCommands wm {subcmd args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands bind {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands pack {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands grid {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands update {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands busyCursor {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands unbusyCursor {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands setWinLocation {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands recordWinSize {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands ::utils::tooltip::Set {w msg} { return }

    if {![namespace exists ::ttk]} { namespace eval ::ttk {} }
    foreach cmd {frame labelframe checkbutton button label menubutton} {
        ::scid_test::mocks::stubCommand stubbedCommands ::ttk::$cmd {path args} {
            if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
            if {[llength $args]} { $path configure {*}$args }
            return $path
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::win::createDialog {w} {
        if {![llength [info commands $w]]} { ::scid_test::widgets::defineWidget $w }
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands tk_optionMenu {path varName args} {
        set menuPath "${path}.menu"
        if {![llength [info commands $menuPath]]} {
            menu $menuPath
        }
        return $menuPath
    }

    ::scid_test::mocks::stubCommand stubbedCommands autoscrollText {bars frame widget style} {
        if {![llength [info commands $frame]]} { ::scid_test::widgets::defineWidget $frame }
        if {![llength [info commands $widget]]} { ::scid_test::widgets::defineTextWidget $widget }
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands font {subcmd args} {
        if {$subcmd ne "measure"} {
            return "scid_test_font"
        }
        return 8
    }
}

proc ::scid_test::gui_fixtures::file_finder_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::menuLabel
    unset -nocomplain ::windowsOS
    unset -nocomplain ::language
}
