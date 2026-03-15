namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::gamelist_window {
    variable bindCalls {}
    variable glistCreateCalls {}
    variable glistUpdateCalls {}
    variable titleCalls {}
    variable updateTreeFilterCalls {}
    variable cancelUpdateTreeFilterCalls {}
    variable notifyFilterCalls {}
    variable messageBoxCalls {}
    variable addSanMoveCalls {}
    variable gridCalls {}
    variable eventCalls {}
    variable searchBoardCalls {}
    variable searchHeaderCalls {}
    variable searchMaterialCalls {}
    variable filterResetCalls {}
    variable filterNegateCalls {}
}

proc ::scid_test::gui_fixtures::gamelist_window::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    ::scid_test::menu_capture::install stubbedCommands \
        -defaultTearoff 0 \
        -stubBind 0

    set ::scid_test::gui_fixtures::gamelist_window::bindCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistCreateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::titleCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::updateTreeFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::cancelUpdateTreeFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::notifyFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::messageBoxCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::addSanMoveCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::gridCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::eventCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchBoardCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchHeaderCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchMaterialCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterResetCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterNegateCalls {}

    set ::language E
    set ::clipbase_db 9

    array set ::tr {
        ChangeFilter ChangeFilter
        ShowHideStatistic ShowHideStatistic
        BoardFilter BoardFilter
        ToolsExpFilter ToolsExpFilter
        all all
        noGames noGames
    }

    array set ::helpMessage {
        E,SearchReset SearchReset
        E,SearchCurrent SearchCurrent
        E,SearchHeader SearchHeader
        E,SearchMaterial SearchMaterial
        E,WindowsTmt WindowsTmt
        E,ToolsCross ToolsCross
    }

    namespace eval ::windows {}
    namespace eval ::windows::gamelist {}
    namespace eval ::win {}
    namespace eval ::utils {}
    namespace eval ::utils::tooltip {}
    namespace eval ::file {}
    namespace eval ::tourney {}
    namespace eval ::crosstab {}
    namespace eval ::notify {}
    namespace eval ::search {}

    ::scid_test::mocks::stubCommand stubbedCommands tr {tag {lang ""}} {
        if {[info exists ::tr($tag)]} { return $::tr($tag) }
        return $tag
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::options.store {varName args} {
        if {![llength $args]} {
            return
        }
        if {![info exists $varName]} {
            set $varName [lindex $args 0]
        }
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands winfo {subcmd args} {
        switch -- $subcmd {
            exists {
                set w [lindex $args 0]
                return [expr {[llength [info commands $w]] > 0}]
            }
            rootx -
            rooty -
            height -
            reqheight {
                return 24
            }
            default {
                error "winfo $subcmd not stubbed in tests"
            }
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::win::createWindow {w title} {
        if {![llength [info commands $w]]} {
            ::scid_test::widgets::defineWidget $w
        }
        return 1
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::win::makeVisible {w} { return }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::gamelist_window::bindCalls [list $w $seq $script]
        return
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

    ::scid_test::mocks::stubCommand stubbedCommands ttk_canvas {path args} {
        if {![llength [info commands $path]]} {
            ::scid_test::widgets::defineCanvasWidget $path
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

    ::scid_test::mocks::stubCommand stubbedCommands grid {args} {
        lappend ::scid_test::gui_fixtures::gamelist_window::gridCalls $args
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands pack {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands update {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands tk_popup {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands event {subcmd args} {
        if {$subcmd ne "generate"} {
            error "event $subcmd not stubbed in tests"
        }
        lappend ::scid_test::gui_fixtures::gamelist_window::eventCalls [list $subcmd {*}$args]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands autoscrollBars {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands destroy {w} {
        catch {rename $w ""}
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands font {subcmd args} {
        switch -- $subcmd {
            metrics {
                set option [lindex $args 1]
                switch -- $option {
                    -linespace { return 10 }
                    -ascent { return 8 }
                    -descent { return 2 }
                    default { error "font metrics $option not stubbed in tests" }
                }
            }
            measure {
                set text [lindex $args 1]
                return [expr {[string length $text] * 6}]
            }
            default {
                error "font $subcmd not stubbed in tests"
            }
        }
    }
    ::scid_test::mocks::stubCommand stubbedCommands image {subcmd args} {
        if {$subcmd ne "create"} {
            error "image $subcmd not stubbed in tests"
        }
        set type [lindex $args 0]
        if {$type ni {"bitmap" "photo"}} {
            error "image create $type not stubbed in tests"
        }
        set name [lindex $args 1]
        if {$name eq "" || [string match "-*" $name]} {
            return "scid_test_image"
        }
        return $name
    }

    ::scid_test::mocks::stubCommand stubbedCommands ::utils::tooltip::Set {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands ::utils::thousands {value threshold} {
        return $value
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::setTitle {w title} {
        lappend ::scid_test::gui_fixtures::gamelist_window::titleCalls [list $w $title]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::file::BaseName {base} {
        return "base$base"
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::search::board {base filter} {
        lappend ::scid_test::gui_fixtures::gamelist_window::searchBoardCalls [list $base $filter]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::search::header {base filter} {
        lappend ::scid_test::gui_fixtures::gamelist_window::searchHeaderCalls [list $base $filter]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::search::material {base} {
        lappend ::scid_test::gui_fixtures::gamelist_window::searchMaterialCalls $base
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::updateTreeFilter {base} {
        lappend ::scid_test::gui_fixtures::gamelist_window::updateTreeFilterCalls $base
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::cancelUpdateTreeFilter {progressSpec} {
        lappend ::scid_test::gui_fixtures::gamelist_window::cancelUpdateTreeFilterCalls $progressSpec
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::notify::filter {base filter} {
        lappend ::scid_test::gui_fixtures::gamelist_window::notifyFilterCalls [list $base $filter]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands tk_messageBox {args} {
        lappend ::scid_test::gui_fixtures::gamelist_window::messageBoxCalls $args
        return ok
    }
    ::scid_test::mocks::stubCommand stubbedCommands addSanMove {moveSAN} {
        lappend ::scid_test::gui_fixtures::gamelist_window::addSanMoveCalls $moveSAN
        return 1
    }
    ::scid_test::mocks::stubCommand stubbedCommands ttk_create {widget subcmd args} {
        return [$widget create $subcmd {*}$args]
    }

    ::scid_test::mocks::stubCommand stubbedCommands sc_base {subcmd args} {
        switch -- $subcmd {
            current {
                return 1
            }
            list {
                return {1 2 3}
            }
            isReadOnly {
                return [expr {[lindex $args 0] == 3}]
            }
            inUse {
                return 1
            }
            numGames {
                return 10
            }
            filename {
                return "/tmp/base[lindex $args 0].si5"
            }
            default {
                error "sc_base $subcmd not stubbed in tests"
            }
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands sc_filter {subcmd args} {
        switch -- $subcmd {
            sizes {
                return {3 10 10}
            }
            reset {
                lappend ::scid_test::gui_fixtures::gamelist_window::filterResetCalls $args
                return
            }
            negate {
                lappend ::scid_test::gui_fixtures::gamelist_window::filterNegateCalls $args
                return
            }
            components {
                set filter [lindex $args 1]
                if {$filter eq ""} {
                    return {}
                }
                return [split $filter +]
            }
            new {
                return "newfilter"
            }
            compose {
                set filter [lindex $args 1]
                set extra [lindex $args 2]
                if {$extra eq ""} {
                    return [lindex [split $filter +] 0]
                }
                return "[lindex [split $filter +] 0]+$extra"
            }
            treestats {
                return [list \
                    [list e4 120 55 25 40 2300 2505 60 W] \
                    [list Nf6 40 10 15 15 2250 2100 8 B] \
                ]
            }
            default {
                error "sc_filter $subcmd not stubbed in tests"
            }
        }
    }
}

proc ::scid_test::gui_fixtures::gamelist_window::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset

    unset -nocomplain ::tr
    unset -nocomplain ::helpMessage
    unset -nocomplain ::language
    unset -nocomplain ::clipbase_db
    catch {array unset ::gamelistBase}
    catch {array unset ::gamelistFilter}
    catch {array unset ::gamelistPosMask}
    catch {array unset ::gamelistMenu}
    catch {array unset ::gamelistTitle}
    catch {array unset ::glistClickOp}
    catch {array unset ::glist_Sort}
    catch {array unset ::glist_ColOrder}
    catch {array unset ::glist_ColWidth}
    catch {array unset ::glist_ColAnchor}
    catch {array unset ::glist_FindBar}
    catch {unset ::glist_Layouts}

    set ::scid_test::gui_fixtures::gamelist_window::bindCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistCreateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::titleCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::updateTreeFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::cancelUpdateTreeFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::notifyFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::messageBoxCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::addSanMoveCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::gridCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::eventCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchBoardCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchHeaderCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchMaterialCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterResetCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterNegateCalls {}
}

proc ::scid_test::gui_fixtures::gamelist_window::installRuntimeStubs {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::stubCommand stubbedCommands glist.create {path layout} {
        lappend ::scid_test::gui_fixtures::gamelist_window::glistCreateCalls [list $path $layout]
        if {![llength [info commands $path.glist]]} {
            ::scid_test::widgets::defineTextWidget $path.glist
        }
        return $path.glist
    }
    ::scid_test::mocks::stubCommand stubbedCommands glist.update {path base filter moveUp} {
        lappend ::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls [list $path $base $filter $moveUp]
        return
    }
}

proc ::scid_test::gui_fixtures::gamelist_window::bindCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::bindCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::glistCreateCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::glistCreateCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::titleCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::titleCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::updateTreeFilterCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::updateTreeFilterCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::cancelUpdateTreeFilterCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::cancelUpdateTreeFilterCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::notifyFilterCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::notifyFilterCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::messageBoxCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::messageBoxCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::addSanMoveCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::addSanMoveCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::gridCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::gridCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::eventCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::eventCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::searchBoardCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::searchBoardCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::searchHeaderCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::searchHeaderCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::searchMaterialCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::searchMaterialCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::filterResetCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::filterResetCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::filterNegateCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::filterNegateCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::resetActionCalls {} {
    set ::scid_test::gui_fixtures::gamelist_window::gridCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::eventCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchBoardCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchHeaderCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchMaterialCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterResetCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterNegateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::notifyFilterCalls {}
}
