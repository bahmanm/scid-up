namespace eval ::scid_test {}

# Stub Scid config path resolution for modules that do config I/O at load time.
# In the full application this is provided elsewhere after `InitDirs`.
if {![llength [info commands scidConfigFile]]} {
    proc scidConfigFile {name} {
        return [file join [::scid_test::tempDir] $name]
    }
}

# Minimal `sc_info` stub required to source modules under `tclsh`.
# The real command is provided by the C++ core when running Scid.
if {![llength [info commands sc_info]]} {
    proc sc_info {subcmd args} {
        switch -- $subcmd {
            limit {
                # `analysis.tcl` queries: `sc_info limit elo`
                if {[llength $args] >= 1 && [lindex $args 0] eq "elo"} {
                    return 4000
                }
                return 0
            }
            default {
                return ""
            }
        }
    }
}

# Minimal `sc_pos` stub required by helpers that query side/move number.
# The real command is provided by the C++ core when running Scid.
if {![llength [info commands sc_pos]]} {
    proc sc_pos {subcmd args} {
        switch -- $subcmd {
            side {
                if {![info exists ::scid_test::sc_pos_side]} {
                    error "::scid_test::sc_pos_side is not set by the test"
                }
                return $::scid_test::sc_pos_side
            }
            moveNumber {
                if {![info exists ::scid_test::sc_pos_moveNumber]} {
                    error "::scid_test::sc_pos_moveNumber is not set by the test"
                }
                return $::scid_test::sc_pos_moveNumber
            }
            fen {
                if {![info exists ::scid_test::sc_pos_fen]} {
                    error "::scid_test::sc_pos_fen is not set by the test"
                }
                return $::scid_test::sc_pos_fen
            }
            default {
                error "sc_pos $subcmd not stubbed in tests"
            }
        }
    }
}

# Minimal `winfo` stub so procs can early-return in headless tests.
# The real command is provided by Tk (`wish`).
if {![llength [info commands winfo]]} {
    proc winfo {subcmd args} {
        switch -- $subcmd {
            exists { return 0 }
            default { error "winfo $subcmd not stubbed in tests" }
        }
    }
}

# `strIsPrefix` is normally provided by Scid's Tcl runtime; keep a tiny local
# implementation for pure formatting helpers such as `formatAnalysisMoves`.
if {![llength [info commands strIsPrefix]]} {
    proc strIsPrefix {prefix text} {
        expr {[string first $prefix $text] == 0}
    }
}

# Minimal message box stub (for headless tests). Tests can override by setting
# `::scid_test::tk_messageBox_answer`.
if {![llength [info commands tk_messageBox]]} {
    proc tk_messageBox {args} {
        if {[info exists ::scid_test::tk_messageBox_answer]} {
            return $::scid_test::tk_messageBox_answer
        }

        # Be strict for confirmation prompts. Returning "ok" for a "yes/no"
        # dialog can mask behavioural regressions.
        set typeIdx [lsearch -exact $args "-type"]
        if {$typeIdx != -1 && ($typeIdx + 1) < [llength $args]} {
            set type [lindex $args [expr {$typeIdx + 1}]]
            if {$type eq "yesno"} {
                error "tk_messageBox -type yesno called without ::scid_test::tk_messageBox_answer"
            }
        }

        return "ok"
    }
}

# Minimal `sc_game` stub for tag manipulation helpers.
if {![llength [info commands sc_game]]} {
    if {![info exists ::scid_test::sc_game_extra]} {
        set ::scid_test::sc_game_extra {}
    }

    proc sc_game {subcmd args} {
        switch -- $subcmd {
            tags {
                set op [lindex $args 0]
                switch -- $op {
                    get {
                        set tagName [lindex $args 1]
                        if {$tagName ne "Extra"} {
                            error "sc_game tags get $tagName not stubbed in tests"
                        }
                        return $::scid_test::sc_game_extra
                    }
                    set {
                        # Only the `-extra` form is required by tests.
                        if {[lindex $args 1] ne "-extra"} {
                            error "sc_game tags set form not stubbed in tests"
                        }
                        set ::scid_test::sc_game_extra [lindex $args 2]
                        return
                    }
                    default {
                        error "sc_game tags $op not stubbed in tests"
                    }
                }
            }
            default {
                error "sc_game $subcmd not stubbed in tests"
            }
        }
    }
}

# Minimal `sc_move` stub for exercising `sc_move_add`.
if {![llength [info commands sc_move]]} {
    proc sc_move {subcmd args} {
        switch -- $subcmd {
            addSan {
                set ::scid_test::last_addSan [lindex $args 0]
                return
            }
            default {
                error "sc_move $subcmd not stubbed in tests"
            }
        }
    }
}

# Minimal `::uci::sc_move_add` stub for exercising the UCI branch of `sc_move_add`.
if {![llength [info commands ::uci::sc_move_add]]} {
    namespace eval ::uci {}
    proc ::uci::sc_move_add {moves} {
        set ::scid_test::last_uci_sc_move_add $moves
        return 0
    }
}

# Provide platform flags commonly assumed to exist in the full application.
if {![info exists ::windowsOS]} { set ::windowsOS 0 }

# Provide directory variables that some modules expect at load time.
# Keep these deterministic so test behaviour does not depend on the process CWD.
if {![info exists ::scidExeDir]} { set ::scidExeDir [::scid_test::repoRoot] }
if {![info exists ::scidShareDir]} { set ::scidShareDir [::scid_test::repoRoot] }
if {![info exists ::scidUserDir]} { set ::scidUserDir [::scid_test::tempDir] }

# Stub options persistence registration used by various modules at load time.
if {![llength [info commands ::options.store]]} {
    # Mirror Scid’s real contract (see `tcl/options.tcl`):
    # - If the variable does not exist, initialises it (defaulting to "").
    # - Registers the variable for persistence via `::autosave_opt`.
    proc ::options.store {varname {default_value ""}} {
        if {![info exists $varname]} {
            set $varname $default_value
        }
        if {![info exists ::autosave_opt] || [lsearch -exact $::autosave_opt $varname] == -1} {
            lappend ::autosave_opt $varname
        }
    }
}
