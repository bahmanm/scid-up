namespace eval ::scid_test {}
namespace eval ::scid_test::gui_fixtures {}
namespace eval ::scid_test::gui_fixtures::glist_widget {
    variable bindCalls {}
    variable mouseWheelBindings {}
    variable focusCalls {}
    variable sortInitCalls {}
    variable sortClickCalls {}
    variable sortcacheCalls {}
    variable findCalls {}
    variable searchHeaderCalls {}
    variable updateDelegateCalls {}
    variable awesomeCalls {}
    variable busyCalls {}
    variable updateCalls {}
    variable afterCalls {}
    variable ybarCalls {}
    variable gameslistCalls {}
    variable gamelocationCalls {}
    variable filterRemoveCalls {}
    variable notifyFilterCalls {}
    variable scrollProxyCalls {}
    variable switchBaseCalls {}
    variable loadCalls {}
    variable delflagCalls {}
    variable currentBase 1
    variable currentGameNumber 1
    variable baseFilenameByBase
    array set baseFilenameByBase {}
    variable gamelocationResponseByKey
    array set gamelocationResponseByKey {}
    variable gameslistResponseByKey
    array set gameslistResponseByKey {}
    variable filterSizesByKey
    array set filterSizesByKey {}
    variable filterComponentsByKey
    array set filterComponentsByKey {}

    variable treeviewState
    array set treeviewState {}

    variable treeviewHeading
    array set treeviewHeading {}

    variable treeviewColumn
    array set treeviewColumn {}

    variable treeviewTagConfigure
    array set treeviewTagConfigure {}

    variable treeviewItems
    array set treeviewItems {}

    variable treeviewItemData
    array set treeviewItemData {}

    variable treeviewDeleteCalls
    array set treeviewDeleteCalls {}

    variable treeviewBBox
    array set treeviewBBox {}

    variable treeviewIdentifyRegion
    array set treeviewIdentifyRegion {}

    variable treeviewIdentifyItem
    array set treeviewIdentifyItem {}

    variable treeviewIdentifyColumn
    array set treeviewIdentifyColumn {}
}

proc ::scid_test::gui_fixtures::glist_widget::resetState {} {
    set ::scid_test::gui_fixtures::glist_widget::bindCalls {}
    set ::scid_test::gui_fixtures::glist_widget::mouseWheelBindings {}
    set ::scid_test::gui_fixtures::glist_widget::focusCalls {}
    set ::scid_test::gui_fixtures::glist_widget::sortInitCalls {}
    set ::scid_test::gui_fixtures::glist_widget::sortClickCalls {}
    set ::scid_test::gui_fixtures::glist_widget::sortcacheCalls {}
    set ::scid_test::gui_fixtures::glist_widget::findCalls {}
    set ::scid_test::gui_fixtures::glist_widget::searchHeaderCalls {}
    set ::scid_test::gui_fixtures::glist_widget::updateDelegateCalls {}
    set ::scid_test::gui_fixtures::glist_widget::awesomeCalls {}
    set ::scid_test::gui_fixtures::glist_widget::busyCalls {}
    set ::scid_test::gui_fixtures::glist_widget::updateCalls {}
    set ::scid_test::gui_fixtures::glist_widget::afterCalls {}
    set ::scid_test::gui_fixtures::glist_widget::ybarCalls {}
    set ::scid_test::gui_fixtures::glist_widget::gameslistCalls {}
    set ::scid_test::gui_fixtures::glist_widget::gamelocationCalls {}
    set ::scid_test::gui_fixtures::glist_widget::filterRemoveCalls {}
    set ::scid_test::gui_fixtures::glist_widget::notifyFilterCalls {}
    set ::scid_test::gui_fixtures::glist_widget::scrollProxyCalls {}
    set ::scid_test::gui_fixtures::glist_widget::switchBaseCalls {}
    set ::scid_test::gui_fixtures::glist_widget::loadCalls {}
    set ::scid_test::gui_fixtures::glist_widget::delflagCalls {}
    set ::scid_test::gui_fixtures::glist_widget::currentBase 1
    set ::scid_test::gui_fixtures::glist_widget::currentGameNumber 1
    array unset ::scid_test::gui_fixtures::glist_widget::baseFilenameByBase
    array set ::scid_test::gui_fixtures::glist_widget::baseFilenameByBase {}
    array unset ::scid_test::gui_fixtures::glist_widget::gamelocationResponseByKey
    array set ::scid_test::gui_fixtures::glist_widget::gamelocationResponseByKey {}
    array unset ::scid_test::gui_fixtures::glist_widget::gameslistResponseByKey
    array set ::scid_test::gui_fixtures::glist_widget::gameslistResponseByKey {}
    array unset ::scid_test::gui_fixtures::glist_widget::filterSizesByKey
    array set ::scid_test::gui_fixtures::glist_widget::filterSizesByKey {}
    array unset ::scid_test::gui_fixtures::glist_widget::filterComponentsByKey
    array set ::scid_test::gui_fixtures::glist_widget::filterComponentsByKey {}

    array unset ::scid_test::gui_fixtures::glist_widget::treeviewState
    array set ::scid_test::gui_fixtures::glist_widget::treeviewState {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewHeading
    array set ::scid_test::gui_fixtures::glist_widget::treeviewHeading {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewColumn
    array set ::scid_test::gui_fixtures::glist_widget::treeviewColumn {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewTagConfigure
    array set ::scid_test::gui_fixtures::glist_widget::treeviewTagConfigure {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewItems
    array set ::scid_test::gui_fixtures::glist_widget::treeviewItems {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewItemData
    array set ::scid_test::gui_fixtures::glist_widget::treeviewItemData {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewDeleteCalls
    array set ::scid_test::gui_fixtures::glist_widget::treeviewDeleteCalls {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewBBox
    array set ::scid_test::gui_fixtures::glist_widget::treeviewBBox {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyRegion
    array set ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyRegion {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyItem
    array set ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyItem {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyColumn
    array set ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyColumn {}
}

proc ::scid_test::gui_fixtures::glist_widget::defineTreeview {path} {
    catch {rename $path ""}
    interp alias {} $path {} ::scid_test::gui_fixtures::glist_widget::dispatchTreeview $path
    return $path
}

proc ::scid_test::gui_fixtures::glist_widget::dispatchTreeview {path subcmd args} {
    switch -- $subcmd {
        configure {
            if {[llength $args] % 2 != 0} {
                error "treeview $path configure expects option/value pairs, got: $args"
            }
            foreach {opt val} $args {
                set ::scid_test::gui_fixtures::glist_widget::treeviewState($path,$opt) $val
            }
            return
        }
        cget {
            set opt [lindex $args 0]
            if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewState($path,$opt)]} {
                error "treeview $path missing option $opt"
            }
            return $::scid_test::gui_fixtures::glist_widget::treeviewState($path,$opt)
        }
        heading {
            set col [lindex $args 0]
            set opts [lrange $args 1 end]
            foreach {opt val} $opts {
                set ::scid_test::gui_fixtures::glist_widget::treeviewHeading($path,$col,$opt) $val
            }
            return
        }
        column {
            set col [lindex $args 0]
            set opts [lrange $args 1 end]
            if {[llength $opts] == 1} {
                set opt [lindex $opts 0]
                set actualCol $col
                if {[string match "#*" $col]} {
                    set displayIdx [expr {[string range $col 1 end] - 1}]
                    set displayCols {}
                    if {[info exists ::scid_test::gui_fixtures::glist_widget::treeviewState($path,-displaycolumns)]} {
                        set displayCols $::scid_test::gui_fixtures::glist_widget::treeviewState($path,-displaycolumns)
                    }
                    if {$opt eq "-id"} {
                        if {$displayIdx >= 0 && $displayIdx < [llength $displayCols]} {
                            return [lindex $::glist_Headers [lindex $displayCols $displayIdx]]
                        }
                        return ""
                    }
                    if {$displayIdx >= 0 && $displayIdx < [llength $displayCols]} {
                        set actualCol [lindex $::glist_Headers [lindex $displayCols $displayIdx]]
                    }
                }
                if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewColumn($path,$actualCol,$opt)]} {
                    return ""
                }
                return $::scid_test::gui_fixtures::glist_widget::treeviewColumn($path,$actualCol,$opt)
            }
            foreach {opt val} $opts {
                set ::scid_test::gui_fixtures::glist_widget::treeviewColumn($path,$col,$opt) $val
            }
            return
        }
        tag {
            set tagSubcmd [lindex $args 0]
            if {$tagSubcmd ne "configure"} {
                error "treeview $path tag $tagSubcmd not stubbed"
            }
            set tagName [lindex $args 1]
            lappend ::scid_test::gui_fixtures::glist_widget::treeviewTagConfigure($path) [list $tagName {*}[lrange $args 2 end]]
            return
        }
        selection {
            if {![llength $args]} {
                if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewState($path,selection)]} {
                    return ""
                }
                return $::scid_test::gui_fixtures::glist_widget::treeviewState($path,selection)
            }
            set op [lindex $args 0]
            if {$op eq "set"} {
                set ::scid_test::gui_fixtures::glist_widget::treeviewState($path,selection) [lindex $args 1]
                return
            }
            error "treeview $path selection $op not stubbed"
        }
        children {
            if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewItems($path)]} {
                return {}
            }
            return $::scid_test::gui_fixtures::glist_widget::treeviewItems($path)
        }
        delete {
            lappend ::scid_test::gui_fixtures::glist_widget::treeviewDeleteCalls($path) [list {*}$args]
            if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewItems($path)]} {
                return
            }
            if {[llength $args] == 1} {
                set itemIds [lindex $args 0]
            } else {
                set itemIds $args
            }
            foreach itemId $itemIds {
                set idx [lsearch -exact $::scid_test::gui_fixtures::glist_widget::treeviewItems($path) $itemId]
                if {$idx >= 0} {
                    set ::scid_test::gui_fixtures::glist_widget::treeviewItems($path) \
                        [lreplace $::scid_test::gui_fixtures::glist_widget::treeviewItems($path) $idx $idx]
                }
                array unset ::scid_test::gui_fixtures::glist_widget::treeviewItemData "$path,$itemId,*"
            }
            return
        }
        insert {
            set opts [dict create]
            foreach {opt val} [lrange $args 2 end] {
                dict set opts $opt $val
            }
            if {![dict exists $opts -id]} {
                error "treeview $path insert requires -id"
            }
            set itemId [dict get $opts -id]
            if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewItems($path)]} {
                set ::scid_test::gui_fixtures::glist_widget::treeviewItems($path) {}
            }
            lappend ::scid_test::gui_fixtures::glist_widget::treeviewItems($path) $itemId
            foreach opt {-values -tag} {
                if {[dict exists $opts $opt]} {
                    set ::scid_test::gui_fixtures::glist_widget::treeviewItemData($path,$itemId,$opt) [dict get $opts $opt]
                }
            }
            return $itemId
        }
        item {
            set itemId [lindex $args 0]
            set opts [lrange $args 1 end]
            if {[llength $opts] == 1} {
                set opt [lindex $opts 0]
                if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewItemData($path,$itemId,$opt)]} {
                    return ""
                }
                return $::scid_test::gui_fixtures::glist_widget::treeviewItemData($path,$itemId,$opt)
            }
            foreach {opt val} $opts {
                set ::scid_test::gui_fixtures::glist_widget::treeviewItemData($path,$itemId,$opt) $val
            }
            return
        }
        prev -
        next {
            set itemId [lindex $args 0]
            if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewItems($path)]} {
                return ""
            }
            set idx [lsearch -exact $::scid_test::gui_fixtures::glist_widget::treeviewItems($path) $itemId]
            if {$idx < 0} {
                return ""
            }
            set delta [expr {$subcmd eq "prev" ? -1 : 1}]
            incr idx $delta
            if {$idx < 0 || $idx >= [llength $::scid_test::gui_fixtures::glist_widget::treeviewItems($path)]} {
                return ""
            }
            return [lindex $::scid_test::gui_fixtures::glist_widget::treeviewItems($path) $idx]
        }
        bbox {
            set itemId [lindex $args 0]
            if {[info exists ::scid_test::gui_fixtures::glist_widget::treeviewBBox($path,$itemId)]} {
                return $::scid_test::gui_fixtures::glist_widget::treeviewBBox($path,$itemId)
            }
            if {[lsearch -exact [::scid_test::gui_fixtures::glist_widget::dispatchTreeview $path children {}] $itemId] >= 0} {
                return {0 0 10 1}
            }
            return ""
        }
        yview {
            if {![llength $args]} {
                if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewState($path,yview)]} {
                    return {0.0 1.0}
                }
                return $::scid_test::gui_fixtures::glist_widget::treeviewState($path,yview)
            }
            lappend ::scid_test::gui_fixtures::glist_widget::treeviewState($path,yview.calls) [list {*}$args]
            if {[lindex $args 0] eq "moveto"} {
                set first [lindex $args 1]
                set ::scid_test::gui_fixtures::glist_widget::treeviewState($path,yview) [list $first 1.0]
            }
            return
        }
        identify {
            set identifySubcmd [lindex $args 0]
            set x [lindex $args 1]
            set y [lindex $args 2]
            switch -- $identifySubcmd {
                region {
                    set key [join [list $path $x $y] \u001f]
                    if {[info exists ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyRegion($key)]} {
                        return $::scid_test::gui_fixtures::glist_widget::treeviewIdentifyRegion($key)
                    }
                    return cell
                }
                item {
                    set key [join [list $path $x $y] \u001f]
                    if {[info exists ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyItem($key)]} {
                        return $::scid_test::gui_fixtures::glist_widget::treeviewIdentifyItem($key)
                    }
                    if {[info exists ::scid_test::gui_fixtures::glist_widget::treeviewState($path,selection)]} {
                        return $::scid_test::gui_fixtures::glist_widget::treeviewState($path,selection)
                    }
                    return ""
                }
                column {
                    set key [join [list $path $x $y] \u001f]
                    if {[info exists ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyColumn($key)]} {
                        return $::scid_test::gui_fixtures::glist_widget::treeviewIdentifyColumn($key)
                    }
                    return "#1"
                }
                default {
                    error "treeview $path identify $identifySubcmd not stubbed"
                }
            }
        }
        default {
            error "treeview $path subcommand $subcmd not stubbed"
        }
    }
}

proc ::scid_test::gui_fixtures::glist_widget::setup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset
    ::scid_test::menu_capture::install stubbedCommands -defaultTearoff 0 -stubBind 0
    ::scid_test::gui_fixtures::glist_widget::resetState

    set ::language E
    set ::macOS 0
    set ::windowsOS 0
    set ::COMMAND Command

    array set ::tr {
        Search Search
        SearchHeader SearchHeader
        SearchReset SearchReset
        all all
        noGames noGames
    }

    array set ::helpMessage {
        E,SearchHeader SearchHeader
        E,SearchReset SearchReset
    }

    namespace eval ::utils {}
    namespace eval ::utils::tooltip {}
    namespace eval ::icon {}
    namespace eval ::search {}
    namespace eval ::windows {}
    namespace eval ::windows::gamelist {}

    foreach {iconName token} {
        filter_adv filter_adv
        filter_reset filter_reset
        filter_go filter_go
        arrow_down16 arrow_down16
        arrow_up16 arrow_up16
    } {
        set ::icon::$iconName $token
    }

    ::scid_test::mocks::stubCommand stubbedCommands tr {tag {lang ""}} {
        if {[info exists ::tr($tag)]} { return $::tr($tag) }
        return $tag
    }
    ::scid_test::mocks::stubCommand stubbedCommands winfo {subcmd args} {
        if {$subcmd ne "exists"} {
            error "winfo $subcmd not stubbed in tests"
        }
        set w [lindex $args 0]
        return [expr {[llength [info commands $w]] > 0}]
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::utils::thousands {value threshold} {
        return $value
    }

    ::scid_test::mocks::stubCommand stubbedCommands image {subcmd args} {
        if {$subcmd ne "create"} {
            error "image $subcmd not stubbed in tests"
        }
        set name [lindex $args 1]
        if {$name eq "" || [string match "-*" $name]} {
            return "scid_test_image"
        }
        return $name
    }

    ::scid_test::mocks::stubCommand stubbedCommands bind {w seq script} {
        lappend ::scid_test::gui_fixtures::glist_widget::bindCalls [list $w $seq $script]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands bindMouseWheel {w script} {
        lappend ::scid_test::gui_fixtures::glist_widget::mouseWheelBindings [list $w $script]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands focus {w} {
        lappend ::scid_test::gui_fixtures::glist_widget::focusCalls $w
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands event {subcmd args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands after {args} {
        lappend ::scid_test::gui_fixtures::glist_widget::afterCalls $args
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands scroll_proxy {first last} {
        lappend ::scid_test::gui_fixtures::glist_widget::scrollProxyCalls [list $first $last]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands grid {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands update {args} {
        lappend ::scid_test::gui_fixtures::glist_widget::updateCalls [list {*}$args]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands autoscrollBars {orientation parent widget args} {
        if {![llength [info commands $parent.ybar]]} {
            ::scid_test::widgets::defineWidget $parent.ybar
        }
        $widget configure -yscrollcommand scroll_proxy
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::utils::tooltip::Set {args} { return }
    ::scid_test::mocks::stubCommand stubbedCommands busyCursor {w} {
        lappend ::scid_test::gui_fixtures::glist_widget::busyCalls [list busyCursor $w]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands unbusyCursor {w} {
        lappend ::scid_test::gui_fixtures::glist_widget::busyCalls [list unbusyCursor $w]
        return
    }
    if {![namespace exists ::notify]} { namespace eval ::notify {} }
    ::scid_test::mocks::stubCommand stubbedCommands ::notify::filter {base filter} {
        lappend ::scid_test::gui_fixtures::glist_widget::notifyFilterCalls [list $base $filter]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands sc_base {subcmd args} {
        switch -- $subcmd {
            current {
                return $::scid_test::gui_fixtures::glist_widget::currentBase
            }
            gamelocation {
                lappend ::scid_test::gui_fixtures::glist_widget::gamelocationCalls [list {*}$args]
                set key [join $args \u001f]
                if {[info exists ::scid_test::gui_fixtures::glist_widget::gamelocationResponseByKey($key)]} {
                    return $::scid_test::gui_fixtures::glist_widget::gamelocationResponseByKey($key)
                }
                return none
            }
            gameslist {
                lappend ::scid_test::gui_fixtures::glist_widget::gameslistCalls [list {*}$args]
                set key [join $args \u001f]
                if {[info exists ::scid_test::gui_fixtures::glist_widget::gameslistResponseByKey($key)]} {
                    return $::scid_test::gui_fixtures::glist_widget::gameslistResponseByKey($key)
                }
                return {}
            }
            filename {
                set base [lindex $args 0]
                if {[info exists ::scid_test::gui_fixtures::glist_widget::baseFilenameByBase($base)]} {
                    return $::scid_test::gui_fixtures::glist_widget::baseFilenameByBase($base)
                }
                return "base$base.si4"
            }
            sortcache {
                lappend ::scid_test::gui_fixtures::glist_widget::sortcacheCalls [list {*}$args]
                return
            }
            default {
                error "sc_base $subcmd not stubbed in tests"
            }
        }
    }
    ::scid_test::mocks::stubCommand stubbedCommands sc_game {subcmd args} {
        if {$subcmd ne "number"} {
            error "sc_game $subcmd not stubbed in tests"
        }
        return $::scid_test::gui_fixtures::glist_widget::currentGameNumber
    }
    ::scid_test::mocks::stubCommand stubbedCommands sc_filter {subcmd args} {
        switch -- $subcmd {
            sizes {
                set key [join $args \u001f]
                if {[info exists ::scid_test::gui_fixtures::glist_widget::filterSizesByKey($key)]} {
                    return $::scid_test::gui_fixtures::glist_widget::filterSizesByKey($key)
                }
                return {0 0 0}
            }
            remove {
                lappend ::scid_test::gui_fixtures::glist_widget::filterRemoveCalls [list {*}$args]
                return
            }
            components {
                set key [join $args \u001f]
                if {[info exists ::scid_test::gui_fixtures::glist_widget::filterComponentsByKey($key)]} {
                    return $::scid_test::gui_fixtures::glist_widget::filterComponentsByKey($key)
                }
                return [list [lindex $args 1]]
            }
            default {
                error "sc_filter $subcmd not stubbed in tests"
            }
        }
    }

    if {![namespace exists ::ttk]} { namespace eval ::ttk {} }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::treeview {path args} {
        ::scid_test::gui_fixtures::glist_widget::defineTreeview $path
        if {[llength $args]} {
            $path configure {*}$args
        }
        return $path
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::frame {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::label {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::button {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::entry {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineEntryWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::ttk::scale {path args} {
        if {![llength [info commands $path]]} { ::scid_test::widgets::defineWidget $path }
        if {[llength $args]} { $path configure {*}$args }
        return $path
    }
}

proc ::scid_test::gui_fixtures::glist_widget::installRuntimeStubs {registryVar {stubFindgame 1} {stubUpdatePublic 0} {stubYbar 1} {stubDoubleclickDeps 1} {stubSortClick 1} {stubSortInit 1}} {
    upvar 1 $registryVar stubbedCommands

    if {$stubSortInit} {
        ::scid_test::mocks::stubCommand stubbedCommands glist.sortInit_ {w layout} {
            lappend ::scid_test::gui_fixtures::glist_widget::sortInitCalls [list $w $layout]
            return
        }
    }
    if {$stubSortClick} {
        ::scid_test::mocks::stubCommand stubbedCommands glist.sortClickEvent_ {w x y event_state layout} {
            lappend ::scid_test::gui_fixtures::glist_widget::sortClickCalls [list $w $x $y $event_state $layout]
            return
        }
    }
    if {$stubFindgame} {
        ::scid_test::mocks::stubCommand stubbedCommands glist.findgame_ {w_parent dir} {
            lappend ::scid_test::gui_fixtures::glist_widget::findCalls [list $w_parent $dir]
            return
        }
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::search::header {base filter} {
        lappend ::scid_test::gui_fixtures::glist_widget::searchHeaderCalls [list $base $filter]
        return
    }
    ::scid_test::mocks::stubCommand stubbedCommands ::windows::gamelist::Awesome {w txt} {
        lappend ::scid_test::gui_fixtures::glist_widget::awesomeCalls [list $w $txt]
        return
    }
    if {$stubYbar} {
        ::scid_test::mocks::stubCommand stubbedCommands glist.ybar_ {w args} {
            lappend ::scid_test::gui_fixtures::glist_widget::ybarCalls [list $w {*}$args]
            return
        }
    }
    if {$stubUpdatePublic} {
        ::scid_test::mocks::stubCommand stubbedCommands glist.update_ {w base} {
            lappend ::scid_test::gui_fixtures::glist_widget::updateDelegateCalls [list $w $base]
            return
        }
    }
    if {$stubDoubleclickDeps} {
        if {![namespace exists ::file]} { namespace eval ::file {} }
        if {![namespace exists ::game]} { namespace eval ::game {} }
        ::scid_test::mocks::stubCommand stubbedCommands ::file::SwitchToBase {base slot} {
            lappend ::scid_test::gui_fixtures::glist_widget::switchBaseCalls [list $base $slot]
            return
        }
        ::scid_test::mocks::stubCommand stubbedCommands ::game::Load {idx {ply ""}} {
            lappend ::scid_test::gui_fixtures::glist_widget::loadCalls [list $idx $ply]
            return
        }
        ::scid_test::mocks::stubCommand stubbedCommands glist.delflag_ {w idx} {
            lappend ::scid_test::gui_fixtures::glist_widget::delflagCalls [list $w $idx]
            return
        }
    }
}

proc ::scid_test::gui_fixtures::glist_widget::cleanup {registryVar} {
    upvar 1 $registryVar stubbedCommands

    ::scid_test::mocks::restoreStubs stubbedCommands
    ::scid_test::widgets::reset
    ::scid_test::menu_capture::reset
    ::scid_test::gui_fixtures::glist_widget::resetState

    unset -nocomplain ::tr
    unset -nocomplain ::helpMessage
    unset -nocomplain ::language
    unset -nocomplain ::macOS
    unset -nocomplain ::windowsOS
    unset -nocomplain ::COMMAND
    catch {unset ::glist_Layouts}
    catch {array unset ::glist_ColOrder}
    catch {array unset ::glist_ColWidth}
    catch {array unset ::glist_ColAnchor}
    catch {array unset ::glist_Sort}
    catch {array unset ::glist_FindBar}
    catch {array unset ::glistBase}
    catch {array unset ::glistFilter}
    catch {array unset ::glistFirst}
    catch {array unset ::glistSortStr}
    catch {array unset ::glistYScroll}
    catch {array unset ::glistFindBar}
    catch {array unset ::glistLoaded}
    catch {array unset ::glistTotal}
    catch {array unset ::glistVisibleLn}
    catch {array unset ::glistSortCache}
    catch {array unset ::glistClickOp}
    catch {array unset ::gamelistBase}
    catch {array unset ::gamelistFilter}
}

proc ::scid_test::gui_fixtures::glist_widget::bindCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::bindCalls
}

proc ::scid_test::gui_fixtures::glist_widget::mouseWheelBindings {} {
    return $::scid_test::gui_fixtures::glist_widget::mouseWheelBindings
}

proc ::scid_test::gui_fixtures::glist_widget::focusCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::focusCalls
}

proc ::scid_test::gui_fixtures::glist_widget::sortInitCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::sortInitCalls
}

proc ::scid_test::gui_fixtures::glist_widget::sortClickCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::sortClickCalls
}

proc ::scid_test::gui_fixtures::glist_widget::sortcacheCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::sortcacheCalls
}

proc ::scid_test::gui_fixtures::glist_widget::findCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::findCalls
}

proc ::scid_test::gui_fixtures::glist_widget::searchHeaderCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::searchHeaderCalls
}

proc ::scid_test::gui_fixtures::glist_widget::updateDelegateCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::updateDelegateCalls
}

proc ::scid_test::gui_fixtures::glist_widget::awesomeCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::awesomeCalls
}

proc ::scid_test::gui_fixtures::glist_widget::busyCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::busyCalls
}

proc ::scid_test::gui_fixtures::glist_widget::updateCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::updateCalls
}

proc ::scid_test::gui_fixtures::glist_widget::afterCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::afterCalls
}

proc ::scid_test::gui_fixtures::glist_widget::ybarCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::ybarCalls
}

proc ::scid_test::gui_fixtures::glist_widget::gameslistCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::gameslistCalls
}

proc ::scid_test::gui_fixtures::glist_widget::gamelocationCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::gamelocationCalls
}

proc ::scid_test::gui_fixtures::glist_widget::filterRemoveCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::filterRemoveCalls
}

proc ::scid_test::gui_fixtures::glist_widget::notifyFilterCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::notifyFilterCalls
}

proc ::scid_test::gui_fixtures::glist_widget::scrollProxyCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::scrollProxyCalls
}

proc ::scid_test::gui_fixtures::glist_widget::switchBaseCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::switchBaseCalls
}

proc ::scid_test::gui_fixtures::glist_widget::loadCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::loadCalls
}

proc ::scid_test::gui_fixtures::glist_widget::delflagCalls {} {
    return $::scid_test::gui_fixtures::glist_widget::delflagCalls
}

proc ::scid_test::gui_fixtures::glist_widget::setGamelocationResponse {args} {
    if {[llength $args] < 2} {
        error "setGamelocationResponse expects at least one lookup arg plus a result"
    }
    set result [lindex $args end]
    set key [join [lrange $args 0 end-1] \u001f]
    set ::scid_test::gui_fixtures::glist_widget::gamelocationResponseByKey($key) $result
}

proc ::scid_test::gui_fixtures::glist_widget::setTreeviewSelection {path value} {
    set ::scid_test::gui_fixtures::glist_widget::treeviewState($path,selection) $value
}

proc ::scid_test::gui_fixtures::glist_widget::setTreeviewYview {path value} {
    set ::scid_test::gui_fixtures::glist_widget::treeviewState($path,yview) $value
}

proc ::scid_test::gui_fixtures::glist_widget::setTreeviewRows {path rows} {
    set ::scid_test::gui_fixtures::glist_widget::treeviewItems($path) {}
    array unset ::scid_test::gui_fixtures::glist_widget::treeviewItemData "$path,*,*"
    foreach row $rows {
        lassign $row itemId values tag
        lappend ::scid_test::gui_fixtures::glist_widget::treeviewItems($path) $itemId
        set ::scid_test::gui_fixtures::glist_widget::treeviewItemData($path,$itemId,-values) $values
        set ::scid_test::gui_fixtures::glist_widget::treeviewItemData($path,$itemId,-tag) $tag
    }
}

proc ::scid_test::gui_fixtures::glist_widget::setTreeviewBBox {path itemId value} {
    set ::scid_test::gui_fixtures::glist_widget::treeviewBBox($path,$itemId) $value
}

proc ::scid_test::gui_fixtures::glist_widget::setTreeviewIdentifyRegion {path x y value} {
    set key [join [list $path $x $y] \u001f]
    set ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyRegion($key) $value
}

proc ::scid_test::gui_fixtures::glist_widget::setTreeviewIdentifyItem {path x y value} {
    set key [join [list $path $x $y] \u001f]
    set ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyItem($key) $value
}

proc ::scid_test::gui_fixtures::glist_widget::setTreeviewIdentifyColumn {path x y value} {
    set key [join [list $path $x $y] \u001f]
    set ::scid_test::gui_fixtures::glist_widget::treeviewIdentifyColumn($key) $value
}

proc ::scid_test::gui_fixtures::glist_widget::setFilterSizes {base filter sizes} {
    set key [join [list $base $filter] \u001f]
    set ::scid_test::gui_fixtures::glist_widget::filterSizesByKey($key) $sizes
}

proc ::scid_test::gui_fixtures::glist_widget::setFilterComponents {base filter components} {
    set key [join [list $base $filter] \u001f]
    set ::scid_test::gui_fixtures::glist_widget::filterComponentsByKey($key) $components
}

proc ::scid_test::gui_fixtures::glist_widget::setGameslistResponse {args} {
    if {[llength $args] < 2} {
        error "setGameslistResponse expects at least one lookup arg plus a result"
    }
    set result [lindex $args end]
    set key [join [lrange $args 0 end-1] \u001f]
    set ::scid_test::gui_fixtures::glist_widget::gameslistResponseByKey($key) $result
}

proc ::scid_test::gui_fixtures::glist_widget::setCurrentBase {value} {
    set ::scid_test::gui_fixtures::glist_widget::currentBase $value
}

proc ::scid_test::gui_fixtures::glist_widget::setCurrentGameNumber {value} {
    set ::scid_test::gui_fixtures::glist_widget::currentGameNumber $value
}

proc ::scid_test::gui_fixtures::glist_widget::setBaseFilename {base value} {
    set ::scid_test::gui_fixtures::glist_widget::baseFilenameByBase($base) $value
}

proc ::scid_test::gui_fixtures::glist_widget::treeviewState {path key} {
    return $::scid_test::gui_fixtures::glist_widget::treeviewState($path,$key)
}

proc ::scid_test::gui_fixtures::glist_widget::treeviewHeadingCalls {path} {
    set out {}
    foreach key [array names ::scid_test::gui_fixtures::glist_widget::treeviewHeading "$path,*,*"] {
        lassign [split $key ,] widget col opt
        dict set out $col $opt $::scid_test::gui_fixtures::glist_widget::treeviewHeading($key)
    }
    return $out
}

proc ::scid_test::gui_fixtures::glist_widget::treeviewColumnCalls {path} {
    set out {}
    foreach key [array names ::scid_test::gui_fixtures::glist_widget::treeviewColumn "$path,*,*"] {
        lassign [split $key ,] widget col opt
        dict set out $col $opt $::scid_test::gui_fixtures::glist_widget::treeviewColumn($key)
    }
    return $out
}

proc ::scid_test::gui_fixtures::glist_widget::treeviewTagConfigureCalls {path} {
    if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewTagConfigure($path)]} {
        return {}
    }
    return $::scid_test::gui_fixtures::glist_widget::treeviewTagConfigure($path)
}

proc ::scid_test::gui_fixtures::glist_widget::treeviewRows {path} {
    set out {}
    foreach itemId [::scid_test::gui_fixtures::glist_widget::dispatchTreeview $path children {}] {
        set values {}
        if {[info exists ::scid_test::gui_fixtures::glist_widget::treeviewItemData($path,$itemId,-values)]} {
            set values $::scid_test::gui_fixtures::glist_widget::treeviewItemData($path,$itemId,-values)
        }
        set tag {}
        if {[info exists ::scid_test::gui_fixtures::glist_widget::treeviewItemData($path,$itemId,-tag)]} {
            set tag $::scid_test::gui_fixtures::glist_widget::treeviewItemData($path,$itemId,-tag)
        }
        lappend out [list $itemId $values $tag]
    }
    return $out
}

proc ::scid_test::gui_fixtures::glist_widget::treeviewDeleteCalls {path} {
    if {![info exists ::scid_test::gui_fixtures::glist_widget::treeviewDeleteCalls($path)]} {
        return {}
    }
    return $::scid_test::gui_fixtures::glist_widget::treeviewDeleteCalls($path)
}
