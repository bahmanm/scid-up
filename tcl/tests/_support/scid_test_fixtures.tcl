namespace eval ::scid_test {}

proc ::scid_test::ensureEngineListFile {} {
    # `tcl/tools/analysis.tcl` sources `[scidConfigFile engines]` at load time.
    # Provide a minimal file so it doesn’t try to auto-discover engines and so
    # the module can be sourced safely under `tclsh`.
    set enginesFile [scidConfigFile engines]
    if {[file exists $enginesFile]} {
        return $enginesFile
    }

    set dir [file dirname $enginesFile]
    file mkdir $dir

    set ch [open $enginesFile w]
    puts $ch {engine { Name "Dummy" Cmd "dummy" Dir "." UCI 1 UCIoptions {} }}
    close $ch

    return $enginesFile
}
