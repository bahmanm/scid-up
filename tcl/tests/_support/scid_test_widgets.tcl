namespace eval ::scid_test {}
namespace eval ::scid_test::widgets {}

namespace eval ::scid_test::widgets {
    variable created {}

    # Store progressbar step calls per widget, indexed by ($path).
    array set steps {}

    # Store configuration/state per widget, indexed by ($path,$option).
    # Examples:
    #   state(.w,-state) = "disabled"
    #   state(.w,-maximum) = 100
    array set state {}

	# Store appended text per widget (for text-like doubles).
	array set text {}

	# Store `tag configure`/`tag config` calls per widget, indexed by ($path).
	array set tagConfigureCalls {}

	# Store `tag bind` calls per widget, indexed by ($path).
	array set tagBindCalls {}

	# Store `tag remove` calls per widget, indexed by ($path).
	array set tagRemoveCalls {}

	# Store `tag add` calls per widget, indexed by ($path).
	array set tagAddCalls {}

	# Store `tag nextrange` calls per widget, indexed by ($path).
	array set tagNextRangeCalls {}

	# Store configurable `tag nextrange` results, indexed by ($path,$tagName).
	array set tagNextRangeResults {}

	# Store `see` calls per widget, indexed by ($path).
	array set seeCalls {}

	# Store `yview` calls per widget, indexed by ($path).
	array set yviewCalls {}
}

# Resets all widget doubles created via this helper.
proc ::scid_test::widgets::reset {} {
    variable created
    variable steps
    variable state
    variable text
    variable tagConfigureCalls
    variable tagBindCalls
    variable tagRemoveCalls
    variable tagAddCalls
    variable tagNextRangeCalls
    variable tagNextRangeResults
    variable seeCalls
    variable yviewCalls

    foreach w $created {
        catch {rename $w ""}
    }

    set created {}

    array unset steps
    array unset state
    array unset text
    array unset tagConfigureCalls
    array unset tagBindCalls
    array unset tagRemoveCalls
    array unset tagAddCalls
    array unset tagNextRangeCalls
    array unset tagNextRangeResults
    array unset seeCalls
    array unset yviewCalls
}

# Defines a lightweight widget command double.
#
# The resulting command supports a minimal Tk-like interface:
#   - `$w configure -opt value ...`
#   - `$w cget -opt`
#   - `$w step n`                (records step calls)
#   - `$w delete ...` / `$w insert ...` (records inserted text)
proc ::scid_test::widgets::defineWidget {path} {
    variable created

    if {[llength [info commands $path]]} {
        error "Widget command already exists: $path"
    }

    interp alias {} $path {} ::scid_test::widgets::dispatch $path
    lappend created $path
    return $path
}

proc ::scid_test::widgets::defineTextWidget {path} {
    variable created

    if {[llength [info commands $path]]} {
        error "Widget command already exists: $path"
    }

    interp alias {} $path {} ::scid_test::widgets::dispatchText $path
    lappend created $path
    return $path
}

proc ::scid_test::widgets::dispatch {path subcmd args} {
    variable state
    variable text
    variable steps

    switch -- $subcmd {
        configure {
            if {[llength $args] % 2 != 0} {
                error "Widget $path configure expects option/value pairs, got: $args"
            }
            foreach {opt val} $args {
                set state($path,$opt) $val
            }
            return
        }
        cget {
            set opt [lindex $args 0]
            if {![info exists state($path,$opt)]} {
                error "Widget $path missing option $opt"
            }
            return $state($path,$opt)
        }
        step {
            set amount [lindex $args 0]
            lappend steps($path) $amount

            # Maintain a `-value` for callers that query it.
            if {[info exists state($path,-value)]} {
                set state($path,-value) [expr {$state($path,-value) + $amount}]
            } else {
                set state($path,-value) $amount
            }
            return
        }
        delete {
            set text($path) ""
            return
        }
        insert {
            # Expected: insert <index> <text>
            set inserted [lindex $args 1]
            append text($path) $inserted
            return
        }
        default {
            error "Widget $path subcommand $subcmd not stubbed"
        }
    }
}

proc ::scid_test::widgets::dispatchText {path subcmd args} {
    variable tagConfigureCalls
    variable tagBindCalls
    variable tagRemoveCalls
    variable tagAddCalls
    variable tagNextRangeCalls
    variable tagNextRangeResults
    variable seeCalls
    variable yviewCalls

    switch -- $subcmd {
        see {
            # see <index>
            lappend seeCalls($path) [lindex $args 0]
            return
        }
        yview {
            # yview moveto <fraction>
            lappend yviewCalls($path) [list {*}$args]
            return
        }
        tag {
            # Continue below.
        }
        default {
            return [::scid_test::widgets::dispatch $path $subcmd {*}$args]
        }
    }

    set tagSubcmd [lindex $args 0]
    switch -- $tagSubcmd {
        configure -
        config {
            # tag (config|configure) <tagName> ?options...?
            set tagName [lindex $args 1]
            lappend tagConfigureCalls($path) [list $tagName {*}[lrange $args 2 end]]
            return
        }
        bind {
            # tag bind <tagName> <sequence> <script>
            set tagName [lindex $args 1]
            set sequence [lindex $args 2]
            set script [lindex $args 3]
            lappend tagBindCalls($path) [list $tagName $sequence $script]
            return
        }
        remove {
            # tag remove <tagName> <start> <end>
            set tagName [lindex $args 1]
            set start [lindex $args 2]
            set end [lindex $args 3]
            lappend tagRemoveCalls($path) [list $tagName $start $end]
            return
        }
        add {
            # tag add <tagName> <start> <end>
            set tagName [lindex $args 1]
            set start [lindex $args 2]
            set end [lindex $args 3]
            lappend tagAddCalls($path) [list $tagName $start $end]
            return
        }
        nextrange {
            # tag nextrange <tagName> <startIndex> ?stopIndex?
            set tagName [lindex $args 1]
            set startIndex [lindex $args 2]
            set stopIndex [lindex $args 3]
            lappend tagNextRangeCalls($path) [list $tagName $startIndex $stopIndex]

            if {[info exists tagNextRangeResults($path,$tagName)]} {
                return $tagNextRangeResults($path,$tagName)
            }
            return {}
        }
        default {
            error "Widget $path tag $tagSubcmd not stubbed"
        }
    }
}

proc ::scid_test::widgets::setTagNextRangeResult {path tagName range} {
    variable tagNextRangeResults
    set tagNextRangeResults($path,$tagName) $range
}

proc ::scid_test::widgets::setState {path opt val} {
    variable state
    set state($path,$opt) $val
}

proc ::scid_test::widgets::hasState {path opt} {
    variable state
    expr {[info exists state($path,$opt)]}
}

proc ::scid_test::widgets::getState {path opt} {
    variable state
    if {![info exists state($path,$opt)]} {
        error "Widget $path missing option $opt"
    }
    return $state($path,$opt)
}

proc ::scid_test::widgets::getText {path} {
    variable text
    if {![info exists text($path)]} {
        return ""
    }
    return $text($path)
}

proc ::scid_test::widgets::getTagConfigureCalls {path} {
    variable tagConfigureCalls
    if {![info exists tagConfigureCalls($path)]} {
        return {}
    }
    return $tagConfigureCalls($path)
}

proc ::scid_test::widgets::getTagBindCalls {path} {
    variable tagBindCalls
    if {![info exists tagBindCalls($path)]} {
        return {}
    }
    return $tagBindCalls($path)
}

proc ::scid_test::widgets::getTagRemoveCalls {path} {
    variable tagRemoveCalls
    if {![info exists tagRemoveCalls($path)]} {
        return {}
    }
    return $tagRemoveCalls($path)
}

proc ::scid_test::widgets::getTagAddCalls {path} {
    variable tagAddCalls
    if {![info exists tagAddCalls($path)]} {
        return {}
    }
    return $tagAddCalls($path)
}

proc ::scid_test::widgets::getTagNextRangeCalls {path} {
    variable tagNextRangeCalls
    if {![info exists tagNextRangeCalls($path)]} {
        return {}
    }
    return $tagNextRangeCalls($path)
}

proc ::scid_test::widgets::getSeeCalls {path} {
    variable seeCalls
    if {![info exists seeCalls($path)]} {
        return {}
    }
    return $seeCalls($path)
}

proc ::scid_test::widgets::getYviewCalls {path} {
    variable yviewCalls
    if {![info exists yviewCalls($path)]} {
        return {}
    }
    return $yviewCalls($path)
}

proc ::scid_test::widgets::getSteps {path} {
    variable steps
    if {![info exists steps($path)]} {
        return {}
    }
    return $steps($path)
}

proc ::scid_test::widgets::getAllSteps {} {
    variable steps
    return [array get steps]
}
