namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::gamelist_window {
    variable bindCalls {}
    variable afterCalls {}
    variable currentBase 1
    variable winCreateWindowCalls {}
    variable winCreateWindowResult 1
    variable winCloseWindowCalls {}
    variable winMakeVisibleCalls {}
    variable glistCreateCalls {}
    variable glistUpdateCalls {}
    variable setBaseCalls {}
    variable titleCalls {}
    variable updateStatsCalls {}
    variable updateTreeFilterCalls {}
    variable cancelUpdateTreeFilterCalls {}
    variable notifyFilterCalls {}
    variable saveFileCalls {}
    variable saveFileResponse ""
    variable progressCalls {}
    variable closeProgressCalls 0
    variable filterExportCalls {}
    variable exportError ""
    variable exportErrorCode ""
    variable errorMessageBoxCalls {}
    variable messageBoxCalls {}
    variable messageBoxResponse ok
    variable addSanMoveCalls {}
    variable gridCalls {}
    variable eventCalls {}
    variable searchBoardCalls {}
    variable searchFilterCalls {}
    variable searchHeaderCalls {}
    variable searchMaterialCalls {}
    variable filterResetCalls {}
    variable filterNegateCalls {}
    variable filterCountDefault 5
    variable filterNewCalls {}
    variable copyGamesCalls {}
    variable copyGamesError ""
    variable databaseModifiedCalls {}
    variable gameChangedCalls 0
    variable clipbaseClearCalls 0
    array set baseInUse {}
    array set baseNumGames {}
    array set filterCounts {}
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
    set ::scid_test::gui_fixtures::gamelist_window::afterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::currentBase 1
    set ::scid_test::gui_fixtures::gamelist_window::winCreateWindowCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::winCreateWindowResult 1
    set ::scid_test::gui_fixtures::gamelist_window::winCloseWindowCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::winMakeVisibleCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistCreateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::setBaseCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::titleCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::updateStatsCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::updateTreeFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::cancelUpdateTreeFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::notifyFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::saveFileCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::saveFileResponse ""
    set ::scid_test::gui_fixtures::gamelist_window::progressCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::closeProgressCalls 0
    set ::scid_test::gui_fixtures::gamelist_window::filterExportCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::exportError ""
    set ::scid_test::gui_fixtures::gamelist_window::exportErrorCode ""
    set ::scid_test::gui_fixtures::gamelist_window::errorMessageBoxCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::messageBoxCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::messageBoxResponse ok
    set ::scid_test::gui_fixtures::gamelist_window::addSanMoveCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::gridCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::eventCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchBoardCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchHeaderCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchMaterialCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterResetCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterNegateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterCountDefault 5
    set ::scid_test::gui_fixtures::gamelist_window::filterNewCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::copyGamesCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::copyGamesError ""
    set ::scid_test::gui_fixtures::gamelist_window::databaseModifiedCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::gameChangedCalls 0
    set ::scid_test::gui_fixtures::gamelist_window::clipbaseClearCalls 0
    array unset ::scid_test::gui_fixtures::gamelist_window::baseInUse
    array unset ::scid_test::gui_fixtures::gamelist_window::baseNumGames
    array unset ::scid_test::gui_fixtures::gamelist_window::filterCounts

    set ::language E
    set ::clipbase_db 9

    array set ::tr {
        ChangeFilter ChangeFilter
        ShowHideStatistic ShowHideStatistic
        BoardFilter BoardFilter
        ToolsExpFilter ToolsExpFilter
        HeaderSearch HeaderSearch
        TreeBestGames TreeBestGames
        ScidUp ScidUp
        Cancel Cancel
        CopyErr CopyErr
        CopyErrSource CopyErrSource
        CopyErrNoGames CopyErrNoGames
        CopyErrTarget CopyErrTarget
        CopyErrReadOnly CopyErrReadOnly
        CopyGames CopyGames
        CopyConfirm CopyConfirm
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
    namespace eval ::ERROR {}

    set ::initialDir(base) /tmp/scid-base
    set ::gamelistExport PGN
    set ::exportStartFile(LaTeX) latex-start
    set ::exportEndFile(LaTeX) latex-end
    set ::ERROR::UserCancel SCID_TEST_USER_CANCEL

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
        lappend ::scid_test::gui_fixtures::gamelist_window::winCreateWindowCalls [list $w $title]
        if {$::scid_test::gui_fixtures::gamelist_window::winCreateWindowResult && ![llength [info commands $w]]} {
            ::scid_test::widgets::defineWidget $w
        }
        return $::scid_test::gui_fixtures::gamelist_window::winCreateWindowResult
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::win::closeWindow {w} {
        lappend ::scid_test::gui_fixtures::gamelist_window::winCloseWindowCalls $w
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::win::makeVisible {w} {
        lappend ::scid_test::gui_fixtures::gamelist_window::winMakeVisibleCalls $w
        return
    }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::gamelist_window::bindCalls [list $w $seq $script]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands after {args} {
        lappend ::scid_test::gui_fixtures::gamelist_window::afterCalls $args
        return after#0
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
    ::scid_test::mocks::stubCommand stubbedCommands tk_getSaveFile {args} {
        lappend ::scid_test::gui_fixtures::gamelist_window::saveFileCalls $args
        return $::scid_test::gui_fixtures::gamelist_window::saveFileResponse
    }
    ::scid_test::mocks::stubCommand stubbedCommands progressWindow {title message cancelLabel} {
        lappend ::scid_test::gui_fixtures::gamelist_window::progressCalls [list $title $message $cancelLabel]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands closeProgressWindow {} {
        incr ::scid_test::gui_fixtures::gamelist_window::closeProgressCalls
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ERROR::MessageBox {args} {
        lappend ::scid_test::gui_fixtures::gamelist_window::errorMessageBoxCalls $args
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
    ::scid_test::mocks::stubCommand stubbedCommands ::notify::DatabaseModified {base} {
        lappend ::scid_test::gui_fixtures::gamelist_window::databaseModifiedCalls $base
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::notify::GameChanged {} {
        incr ::scid_test::gui_fixtures::gamelist_window::gameChangedCalls
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands tk_messageBox {args} {
        lappend ::scid_test::gui_fixtures::gamelist_window::messageBoxCalls $args
        return $::scid_test::gui_fixtures::gamelist_window::messageBoxResponse
    }
    ::scid_test::mocks::stubCommand stubbedCommands sc_clipbase {subcmd args} {
        if {$subcmd ne "clear"} {
            error "sc_clipbase $subcmd not stubbed in tests"
        }
        incr ::scid_test::gui_fixtures::gamelist_window::clipbaseClearCalls
        return
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
                return $::scid_test::gui_fixtures::gamelist_window::currentBase
            }
            list {
                return {1 2 3}
            }
            isReadOnly {
                return [expr {[lindex $args 0] == 3}]
            }
            inUse {
                set base [lindex $args 0]
                if {[info exists ::scid_test::gui_fixtures::gamelist_window::baseInUse($base)]} {
                    return $::scid_test::gui_fixtures::gamelist_window::baseInUse($base)
                }
                return 1
            }
            numGames {
                set base [lindex $args 0]
                if {[info exists ::scid_test::gui_fixtures::gamelist_window::baseNumGames($base)]} {
                    return $::scid_test::gui_fixtures::gamelist_window::baseNumGames($base)
                }
                return 10
            }
            filename {
                return "/tmp/base[lindex $args 0].si5"
            }
            copygames {
                lappend ::scid_test::gui_fixtures::gamelist_window::copyGamesCalls $args
                if {$::scid_test::gui_fixtures::gamelist_window::copyGamesError ne ""} {
                    error $::scid_test::gui_fixtures::gamelist_window::copyGamesError
                }
                return
            }
            default {
                error "sc_base $subcmd not stubbed in tests"
            }
        }
    }

    ::scid_test::mocks::stubCommand stubbedCommands sc_filter {subcmd args} {
        switch -- $subcmd {
            export {
                lappend ::scid_test::gui_fixtures::gamelist_window::filterExportCalls $args
                if {$::scid_test::gui_fixtures::gamelist_window::exportError ne ""} {
                    set ::errorCode $::scid_test::gui_fixtures::gamelist_window::exportErrorCode
                    error $::scid_test::gui_fixtures::gamelist_window::exportError
                }
                return
            }
            search {
                lappend ::scid_test::gui_fixtures::gamelist_window::searchFilterCalls $args
                return
            }
            count {
                lassign $args base filter
                if {[info exists ::scid_test::gui_fixtures::gamelist_window::filterCounts($base,$filter)]} {
                    return $::scid_test::gui_fixtures::gamelist_window::filterCounts($base,$filter)
                }
                return $::scid_test::gui_fixtures::gamelist_window::filterCountDefault
            }
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
                lappend ::scid_test::gui_fixtures::gamelist_window::filterNewCalls $args
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
    catch {array unset ::initialDir}
    unset -nocomplain ::gamelistExport
    catch {array unset ::exportStartFile}
    catch {array unset ::exportEndFile}
    catch {unset ::errorCode}
    catch {namespace delete ::ERROR}
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
    set ::scid_test::gui_fixtures::gamelist_window::afterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::currentBase 1
    set ::scid_test::gui_fixtures::gamelist_window::winCreateWindowCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::winCreateWindowResult 1
    set ::scid_test::gui_fixtures::gamelist_window::winCloseWindowCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::winMakeVisibleCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistCreateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::setBaseCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::titleCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::updateStatsCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::updateTreeFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::cancelUpdateTreeFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::notifyFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::saveFileCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::saveFileResponse ""
    set ::scid_test::gui_fixtures::gamelist_window::progressCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::closeProgressCalls 0
    set ::scid_test::gui_fixtures::gamelist_window::filterExportCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::exportError ""
    set ::scid_test::gui_fixtures::gamelist_window::exportErrorCode ""
    set ::scid_test::gui_fixtures::gamelist_window::errorMessageBoxCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::messageBoxCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::messageBoxResponse ok
    set ::scid_test::gui_fixtures::gamelist_window::addSanMoveCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::gridCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::eventCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchBoardCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchHeaderCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchMaterialCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterResetCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterNegateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterCountDefault 5
    set ::scid_test::gui_fixtures::gamelist_window::filterNewCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::copyGamesCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::copyGamesError ""
    set ::scid_test::gui_fixtures::gamelist_window::databaseModifiedCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::gameChangedCalls 0
    set ::scid_test::gui_fixtures::gamelist_window::clipbaseClearCalls 0
    array unset ::scid_test::gui_fixtures::gamelist_window::baseInUse
    array unset ::scid_test::gui_fixtures::gamelist_window::baseNumGames
    array unset ::scid_test::gui_fixtures::gamelist_window::filterCounts
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

proc ::scid_test::gui_fixtures::gamelist_window::installRefreshRuntimeStubs {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::stubCommand stubbedCommands ::windows::gamelist::updateStats_ {w} {
        lappend ::scid_test::gui_fixtures::gamelist_window::updateStatsCalls $w
        return
    }
}

proc ::scid_test::gui_fixtures::gamelist_window::installRefreshDispatchStubs {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::stubCommand stubbedCommands ::windows::gamelist::SetBase {w base {filter "dbfilter"}} {
        lappend ::scid_test::gui_fixtures::gamelist_window::setBaseCalls [list $w $base $filter]
        return
    }
}

proc ::scid_test::gui_fixtures::gamelist_window::bindCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::bindCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::afterCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::afterCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::winCreateWindowCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::winCreateWindowCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::winCloseWindowCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::winCloseWindowCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::winMakeVisibleCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::winMakeVisibleCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::glistCreateCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::glistCreateCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::setBaseCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::setBaseCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::titleCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::titleCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::updateStatsCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::updateStatsCalls
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

proc ::scid_test::gui_fixtures::gamelist_window::saveFileCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::saveFileCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::progressCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::progressCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::closeProgressCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::closeProgressCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::filterExportCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::filterExportCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::errorMessageBoxCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::errorMessageBoxCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::messageBoxCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::messageBoxCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::copyGamesCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::copyGamesCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::databaseModifiedCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::databaseModifiedCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::gameChangedCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::gameChangedCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::clipbaseClearCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::clipbaseClearCalls
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

proc ::scid_test::gui_fixtures::gamelist_window::searchFilterCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::searchFilterCalls
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

proc ::scid_test::gui_fixtures::gamelist_window::filterNewCalls {} {
    return $::scid_test::gui_fixtures::gamelist_window::filterNewCalls
}

proc ::scid_test::gui_fixtures::gamelist_window::resetActionCalls {} {
    set ::scid_test::gui_fixtures::gamelist_window::afterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::gridCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::eventCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchBoardCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchHeaderCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchMaterialCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterResetCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterNegateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::notifyFilterCalls {}
}

proc ::scid_test::gui_fixtures::gamelist_window::resetRefreshCalls {} {
    set ::scid_test::gui_fixtures::gamelist_window::afterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::setBaseCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::titleCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::updateStatsCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::updateTreeFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::cancelUpdateTreeFilterCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::notifyFilterCalls {}
}

proc ::scid_test::gui_fixtures::gamelist_window::resetExportCalls {} {
    set ::scid_test::gui_fixtures::gamelist_window::saveFileCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::progressCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::closeProgressCalls 0
    set ::scid_test::gui_fixtures::gamelist_window::filterExportCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::exportError ""
    set ::scid_test::gui_fixtures::gamelist_window::exportErrorCode ""
    set ::scid_test::gui_fixtures::gamelist_window::errorMessageBoxCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::searchFilterCalls {}
    catch {unset ::errorCode}
}

proc ::scid_test::gui_fixtures::gamelist_window::resetCopyCalls {} {
    set ::scid_test::gui_fixtures::gamelist_window::progressCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::closeProgressCalls 0
    set ::scid_test::gui_fixtures::gamelist_window::messageBoxCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::messageBoxResponse ok
    set ::scid_test::gui_fixtures::gamelist_window::copyGamesCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::copyGamesError ""
    set ::scid_test::gui_fixtures::gamelist_window::databaseModifiedCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::errorMessageBoxCalls {}
    catch {unset ::errorCode}
}

proc ::scid_test::gui_fixtures::gamelist_window::resetClearClipbaseCalls {} {
    set ::scid_test::gui_fixtures::gamelist_window::setBaseCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::databaseModifiedCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::gameChangedCalls 0
    set ::scid_test::gui_fixtures::gamelist_window::clipbaseClearCalls 0
}

proc ::scid_test::gui_fixtures::gamelist_window::resetOpenTreeBestCalls {} {
    set ::scid_test::gui_fixtures::gamelist_window::winCreateWindowCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::winCloseWindowCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::gridCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistCreateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::titleCalls {}
}

proc ::scid_test::gui_fixtures::gamelist_window::resetOpenCalls {} {
    set ::scid_test::gui_fixtures::gamelist_window::winCreateWindowCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::winCloseWindowCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::winMakeVisibleCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistCreateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::glistUpdateCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::setBaseCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::titleCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::gridCalls {}
    set ::scid_test::gui_fixtures::gamelist_window::filterNewCalls {}
}

proc ::scid_test::gui_fixtures::gamelist_window::setCurrentBase {base} {
    set ::scid_test::gui_fixtures::gamelist_window::currentBase $base
}

proc ::scid_test::gui_fixtures::gamelist_window::setWinCreateWindowResult {result} {
    set ::scid_test::gui_fixtures::gamelist_window::winCreateWindowResult $result
}

proc ::scid_test::gui_fixtures::gamelist_window::setBaseInUse {base inUse} {
    set ::scid_test::gui_fixtures::gamelist_window::baseInUse($base) $inUse
}

proc ::scid_test::gui_fixtures::gamelist_window::setBaseNumGames {base numGames} {
    set ::scid_test::gui_fixtures::gamelist_window::baseNumGames($base) $numGames
}

proc ::scid_test::gui_fixtures::gamelist_window::setSaveFileResponse {path} {
    set ::scid_test::gui_fixtures::gamelist_window::saveFileResponse $path
}

proc ::scid_test::gui_fixtures::gamelist_window::setMessageBoxResponse {response} {
    set ::scid_test::gui_fixtures::gamelist_window::messageBoxResponse $response
}

proc ::scid_test::gui_fixtures::gamelist_window::setFilterCount {base filter count} {
    set ::scid_test::gui_fixtures::gamelist_window::filterCounts($base,$filter) $count
}

proc ::scid_test::gui_fixtures::gamelist_window::setCopyGamesError {{message ""}} {
    set ::scid_test::gui_fixtures::gamelist_window::copyGamesError $message
}

proc ::scid_test::gui_fixtures::gamelist_window::setExportError {{message ""} {errorCode ""}} {
    set ::scid_test::gui_fixtures::gamelist_window::exportError $message
    set ::scid_test::gui_fixtures::gamelist_window::exportErrorCode $errorCode
}
