########################################################################
# Copyright (C) 2020-2023 Fulvio Benini
#
# This file is part of SCID (Shane's Chess Information Database).
# SCID is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.

### Functions and sub-window for chess engine configuration.

namespace eval enginecfg {
    variable PROTOCOL_UCI_LOCAL 1
    variable PROTOCOL_UCI_NET 2
}

################################################################################
# ::enginecfg::names
#   Returns engine names sorted by last-use timestamp.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - (list<string>): Engine names, ordered by the `time` field descending.
# Side effects:
#   - Reads `::engines(list)`.
################################################################################
proc ::enginecfg::names {} {
    return [lmap elem [lsort -integer -decreasing -index 5 $::engines(list)] {
        lindex $elem 0
    }]
}

################################################################################
# ::enginecfg::get
#   Returns the stored configuration for an engine.
# Visibility:
#   Public.
# Inputs:
#   - name (string): Engine name (as stored in `::engines(list)`).
# Returns:
#   - (list|""): The engine configuration list, or "" if not found.
# Side effects:
#   - Normalises legacy metadata stored in element 6 when present.
################################################################################
proc ::enginecfg::get {name} {
    set res [lsearch -exact -inline -index 0 $::engines(list) $name]
    if {$res ne ""} {
        # The old url element is now used to store the values for:
        # scoreside notation pvwrap debugframe priority netport
        if {[llength [lindex $res 6]] != 6} {
            lset res 6 [list white 1 word false normal ""]
        }
    }
    return $res
}

################################################################################
# ::enginecfg::rename
#   Renames an engine entry and persists the updated engine list.
# Visibility:
#   Public.
# Inputs:
#   - oldname (string): Existing engine name.
#   - newname (string): Desired new name.
# Returns:
#   - (string): The new unique name on success; otherwise `oldname`.
# Side effects:
#   - Updates `::engines(list)`.
#   - Writes `[scidConfigFile engines]` via `::enginecfg::write`.
################################################################################
proc ::enginecfg::rename {oldname newname} {
    set idx [lsearch -exact -index 0 $::engines(list) $oldname]
    if {$idx < 0 || $newname eq $oldname || $newname eq ""} {
        return $oldname
    }
    set newname [::enginecfg::uniquename $newname]
    lset ::engines(list) $idx 0 $newname
    ::enginecfg::write
    return $newname
}

################################################################################
# ::enginecfg::uniquename
#   Returns a unique engine name by appending/incrementing a numeric suffix.
# Visibility:
#   Private.
# Inputs:
#   - name (string): Desired engine name.
# Returns:
#   - (string): A name not currently present in `::engines(list)`.
# Side effects:
#   - Reads `::engines(list)`.
################################################################################
proc ::enginecfg::uniquename {name} {
    set copyn 0
    while {[lsearch -exact -index 0 $::engines(list) $name] >= 0} {
        regexp {^(.*?)\s*(\(\d+\))*$} $name -> name
        set name "$name ([incr copyn])"
    }
    return $name
}

################################################################################
# ::enginecfg::add
#   Adds a new engine entry (ensuring a unique name) and persists it.
# Visibility:
#   Public.
# Inputs:
#   - enginecfg (list): Engine configuration list.
# Returns:
#   - (string|""): The stored engine name on success; otherwise "".
# Side effects:
#   - Appends to `::engines(list)`.
#   - Writes `[scidConfigFile engines]` via `::enginecfg::save`.
################################################################################
proc ::enginecfg::add {enginecfg} {
    lset enginecfg 0 [::enginecfg::uniquename [lindex $enginecfg 0]]
    lappend ::engines(list) $enginecfg
    return [::enginecfg::save $enginecfg true]
}

################################################################################
# ::enginecfg::remove
#   Removes an engine entry after user confirmation and persists the update.
# Visibility:
#   Public.
# Inputs:
#   - name (string): Engine name to remove.
# Returns:
#   - (bool): true if removed; otherwise false.
# Side effects:
#   - Shows a confirmation `tk_messageBox`.
#   - Updates `::engines(list)`.
#   - Writes `[scidConfigFile engines]` via `::enginecfg::write`.
################################################################################
proc ::enginecfg::remove {name} {
    set idx [lsearch -exact -index 0 $::engines(list) $name]
    if {$idx < 0} { return false }

    lassign [lindex $::engines(list) $idx] name cmd
    set msg "Name: $name\n"
    append msg "Command: $cmd\n\n"
    append msg "Do you really want to remove this engine from the list?"
    set answer [tk_messageBox -title [tr ScidUp] -icon question -type yesno -message $msg]
    if {$answer ne "yes"} { return false }

    set ::engines(list) [lreplace $::engines(list) $idx $idx]
    ::enginecfg::write
    return true
}

################################################################################
# ::enginecfg::save
#   Replaces an existing engine entry and persists changes when necessary.
# Visibility:
#   Public.
# Inputs:
#   - enginecfg (list): Engine configuration list (must already exist by name).
#   - force_write (bool, optional): When true, always write the engines file.
# Returns:
#   - (string|""): The engine name on success; otherwise "" if not found.
# Side effects:
#   - Normalises UCI option storage by persisting only non-default, non-internal
#     option values.
#   - Updates `::engines(list)`.
#   - Writes `[scidConfigFile engines]` via `::enginecfg::write`.
################################################################################
proc ::enginecfg::save {enginecfg {force_write false}} {
    lassign $enginecfg enginename
    set idx [lsearch -exact -index 0 $::engines(list) $enginename]
    if {$idx < 0} {
        return ""
    }
    lset enginecfg 8 [lmap elem [lindex $enginecfg 8] {
        lassign $elem name value type default min max var_list internal
        if {$internal || $value eq $default} { continue }
        list $name $value
    }]
    if {$force_write || [lindex $::engines(list) $idx] ne $enginecfg} {
        lset ::engines(list) $idx $enginecfg
        ::enginecfg::write
    }
    return $enginename
}

################################################################################
# ::enginecfg::write
#   Writes the analysis engines list file.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Writes `[scidConfigFile engines]`.
# Notes:
#   - Throws on I/O errors.
################################################################################
proc ::enginecfg::write {} {
    set enginesFile [scidConfigFile engines]
    set f [open $enginesFile w]
    puts $f "\# Analysis engines list file for Scid $::scidVersion with UCI support"
    puts $f ""
    foreach e $::engines(list) {
        lassign $e name cmd args dir elo time url uci opt
        puts $f "engine {"
            puts $f "  Name [list $name]"
            puts $f "  Cmd  [list $cmd]"
            puts $f "  Args [list $args]"
            puts $f "  Dir  [list $dir]"
            puts $f "  Elo  [list $elo]"
            puts $f "  Time [list $time]"
            puts $f "  URL  [list $url]"
            puts $f "  UCI [list $uci]"
            puts $f "  UCIoptions [list $opt]"
            puts $f "}"
        puts $f ""
    }
    close $f
}

################################################################################
# ::enginecfg::dlgNewLocal
#   Prompts the user to select a local engine executable and adds it.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - (string|""): New engine name on success; otherwise "".
# Side effects:
#   - Opens `tk_getOpenFile`.
#   - Updates `::scidEnginesDir`.
#   - Appends to `::engines(list)` via `::enginecfg::add`.
################################################################################
proc ::enginecfg::dlgNewLocal {} {
    if {$::windowsOS} {
        lappend ftype [list "Executable" [list ".exe" ".bat"]]
    }
    lappend ftype [list "All files" *]
    set fName [tk_getOpenFile -initialdir $::scidEnginesDir -filetypes $ftype]
    if {$fName eq ""} { return "" }
    set ::scidEnginesDir [file dirname $fName]
    return [::enginecfg::add [list $fName $fName {} {} {} 0 {} $::enginecfg::PROTOCOL_UCI_LOCAL {}]]
}

################################################################################
# ::enginecfg::dlgNewRemote
#   Prompts for a remote engine address (hostname:port) and adds it.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - (string|""): New engine name on success; otherwise "".
# Side effects:
#   - Creates `.engineDlgNewRemote`.
#   - Appends to `::engines(list)` via `::enginecfg::add`.
################################################################################
proc ::enginecfg::dlgNewRemote {} {
    set ::enginecfg_dlgresult ""
    set w .engineDlgNewRemote
    win::createDialog $w
    pack [ttk::label $w.msg -text "Remote engine (hostname:port):"] -fill x
    pack [ttk::entry $w.value] -fill x
    dialogbutton $w.cancel -text [tr Cancel] -command [list destroy $w]
    dialogbutton $w.ok -text "OK" -command [list apply {{w} {
        set ::enginecfg_dlgresult [$w.value get]
        destroy $w
    } ::} $w]
    ::packdlgbuttons $w.cancel $w.ok
    grab $w
    tkwait window $w
    if {$::enginecfg_dlgresult eq ""} { return "" }
    return [::enginecfg::add [list $::enginecfg_dlgresult $::enginecfg_dlgresult {} {} {} 0 {} $::enginecfg::PROTOCOL_UCI_NET {}]]
}

# TODO: no references to ::enginewin should exists in this file

################################################################################
# ::enginecfg::createConfigButtons
#   Creates engine-selection and engine-management buttons.
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - w (string): Parent widget path.
#   - fn_connect (command): Callback invoked on engine selection.
# Returns:
#   - None.
# Side effects:
#   - Creates widgets under `$w`.
#   - Binds `<<ComboboxSelected>>` and a custom `<<UpdateEngineName>>` event.
################################################################################
proc ::enginecfg::createConfigButtons {id w fn_connect} {
    ttk::combobox $w.engine -width 30 -state readonly -postcommand [list apply {{w} {
        $w.engine configure -values [::enginecfg::names ]
    }} $w]
    bind $w.engine <<ComboboxSelected>> [list apply {{fn_connect} {
        {*}$fn_connect [%W get]
    }} $fn_connect]
    ::utils::tooltip::Set $w.engine [tr EngineSelect]

    ttk::button $w.reload -text "\u21BB" -style Toolbutton \
        -command [list event generate $w.engine <<ComboboxSelected>>]
    ::utils::tooltip::Set $w.reload [tr EngineReload]

    ttk::button $w.addpipe -text "\u271A" -style Toolbutton -command [list apply {{fn_connect} {
        if {[set newEngine [::enginecfg::dlgNewLocal]] ne ""} {
            {*}$fn_connect $newEngine
        }
    }} $fn_connect]
    ::utils::tooltip::Set $w.addpipe [tr EngineAddLocal]

    ttk::button $w.addremote -text "\u2B82" -style Toolbutton -command [list apply {{fn_connect} {
        if {[set newEngine [::enginecfg::dlgNewRemote]] ne ""} {
            {*}$fn_connect $newEngine
        }
    }} $fn_connect]
    ::utils::tooltip::Set $w.addremote [tr EngineAddRemote]

    ttk::button $w.clone -text "\u29C9" -style Toolbutton -command [list apply {{id fn_connect} {
        {*}$fn_connect [::enginecfg::add [set ::enginecfg::engConfig_$id]]
    }} $id $fn_connect]
    ::utils::tooltip::Set $w.clone [tr EngineClone]

    ttk::button $w.delete -text "\u2A02" -style Toolbutton -command [list apply {{w fn_connect} {
        if {[::enginecfg::remove [$w.engine get]]} {
            {*}$fn_connect {}
        }
    }} $w $fn_connect]
    ::utils::tooltip::Set $w.delete [tr EngineDelete]

    grid $w.engine $w.reload $w.addpipe $w.addremote \
         $w.clone $w.delete -sticky news -padx 4

    bind $w <<UpdateEngineName>> [list apply {{w} {
        lassign %d name
        set state "normal"
        if {$name eq ""} {
            set name "[tr Engine]:"
            set state "disabled"
        }
        $w.engine set $name
        $w.reload configure -state $state
        $w.clone configure -state $state
        $w.delete configure -state $state
    }} $w]
}

################################################################################
# ::enginecfg::createConfigFrame
#   Creates the frame content used to display engine configuration messages.
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - configFrame (string): Parent frame path.
#   - msg (string): Initial message text.
# Returns:
#   - None.
# Side effects:
#   - Creates a disabled text widget under `$configFrame`.
################################################################################
proc ::enginecfg::createConfigFrame {id configFrame msg} {
    ttk_text $configFrame.text -wrap none -padx 4
    autoscrollBars both $configFrame $configFrame.text
    $configFrame.text insert end $msg
    $configFrame.text configure -state disabled
}

################################################################################
# ::enginecfg::updateConfigFrame
#   Updates (and if necessary recreates) the engine configuration and option UI.
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - configFrame (string): Frame containing the configuration widgets.
#   - msgInfoConfig (list|""): InfoConfig payload `{protocol netclients options}`.
# Returns:
#   - (string): A new engine name if auto-config triggers a rename; otherwise "".
# Side effects:
#   - Updates `::enginecfg::engConfig_$id` and widgets under `$configFrame`.
#   - May rename the engine and persist the engine list.
################################################################################
proc ::enginecfg::updateConfigFrame {id configFrame msgInfoConfig} {
    upvar ::enginecfg::engConfig_$id engConfig_
    set w $configFrame.text
    lassign $msgInfoConfig protocol netclients options

    # Replace the engine's available options
    set oldOptions [lindex $engConfig_ 8]
    lset engConfig_ 8 $options

    set renamed ""
    set recreate_widgets 1
    if {$msgInfoConfig eq ""} {
        # An emtpy message -> recreate all the widgets
    } elseif {[lindex $engConfig_ 7] == ""} {
        # A new engine added with auto-config, update the name and protocol
        # and recreate all the widgets
        lassign $engConfig_ currname
        if {[set idx [lsearch -index 0 $options "myname"]] >=0} {
            set renamed [::enginecfg::rename $currname [lindex $options $idx 1]]
            lset engConfig_ 0 $renamed
        }
        lset engConfig_ 7 [expr { $protocol eq "uci" }]

    } elseif {[winfo exists $w.name] && [string equal \
                            [lmap elem $oldOptions {lreplace $elem 1 1}] \
                            [lmap elem $options {lreplace $elem 1 1}]]} {
        # Same options, no need to recreate the widgets
        set recreate_widgets 0
    }

    $w configure -state normal
    if {$recreate_widgets} {
        if {![::enginecfg::createConfigWidgets $id $configFrame $engConfig_]} {
            # The option widgets are not created if the engine is not open
            $w configure -state disabled
            return $renamed
        }
        ::enginecfg::createOptionWidgets $id $configFrame $options
    }
    ::enginecfg::updateOptionWidgets $id $configFrame $options $oldOptions
    ::enginecfg::updateNetClients $configFrame $netclients
    $w configure -state disabled
    return $renamed
}

################################################################################
# ::enginecfg::autoSaveConfig
#   Enables or disables automatic persistence on configuration UI destruction.
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - configFrame (string): Frame containing the configuration widgets.
#   - autosave (bool, optional): When true, saves on widget destroy.
# Returns:
#   - None.
# Side effects:
#   - Binds/unbinds a `<Destroy>` handler on `$configFrame.text`.
################################################################################
proc ::enginecfg::autoSaveConfig {id configFrame {autosave false}} {
    if {$autosave} {
        bind $configFrame.text <Destroy> [list apply {{id} {
            ::enginecfg::save [set ::enginecfg::engConfig_$id]
        } ::} $id]
    } else {
        bind $configFrame.text <Destroy> {}
    }
}

################################################################################
# ::enginecfg::findOption
#   Finds an engine option by name (case-insensitive).
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - name (string): Option name to find.
# Returns:
#   - (int): Index within the options list.
# Side effects:
#   - Reads `::enginecfg::engConfig_$id`.
# Notes:
#   - Throws if the option does not exist.
################################################################################
proc ::enginecfg::findOption {id name} {
    set options [lindex [set ::enginecfg::engConfig_$id] 8]
    for {set idx 0} {$idx < [llength $options]} {incr idx} {
        lassign [lindex $options $idx] option_name
        if {[string equal -nocase $name $option_name]} {
            return $idx
        }
    }
    error "wrong option"
}

################################################################################
# ::enginecfg::setOption
#   Validates and submits a single option value to the engine (if changed).
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - idx (int): Option index within `engConfig_$id`.
#   - value (string): New value to submit.
# Returns:
#   - (bool): true if a SetOptions message was sent; otherwise false.
# Side effects:
#   - Calls `::engine::send $id SetOptions ...`.
# Notes:
#   - Throws on validation errors.
################################################################################
proc ::enginecfg::setOption {id idx value} {
    lassign [lindex [set ::enginecfg::engConfig_$id] 8 $idx] \
        name oldValue type default min max

    if {$value eq $oldValue} { return false }

    if {$value eq ""} {
        set value $default
    } elseif {$min != "" && $max != ""} {
        if {$value < $min || $value > $max} {
            error "wrong value"
        }
    } elseif {![catch { set values [$widget cget -values] }]} {
        if {[set idx [lsearch -exact -nocase $values $value]] != -1} {
            set value [lindex $values $idx]
        } else {
            error "wrong value"
        }
    }
    ::engine::send $id SetOptions [list [list $name $value]]
    return true
}

################################################################################
# ::enginecfg::setOptionFromWidget
#   Reads an option value from a widget and submits it to the engine (if changed).
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - idx (int): Option index.
#   - widget (string): Widget path supporting `get` and `configure`.
# Returns:
#   - (bool): true if a SetOptions message was sent; otherwise false.
# Side effects:
#   - Calls `::enginecfg::setOption`.
#   - On validation error, sets widget style to `Error.<WidgetClass>`.
################################################################################
proc ::enginecfg::setOptionFromWidget {id idx widget} {
    set value [$widget get]
    if {[catch {::enginecfg::setOption $id $idx $value} res]} {
        $widget configure -style Error.[winfo class $widget]
        return false
    }
    $widget configure -style {}
    return $res
}

################################################################################
# ::enginecfg::createConfigWidgets
#   Creates widgets to edit an engine's core configuration (command, args, dir,
#   notation, layout, priority, and network settings).
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - configFrame (string): Frame containing the configuration widgets.
#   - engCfg (list): Engine configuration list.
# Returns:
#   - (bool): true if widgets were created; false if the engine is not open.
# Side effects:
#   - Creates widgets under `$configFrame.text`.
#   - Wires UI callbacks that can reconnect engines and change display layout.
################################################################################
proc ::enginecfg::createConfigWidgets {id configFrame engCfg} {
    lassign $engCfg name cmd args wdir elo time url protocolFlag
    lassign $url scoreside notation pvwrap debugframe priority netport

    set w $configFrame.text

    $w delete 1.0 end

    # Use the last element from the sorted list of the labels' width.
    $w configure -tabs [lindex [lsort -integer [lmap elem [list \
        EngineCmd EngineArgs EngineDir EngineProtocol EngineNotation \
        EngineFlipEvaluation EngineShowLog LowPriority EngineNetworkd] {
             font measure font_Regular -displayof $w "[tr $elem]: "
        }]] end]

    if {$name == ""} {
        ::enginecfg::clearConfigFrame $configFrame
        return false
    }

    set fn_create_entry {{w widget label value} {
        $w insert end "$label:\t"
        ttk::entry $w.$widget
        $w window create end -window $w.$widget -pady 2
        $w.$widget insert end "$value"
        set wd [string length $value]
        if {$wd < 24} { set wd 24 } elseif {$wd > 60} { set wd 60 }
        $w.$widget configure -width $wd
    }}

    apply $fn_create_entry $w name [tr EngineName] $name
    bind $w.name <FocusOut> [list apply {{id} {
        lassign [set ::enginecfg::engConfig_$id] old
        if {$old ne [set name [%W get]]} {
            ::enginecfg::save [set ::enginecfg::engConfig_$id]
            ::enginewin::connectEngine $id [::enginecfg::rename $old $name]
        }
    }} $id]
    bind $w.name <Return> [bind $w.name <FocusOut>]

    apply $fn_create_entry $w cmd "\n[tr EngineCmd]" $cmd
    bind $w.cmd <FocusOut> [list apply {{id} { ::enginecfg::onSubmitParam $id cmd [%W get] } ::} $id]
    bind $w.cmd <Return> [bind $w.cmd <FocusOut>]
    ttk::button $w.cmdbtn -style Pad0.Small.TButton -text ... \
        -command [list ::enginecfg::onSubmitParam $id cmd {} 1]
    $w window create end -window $w.cmdbtn -pady 2 -padx 2

    apply $fn_create_entry $w args "\n[tr EngineArgs]" $args
    bind $w.args <FocusOut> [list apply {{id} { ::enginecfg::onSubmitParam $id args [%W get] } ::} $id]
    bind $w.args <Return> [bind $w.args <FocusOut>]

    apply $fn_create_entry $w wdir "\n[tr EngineDir]" $wdir
    bind $w.wdir <FocusOut> [list apply {{id} { ::enginecfg::onSubmitParam $id wdir [%W get] } ::} $id]
    bind $w.wdir <Return> [bind $w.wdir <FocusOut>]
    ttk::button $w.wdirbtn -style Pad0.Small.TButton -text ... \
        -command [list ::enginecfg::onSubmitParam $id wdir {} 2]
    $w window create end -window $w.wdirbtn -pady 2 -padx 2

    $w insert end "\n[tr EngineProtocol]:\t"
    $w insert end [expr {$protocolFlag == $::enginecfg::PROTOCOL_UCI_NET ? "network" : "uci"}]

    $w insert end "\n[tr EngineNotation]:\t"
    ttk::combobox $w.notation -state readonly -width 12 -values [list engine SAN "English SAN" figurine]
    bind $w.notation <<ComboboxSelected>> [list apply {{id} {
        ::enginecfg::onChangeLayout $id notation [%W current]
    } ::} $id]
    $w window create end -window $w.notation -pady 2
    $w.notation current [expr { $notation < 0 ? 0 - $notation : $notation }]
    ::enginecfg::onChangeLayout $id notation $notation

    ttk::checkbutton $w.wrap -text [tr GInfoWrap] -onvalue word -offvalue none -style Toolbutton \
        -command [list apply {{id wrapVar} {
            ::enginecfg::onChangeLayout $id wrap [set $wrapVar]
        } ::} $id ::$w.wrap]
    $w window create end -window $w.wrap -pady 2 -padx 6
    set ::$w.wrap $pvwrap

    $w insert end "\n[tr EngineFlipEvaluation]:\t"
    ttk::checkbutton $w.scoreside -style Switch.Toolbutton -onvalue engine -offvalue white \
        -command [list apply {{id btn} {
            ::enginecfg::onChangeLayout $id scoreside [::update_switch_btn $btn]
        } ::} $id $w.scoreside]
    ::update_switch_btn $w.scoreside $scoreside
    $w window create end -window $w.scoreside -pady 2

    $w insert end "\n[tr EngineShowLog]:\t"
    ttk::checkbutton $w.debug -style Switch.Toolbutton -command [list apply {{id w} {
        set enabled [::update_switch_btn $w.debug]
        lset ::enginecfg::engConfig_$id 6 3 $enabled
        ::enginewin::logEngine $id $enabled
    } ::} $id $w]
    ::update_switch_btn $w.debug $debugframe
    $w window create end -window $w.debug -pady 2

    if {[catch {::engine::pid $id} enginePid]} {
        return false
    }
    if {$enginePid != ""} {
        $w insert end "\n[tr LowPriority]:\t"
        ttk::checkbutton $w.priority -onvalue idle -offvalue normal \
            -style Switch.Toolbutton -command [list apply {{id w enginePid} {
                set priority [::update_switch_btn $w.priority]
                catch { sc_info priority $enginePid $priority }
                lset ::enginecfg::engConfig_$id 6 4 $priority
            } ::} $id $w $enginePid]
        ::update_switch_btn $w.priority $priority
        $w window create end -window $w.priority -pady 2
        $w insert end "  pid: $enginePid"
        if {$priority eq "idle"} {
            catch { sc_info priority $enginePid idle }
        }
    }

    $w insert end "\n[tr EngineNetworkd]:\t"
    ttk::combobox $w.netd -state readonly -width 12 -values {off on auto_port}
    $w window create end -window $w.netd -pady 2
    $w insert end "  port: "
    ttk::entry $w.netport -width 6 -validate key -validatecommand { string is integer %P }
    $w window create end -window $w.netport -pady 2
    bind $w.netd <<ComboboxSelected>> [list ::enginecfg::onSubmitNetd $id $w]
    bind $w.netport <FocusOut> [list apply {{id w} {
        if {"readonly" ni [%W state]} {
            ::enginecfg::onSubmitNetd $id $w
        }
    } ::} $id $w]
    bind $w.netport <Return> [bind $w.netport <FocusOut>]
    if {$netport eq ""} {
        $w.netd set "off"
        $w.netport configure -state disabled
    } elseif {[string match "auto_*" $netport]} {
        $w.netd set "auto_port"
        $w.netport insert 0 [string range $netport 5 end]
        $w.netport configure -state readonly
    } else {
        $w.netd set "on"
        $w.netport insert 0 $netport
    }
    $w insert end "\n" netclients_tag

    return true
}

################################################################################
# ::enginecfg::createOptionWidgets
#   Creates widgets to show and edit engine-specific options.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - configFrame (string): Frame containing the configuration widgets.
#   - options (list): Option descriptors received from the engine.
# Returns:
#   - None.
# Side effects:
#   - Creates option widgets under `$configFrame.text`.
################################################################################
proc ::enginecfg::createOptionWidgets {id configFrame options} {
    set w $configFrame.text

    set tab_width 0
    set disableReset 1
    for {set i 0} {$i < [llength $options]} {incr i} {
        lassign [lindex $options $i] name value type default min max var_list internal
        if {$internal} { continue }

        if {$disableReset} {
            set disableReset 0
            $w insert end "\n"
            ttk::button $w.reset -style Pad0.Small.TButton -text "Reset Options" \
                -command [list ::enginecfg::onSubmitReset $id $configFrame]
            $w window create end -window $w.reset
        }
        $w insert end "\n$name:" opt_label "\t"
        set label_width [font measure font_Regular -displayof $w "$name: "]
        if {$label_width > $tab_width} {
            set tab_width $label_width
            $w tag configure opt_label -tabs $tab_width
        }
        set btn ""
        if {$type eq "button" || $type eq "save" || $type eq "reset"} {
            set btn $name
        } else {
            if {$type eq "combo"} {
                lassign [lsort -decreasing -integer [lmap elem $var_list { string length $elem }]] maxlen
                ttk::combobox $w.value$i -width [incr maxlen] -values $var_list -state readonly
                bind $w.value$i <<ComboboxSelected>> [list ::enginecfg::setOptionFromWidget $id $i %W]
            } elseif {$type eq "check"} {
                ttk::checkbutton $w.value$i -onvalue true -offvalue false -style Switch.Toolbutton -command \
                    [list apply {{id i btn} {
                        ::enginecfg::setOption $id $i [::update_switch_btn $btn]
                    } ::} $id $i $w.value$i]
            } else {
                if {$type eq "spin" || $type eq "slider"} {
                    ttk::spinbox $w.value$i -width 12 -from $min -to $max -increment 1 \
                        -validate key -validatecommand { string is integer %P } \
                        -command [list after idle [list ::enginecfg::setOptionFromWidget $id $i $w.value$i]]
                } else {
                    ttk::entry $w.value$i
                    if {$type eq "file"} {
                        set btn "..."
                    } elseif {$type eq "path"} {
                        set btn "+ ..."
                    }
                }
                # Special vars like %W cannot be used in <FocusOut> because the
                # other events are forwarded to it
                bind $w.value$i <FocusOut> [list ::enginecfg::setOptionFromWidget $id $i $w.value$i]
                bind $w.value$i <Return> [bind $w.value$i <FocusOut>]
            }
            $w window create end -window $w.value$i -pady 2
        }
        if {$btn ne ""} {
            ttk::button $w.button$i -style Pad0.Small.TButton -text $btn \
                -command [list ::enginecfg::onSubmitButton $id $i]
            $w window create end -window $w.button$i -padx 2 -pady 2
        } elseif {$type eq "spin" || $type eq "slider"} {
            $w insert end " (Range: $min ... $max)"
        }
    }
}

################################################################################
# ::enginecfg::updateOptionWidgets
#   Updates option widgets to reflect the latest option values.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - configFrame (string): Frame containing the option widgets.
#   - options (list): Current option descriptors.
#   - oldOptions (list): Previous option descriptors (may be "").
# Returns:
#   - None.
# Side effects:
#   - Updates widget values and visual highlighting under `$configFrame.text`.
################################################################################
proc ::enginecfg::updateOptionWidgets {id configFrame options oldOptions} {
    set w $configFrame.text

    set disableReset 1
    for {set i 0} {$i < [llength $options]} {incr i} {
        lassign [lindex $options $i] name value type default min max var_list internal
        if {$internal || $type in [list button save reset]} { continue }

        if {$disableReset && $value ne $default} {
            $w.reset configure -state normal
            set disableReset 0
        }

        if {$oldOptions ne "" && $value eq [lindex $oldOptions $i 1]} {
            if {$type eq "check"} {
                set widget_value [::update_switch_btn $w.value$i]
            } else {
                set widget_value [$w.value$i get]
            }
            if {$value eq $widget_value} { continue }
        }

        if {$value eq $default} {
            $w tag remove header "$w.value$i linestart" $w.value$i
        } else {
            $w tag add header "$w.value$i linestart" $w.value$i
        }
        if {$type eq "string" || $type eq "file" || $type eq "path"} {
            set wd [string length $value]
            if {$wd < 24} { set wd 24 } elseif {$wd > 60} { set wd 60 }
            $w.value$i configure -width $wd
        }
        if {$type eq "combo"} {
            $w.value$i set $value
        } elseif {$type eq "check"} {
            ::update_switch_btn $w.value$i $value
        } else {
            $w.value$i configure -style {}
            $w.value$i delete 0 end
            $w.value$i insert 0 $value
        }
    }
    if {$disableReset && [winfo exists $w.reset]} {
        $w.reset configure -state disabled
    }
}

################################################################################
# ::enginecfg::updateNetClients
#   Updates the “network connections” text block in the configuration view.
# Visibility:
#   Private.
# Inputs:
#   - configFrame (string): Frame containing the configuration widgets.
#   - netclients (list): List of remote client descriptors.
# Returns:
#   - None.
# Side effects:
#   - Replaces content tagged `netclients_tag` in `$configFrame.text`.
################################################################################
proc ::enginecfg::updateNetClients {configFrame netclients} {
    set w $configFrame.text

    set strclients "\n"
    if {[llength $netclients]} {
        append strclients "Network Connections:"
        foreach client $netclients {
            append strclients "\t$client\n"
        }
    }
    $w replace netclients_tag.first netclients_tag.last $strclients netclients_tag
}

################################################################################
# ::enginecfg::onSubmitParam
#   Applies a core connection parameter change and reconnects the engine.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - connectParam (string): One of "cmd", "args", or "wdir".
#   - newValue (string): New value (or "" to prompt via dialog when opendlg != 0).
#   - opendlg (int, optional): 0 for no dialog; 1 to open a file chooser; 2 to
#     open a directory chooser.
# Returns:
#   - None.
# Side effects:
#   - Updates `::enginecfg::engConfig_$id` and reconnects via
#     `::enginewin::connectEngine`.
################################################################################
proc ::enginecfg::onSubmitParam {id connectParam newValue {opendlg 0}} {
    switch $connectParam {
        "cmd"      { set configIdx 1 }
        "args"     { set configIdx 2 }
        "wdir"     { set configIdx 3 }
        default { error "wrong option" }
    }
    upvar ::enginecfg::engConfig_$id engConfig_
    set oldValue [lindex $engConfig_ $configIdx]
    if {$opendlg} {
        set dlgcmd [expr { $opendlg == 1 ? "tk_getOpenFile" : "tk_chooseDirectory" }]
        set newValue [$dlgcmd -initialdir [file dirname $oldValue]]
        if {$newValue == ""} {
            return
        }
    }
    if {$newValue ne $oldValue} {
        lset engConfig_ $configIdx $newValue
        ::enginewin::connectEngine $id [::enginecfg::save $engConfig_]
    }
}

################################################################################
# ::enginecfg::onSubmitReset
#   Resets all non-internal options to their default values.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - w (string): Unused widget argument (kept for callback signature).
# Returns:
#   - None.
# Side effects:
#   - Sends a SetOptions message via `::engine::send`.
################################################################################
proc ::enginecfg::onSubmitReset {id w} {
    upvar ::enginecfg::engConfig_$id engConfig_
    set options {}
    foreach option [lindex $engConfig_ 8] {
        lassign $option name value type default min max var_list internal
        if {! $internal && $value ne $default} {
            lappend options [list $name $default]
        }
    }
    if {[llength $options]} {
        ::engine::send $id SetOptions $options
    }
}

################################################################################
# ::enginecfg::onSubmitButton
#   Submits a button/file/path option to the engine.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - idx (int): Option index.
# Returns:
#   - None.
# Side effects:
#   - For type "file"/"path", prompts via `tk_getOpenFile`/`tk_chooseDirectory`.
#   - Sends a SetOptions message via `::engine::send`.
# Notes:
#   - For file/path options, the displayed value is updated on the next
#     InfoConfig refresh.
################################################################################
proc ::enginecfg::onSubmitButton {id idx} {
    lassign [lindex [set ::enginecfg::engConfig_$id] 8 $idx] \
        name oldValue type default min max

    if {$type eq "file"} {
        set value [tk_getOpenFile]
        if {$value == ""} { return }
    } elseif {$type eq "path"} {
        set value [tk_chooseDirectory]
        if {$value == ""} { return }
        if {$oldValue ne "" && $oldValue ne "<empty>"} {
            append oldValue [expr {$::windowsOS ? ";" : ":"}]
            set value "$oldValue$value"
        }
    } else {
        set value ""
    }
    ::engine::send $id SetOptions [list [list $name $value]]
}

################################################################################
# ::enginecfg::setupNetd
#   Starts/stops the engine network server and persists the configured port.
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - netport (string): "" to disable; a port number; or "auto_<seed>" to enable
#     auto-port selection.
# Returns:
#   - (string|int): The listening port; "" when remote connections are disabled.
# Side effects:
#   - Calls `::engine::netserver`.
#   - Updates `::enginecfg::engConfig_$id` (netport metadata).
################################################################################
proc ::enginecfg::setupNetd {id netport} {
    set new_value ""
    if {[string match "auto_*" $netport]} {
        set new_value "auto_"
        set netport 0
    }
    set port [::engine::netserver $id $netport]
    append new_value $port
    lset ::enginecfg::engConfig_$id 6 5 $new_value
    return $port
}

################################################################################
# ::enginecfg::onSubmitNetd
#   Applies changes to the networkd controls (enable/disable/auto-port).
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - w (string): Widget container holding `.netd` and `.netport`.
# Returns:
#   - None.
# Side effects:
#   - Calls `::enginecfg::setupNetd`.
#   - Updates widget state and displays errors via `ERROR::MessageBox`.
################################################################################
proc ::enginecfg::onSubmitNetd {id w} {
    set old_value [lindex [set ::enginecfg::engConfig_$id] 6 5]

    switch [$w.netd get] {
      "auto_port" {
          set netport auto_
          set state readonly
      }
      "on" {
          set netport [$w.netport get]
          set state normal
      }
      default {
          set netport ""
          set state disabled
      }
    }
    $w.netport configure -state normal -style {}
    if {$old_value ne $netport} {
        if {[catch {
            set port [::enginecfg::setupNetd $id $netport]
            $w.netport delete 0 end
            $w.netport insert 0 $port
        }]} {
            $w.netport configure -style Error.TEntry
            ERROR::MessageBox
        }
    }
    $w.netport configure -state $state
}

################################################################################
# ::enginecfg::onChangeLayout
#   Persists display/layout-related settings and notifies the engine window.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - param (string): One of "scoreside", "notation", or "wrap".
#   - value (string|int): New value for the setting.
# Returns:
#   - None.
# Side effects:
#   - Updates `::enginecfg::engConfig_$id`.
#   - Calls `::enginewin::changeDisplayLayout`.
################################################################################
proc ::enginecfg::onChangeLayout {id param value} {
    upvar ::enginecfg::engConfig_$id engConfig_
    switch $param {
        "scoreside" {
            set idx 0
        }
        "notation" {
            set idx 1
            if {$value < 0} {
                set value [expr { 0 - $value }]
            }
        }
        "wrap" {
            set idx 2
        }
        default { error "changeLayout unknown $param" }
    }
    lset engConfig_ 6 $idx $value
    ::enginewin::changeDisplayLayout $id $param $value
}
