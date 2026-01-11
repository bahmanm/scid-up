namespace eval ::scidup {}
namespace eval ::scidup::dirs {}

proc ::scidup::dirs::configRoot {{platform ""} {os ""} {exeDir ""}} {
    if {$platform eq ""} {
        set platform $::tcl_platform(platform)
    }
    if {$os eq ""} {
        set os $::tcl_platform(os)
    }
    if {$exeDir eq ""} {
        set exeDir [file dirname [info nameofexecutable]]
    }

    set xdgConfigHome ""
    if {[info exists ::env(XDG_CONFIG_HOME)] && $::env(XDG_CONFIG_HOME) ne ""} {
        set xdgConfigHome $::env(XDG_CONFIG_HOME)
    } elseif {[info exists ::env(XDG_CONFIG_DIR)] && $::env(XDG_CONFIG_DIR) ne ""} {
        set xdgConfigHome $::env(XDG_CONFIG_DIR)
    }

    if {$xdgConfigHome ne ""} {
        return [file nativename [file join $xdgConfigHome "scid-up"]]
    }

    if {$platform eq "windows"} {
        if {[info exists ::env(APPDATA)] && $::env(APPDATA) ne ""} {
            return [file nativename [file join $::env(APPDATA) "scid-up"]]
        }
        return [file nativename $exeDir]
    }

    if {$os eq "Darwin"} {
        return [file nativename [file join [file nativename "~"] "Library" "Application Support" "scid-up"]]
    }

    return [file nativename [file join [file nativename "~/.config"] "scid-up"]]
}

