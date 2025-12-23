namespace eval ::scid_test {}

# Stub Scid config path resolution for modules that do config I/O at load time.
# In the full application this is provided elsewhere after `InitDirs`.
if {![llength [info procs scidConfigFile]]} {
    proc scidConfigFile {name} {
        return [file join [::scid_test::tempDir] $name]
    }
}

# Minimal `sc_info` stub required to source modules under `tclsh`.
# The real command is provided by the C++ core when running Scid.
if {![llength [info procs sc_info]]} {
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
if {![llength [info procs sc_pos]]} {
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
            default {
                error "sc_pos $subcmd not stubbed in tests"
            }
        }
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
if {![llength [info procs ::options.store]]} {
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
