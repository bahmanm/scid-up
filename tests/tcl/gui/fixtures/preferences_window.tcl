namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::preferences_window {
    variable bindCalls {}
    variable focusCalls {}
    variable winCreateCalls {}
    variable initCalls {}

    variable treeviewState
    array set treeviewState {}

    variable treeviewInserted
    array set treeviewInserted {}

    variable treeviewSelection
    array set treeviewSelection {}

    variable canvasState
    array set canvasState {}

    variable canvasCreateCalls
    array set canvasCreateCalls {}
}

proc ::scid_test::gui_fixtures::preferences_window::resetState {} {
    set ::scid_test::gui_fixtures::preferences_window::bindCalls {}
    set ::scid_test::gui_fixtures::preferences_window::focusCalls {}
    set ::scid_test::gui_fixtures::preferences_window::winCreateCalls {}
    set ::scid_test::gui_fixtures::preferences_window::initCalls {}

    array unset ::scid_test::gui_fixtures::preferences_window::treeviewState
    array set ::scid_test::gui_fixtures::preferences_window::treeviewState {}
    array unset ::scid_test::gui_fixtures::preferences_window::treeviewInserted
    array set ::scid_test::gui_fixtures::preferences_window::treeviewInserted {}
    array unset ::scid_test::gui_fixtures::preferences_window::treeviewSelection
    array set ::scid_test::gui_fixtures::preferences_window::treeviewSelection {}
    array unset ::scid_test::gui_fixtures::preferences_window::canvasState
    array set ::scid_test::gui_fixtures::preferences_window::canvasState {}
    array unset ::scid_test::gui_fixtures::preferences_window::canvasCreateCalls
    array set ::scid_test::gui_fixtures::preferences_window::canvasCreateCalls {}
}

proc ::scid_test::gui_fixtures::preferences_window::defineTreeview {path} {
    catch {rename $path ""}
    interp alias {} $path {} ::scid_test::gui_fixtures::preferences_window::dispatchTreeview $path
    return $path
}

proc ::scid_test::gui_fixtures::preferences_window::dispatchTreeview {path subcmd args} {
    switch -- $subcmd {
        configure {
            if {[llength $args] % 2 != 0} {
                error "treeview $path configure expects option/value pairs, got: $args"
            }
            foreach {opt val} $args {
                set ::scid_test::gui_fixtures::preferences_window::treeviewState($path,$opt) $val
            }
            return
        }
        cget {
            set opt [lindex $args 0]
            if {![info exists ::scid_test::gui_fixtures::preferences_window::treeviewState($path,$opt)]} {
                error "treeview $path missing option $opt"
            }
            return $::scid_test::gui_fixtures::preferences_window::treeviewState($path,$opt)
        }
        insert {
            set parent [lindex $args 0]
            set index [lindex $args 1]
            set opts [lrange $args 2 end]

            set itemId ""
            set values {}
            for {set i 0} {$i < [llength $opts]} {incr i 2} {
                set opt [lindex $opts $i]
                set val [lindex $opts [expr {$i + 1}]]
                if {$opt eq "-id"} { set itemId $val }
                if {$opt eq "-values"} { set values $val }
            }
            if {$itemId eq ""} {
                error "treeview $path insert missing -id (parent=$parent index=$index opts=$opts)"
            }

            lappend ::scid_test::gui_fixtures::preferences_window::treeviewInserted($path) [list \
                -parent $parent \
                -index $index \
                -id $itemId \
                -values $values \
            ]
            return $itemId
        }
        column {
            set col [lindex $args 0]
            set opts [lrange $args 1 end]
            if {[llength $opts] % 2 != 0} {
                error "treeview $path column expects option/value pairs, got: $opts"
            }
            foreach {opt val} $opts {
                set ::scid_test::gui_fixtures::preferences_window::treeviewState($path,column,$col,$opt) $val
            }
            return
        }
        selection {
            if {![llength $args]} {
                if {![info exists ::scid_test::gui_fixtures::preferences_window::treeviewSelection($path)]} {
                    return ""
                }
                return $::scid_test::gui_fixtures::preferences_window::treeviewSelection($path)
            }

            set op [lindex $args 0]
            switch -- $op {
                set {
                    set ids [lrange $args 1 end]
                    set ::scid_test::gui_fixtures::preferences_window::treeviewSelection($path) $ids
                    return
                }
                default {
                    error "treeview $path selection $op not stubbed"
                }
            }
        }
        default {
            error "treeview $path subcommand $subcmd not stubbed"
        }
    }
}

proc ::scid_test::gui_fixtures::preferences_window::defineCanvas {path} {
    catch {rename $path ""}
    interp alias {} $path {} ::scid_test::gui_fixtures::preferences_window::dispatchCanvas $path
    return $path
}

proc ::scid_test::gui_fixtures::preferences_window::dispatchCanvas {path subcmd args} {
    switch -- $subcmd {
        configure {
            if {[llength $args] % 2 != 0} {
                error "canvas $path configure expects option/value pairs, got: $args"
            }
            foreach {opt val} $args {
                set ::scid_test::gui_fixtures::preferences_window::canvasState($path,$opt) $val
            }
            return
        }
        cget {
            set opt [lindex $args 0]
            if {![info exists ::scid_test::gui_fixtures::preferences_window::canvasState($path,$opt)]} {
                error "canvas $path missing option $opt"
            }
            return $::scid_test::gui_fixtures::preferences_window::canvasState($path,$opt)
        }
        create {
            set type [lindex $args 0]
            if {$type ne "window"} {
                return 0
            }
            lappend ::scid_test::gui_fixtures::preferences_window::canvasCreateCalls($path) $args
            return [llength $::scid_test::gui_fixtures::preferences_window::canvasCreateCalls($path)]
        }
        xview -
        yview {
            return
        }
        default {
            error "canvas $path subcommand $subcmd not stubbed"
        }
    }
}

proc ::scid_test::gui_fixtures::preferences_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    ::scid_test::gui_fixtures::preferences_window::resetState

    set ::language E
    array set ::menuLabel {E,ConfigureScid ConfigureScid}

    array set ::tr {
        OptionsBoard OptionsBoard
        OptionsFonts OptionsFonts
        OptionsToolbar OptionsToolbar
        OptionsInternationalization OptionsInternationalization
        OptionsRecent OptionsRecent
        OptionsSounds OptionsSounds
        OptionsMoves OptionsMoves
        ConfigureInformant ConfigureInformant
    }

    namespace eval ::win {}
    namespace eval ::preferences {}
    namespace eval ::recentFiles {}
    namespace eval ::utils {}
    namespace eval ::utils::sound {}

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
            reqwidth -
            reqheight {
                return 100
            }
            default {
                error "winfo $subcmd not stubbed in tests"
            }
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::preferences_window::bindCalls [list $w $seq $script]
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands focus {w} {
        lappend ::scid_test::gui_fixtures::preferences_window::focusCalls $w
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands grid {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands autoscrollBars {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands ::applyThemeColor_background {args} { return }

    ::scid_test::mocks::stubCommand stubbedCommands ::win::createWindow {w title} {
        lappend ::scid_test::gui_fixtures::preferences_window::winCreateCalls [list $w $title]
        if {[llength [info commands $w]]} {
            return 0
        }
        ::scid_test::widgets::defineWidget $w
        return 1
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::win::makeVisible {w} { return }

    if {![namespace exists ::ttk]} { namespace eval ::ttk {} }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::frame {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::treeview {path args} {
        ::scid_test::gui_fixtures::preferences_window::defineTreeview $path
        if {[llength $args]} {
            $path configure {*}$args
        }
        return $path
    }

    ::scid_test::mocks::stubCommand stubbedCommands canvas {path args} {
        ::scid_test::gui_fixtures::preferences_window::defineCanvas $path
        if {[llength $args]} {
            $path configure {*}$args
        }
        return $path
    }

    ::scid_test::mocks::stubCommand stubbedCommands font {subcmd args} {
        if {$subcmd eq "measure"} {
            set text [lindex $args 1]
            return [expr {[string length $text] * 8}]
        }

        if {$subcmd eq "create"} {
            set name "scid_test_font"
            if {[llength $args] > 0 && ![string match "-*" [lindex $args 0]]} {
                set name [lindex $args 0]
            }
            return $name
        }

        return "scid_test_font"
    }
}

proc ::scid_test::gui_fixtures::preferences_window::stubPaneInitialisers {registryVar} {
    upvar 1 $registryVar stubbedCommands

    set ::scid_test::gui_fixtures::preferences_window::initCalls {}

    foreach initProc {
        chooseBoardColors
        ::preferences::fonts
        ConfigToolbar
        ::preferences::internationalization
        ::recentFiles::configure
        ::utils::sound::OptionsDialog
        ::preferences::moves
        configInformant
    } {
        set body [string map [list @P@ $initProc] {
            lappend ::scid_test::gui_fixtures::preferences_window::initCalls [list @P@ $frame]
            return
        }]
        ::scid_test::mocks::stubCommand stubbedCommands $initProc {frame} $body
    }
}

proc ::scid_test::gui_fixtures::preferences_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::menuLabel
    unset -nocomplain ::language

    ::scid_test::gui_fixtures::preferences_window::resetState
}

proc ::scid_test::gui_fixtures::preferences_window::bindCalls {} {
    return $::scid_test::gui_fixtures::preferences_window::bindCalls
}

proc ::scid_test::gui_fixtures::preferences_window::focusCalls {} {
    return $::scid_test::gui_fixtures::preferences_window::focusCalls
}

proc ::scid_test::gui_fixtures::preferences_window::winCreateCalls {} {
    return $::scid_test::gui_fixtures::preferences_window::winCreateCalls
}

proc ::scid_test::gui_fixtures::preferences_window::initCalls {} {
    return $::scid_test::gui_fixtures::preferences_window::initCalls
}

proc ::scid_test::gui_fixtures::preferences_window::treeviewState {path key} {
    return $::scid_test::gui_fixtures::preferences_window::treeviewState($path,$key)
}

proc ::scid_test::gui_fixtures::preferences_window::treeviewInserted {path} {
    if {![info exists ::scid_test::gui_fixtures::preferences_window::treeviewInserted($path)]} {
        return {}
    }
    return $::scid_test::gui_fixtures::preferences_window::treeviewInserted($path)
}

proc ::scid_test::gui_fixtures::preferences_window::treeviewSelection {path} {
    if {![info exists ::scid_test::gui_fixtures::preferences_window::treeviewSelection($path)]} {
        return ""
    }
    return $::scid_test::gui_fixtures::preferences_window::treeviewSelection($path)
}

proc ::scid_test::gui_fixtures::preferences_window::treeviewColumnState {path col key} {
    return $::scid_test::gui_fixtures::preferences_window::treeviewState($path,column,$col,$key)
}

proc ::scid_test::gui_fixtures::preferences_window::canvasState {path key} {
    return $::scid_test::gui_fixtures::preferences_window::canvasState($path,$key)
}

proc ::scid_test::gui_fixtures::preferences_window::canvasCreateCalls {path} {
    if {![info exists ::scid_test::gui_fixtures::preferences_window::canvasCreateCalls($path)]} {
        return {}
    }
    return $::scid_test::gui_fixtures::preferences_window::canvasCreateCalls($path)
}
