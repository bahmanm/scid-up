################################################################################
# ::file::Exit
#   Prompts for confirmation (when needed) then exits Scid.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Temporarily switches between open bases via `sc_base switch` to check for
#     unsaved changes.
#   - Closes any active tree mask via `::tree::mask::close`.
#   - May show a `tk_messageBox` confirmation dialog.
#   - Persists options via `options.write` when `::optionsAutoSave` is true.
#   - Persists recent files and history via `::recentFiles::save` and
#     `::utils::history::Save`.
#   - Destroys the main window (`destroy .`).
################################################################################
proc ::file::Exit {}  {
  # Check for altered game in all bases except the clipbase:
  set unsavedCount 0
  set savedBase [sc_base current]
  set msg ""
  foreach i [sc_base list] {
    sc_base switch $i
    if {[sc_game altered] && ![sc_base isReadOnly $i]} {
      if {$unsavedCount == 0} {
        append msg $::tr(ExitUnsaved)
        append msg "\n\n"
      }
      incr unsavedCount
      set fname [::file::BaseName $i]
      set g [sc_game number]
      append msg "   Base $i: $fname "
      append msg "($::tr(game) $g)"
      append msg "\n"
    }
  }
  # Switch back to original database:
  sc_base switch $savedBase

  # Check if a mask is opened and dirty
  ::tree::mask::close

  if {$msg != ""} {
    append msg "\n"
  }
  append msg $::tr(ExitDialog)

  # Only ask before exiting if there are unsaved changes:
  if {$unsavedCount > 0} {
    set answer [tk_messageBox -title "[tr ScidUp]: [tr FileExit]" \
        -message $msg -type yesno -icon question]
    if {$answer != "yes"} { return }
  }
  if {$::optionsAutoSave} {
    options.write
  }
  ::recentFiles::save
  ::utils::history::Save
  destroy .
}


################################################################################
# ::file::New
#   Opens a file-save dialog and creates a new database.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - The newly created base ID on success.
#   - None (empty string) when cancelled or on error.
# Side effects:
#   - Shows a `tk_getSaveFile` dialog.
#   - Creates a database via `sc_base create`.
#   - Updates `::curr_db`.
#   - Updates `::initialDir(base)`.
#   - Adds the new base to `::recentFiles`.
#   - Opens/refreshes the game list window via `::windows::gamelist::Open`.
#   - Notifies listeners via `::notify::DatabaseChanged` and `::notify::GameChanged`.
################################################################################
proc ::file::New {} {
  set ftype {
    { "Scid5 databases" {".si5"} }
    { "PGN files" {".pgn" ".PGN"} }
    { "Scid4 databases" {".si4"} }
  }

  set fName [tk_getSaveFile \
             -initialdir $::initialDir(base) \
             -filetypes $ftype \
             -defaultextension ".si5" \
             -title "Create a [tr ScidUp] database"]

  if {$fName == ""} { return }
  set file_extension [string tolower [file extension $fName]]
  if {$file_extension == ".si5"} {
    set dbType "SCID5"
  } elseif {$file_extension == ".si4"} {
    set dbType "SCID4"
  } elseif {$file_extension == ".pgn"} {
    set dbType "PGN"
  }
  if {[catch {sc_base create $dbType $fName} baseId]} {
    ERROR::MessageBox "$fName\n"
    return
  }
  set ::curr_db $baseId
  set ::initialDir(base) [file dirname $fName]
  ::recentFiles::add $fName
  ::windows::gamelist::Open $::curr_db
  ::notify::DatabaseChanged
  ::notify::GameChanged
  return $baseId
}

################################################################################
# ::file::Open
#   Opens a file-open dialog (when no filename is provided) and opens the selected
#   database.
# Visibility:
#   Public.
# Inputs:
#   - fName: Optional string path. When empty, a `tk_getOpenFile` dialog is shown.
# Returns:
#   - Integer error code from `::file::Open_` (0 on success; non-zero on failure
#     or cancellation).
# Side effects:
#   - Opens the database via `::file::Open_` and writes `::file::lastOpened`.
#   - Updates `::initialDir(base)`, `::curr_db`, recent files, and the game list UI.
#   - Notifies listeners via `::notify::DatabaseChanged` and, when appropriate,
#     `::notify::GameChanged`.
#   - May auto-load a game based on the base's `autoload` extra tag.
################################################################################
proc ::file::Open {{fName ""}} {
  if {$fName == ""} {
      set ftype {
        { "All Scid files" {".si5" ".si4" ".si3" ".pgn" ".epd"} }
        { "Scid databases" {".si5" ".si4" ".si3"} }
        { "PGN files" {".pgn" ".PGN"} }
        { "EPD files" {".epd" ".EPD"} }
      }

    set fName [tk_getOpenFile -initialdir $::initialDir(base) -filetypes $ftype -title "Open a [tr ScidUp] file"]
  }
  set err [::file::Open_ "$fName"]
  if {$err == 0} {
    set ::initialDir(base) [file dirname "$fName"]
    ::recentFiles::add "$fName"
    set ::curr_db $::file::lastOpened
    ::windows::gamelist::Open $::curr_db
    ::notify::DatabaseChanged
    set gamenum 1
    foreach {tagname tagvalue} [sc_base extra $::curr_db] {
      if {$tagname eq "autoload" && [string is integer -strict $tagvalue] && $tagvalue > 0} {
        set gamenum $tagvalue
        break
      }
    }
    if {$gamenum <= [sc_base numGames $::curr_db]} {
      ::game::Load $gamenum 0
    } else {
      ::notify::GameChanged
    }
  }
  return $err
}

################################################################################
# ::file::OpenOrSwitch
#   Opens a database, or switches to it when it is already open.
# Visibility:
#   Public.
# Inputs:
#   - fname: String path to a database file.
# Returns:
#   - Integer error code (0 on success; non-zero on failure), as returned by
#     `::file::SwitchToBase` or `::file::Open`.
# Side effects:
#   - May switch the active base via `::file::SwitchToBase`.
#   - May open a new base via `::file::Open`.
################################################################################
proc ::file::OpenOrSwitch { fname } {
  set slot [sc_base slot $fname]
  if {$slot != 0} {
    return [::file::SwitchToBase $slot]
  }
  return [::file::Open "$fname"]
}

################################################################################
# ::file::openBaseAsTree
#   Opens a database and creates a tree window for it, then returns to the
#   previously active base.
# Visibility:
#   Public.
# Inputs:
#   - fName: Optional string path. When empty, `::file::Open` will prompt.
# Returns:
#   - Integer error code from `::file::Open`.
# Side effects:
#   - Opens a base via `::file::Open`.
#   - Switches back to the previously active base via `::file::SwitchToBase`.
#   - Creates a tree window via `::tree::make` (readonly mode).
################################################################################
proc ::file::openBaseAsTree { { fName "" } } {
  set current [sc_base current]
  set err [::file::Open $fName]
  if {! $err} {
    ::file::SwitchToBase $current
    ::tree::make $::file::lastOpened 1
  }
  return $err
}

################################################################################
# ::file::Open_
#   Opens the given database file without updating `::curr_db` or the game list UI.
# Visibility:
#   Private (internal helper).
# Inputs:
#   - fName: String path to open.
# Returns:
#   - Integer error code: 0 on success; 1 on failure; 2 when no filename was
#     provided.
# Side effects:
#   - Writes `::file::lastOpened` on successful open/create.
#   - May show progress UI via `progressWindow` / `closeProgressWindow`.
#   - May show error UI via `tk_messageBox` / `ERROR::MessageBox`.
#   - May import EPD content via `importPgnFile` (for `.epd`).
#   - May set base metadata via `sc_base extra ... type 3` (for PGN/EPD).
################################################################################
proc ::file::Open_ {fName } {
  if {$fName == ""} { return 2}

  set ext [string tolower [file extension "$fName"] ]
  if {[sc_base slot $fName] != 0} {
    tk_messageBox -title "[tr ScidUp]: opening file" -message "The database you selected is already opened."
    return 1
  }

  set err 0
  if {"$ext" == ".si3"} {
    set err [::file::Upgrade [file rootname "$fName"] ]
  } elseif {"$ext" == ".pgn"} {
    # PGN file:
    set tip "[tr Tip]:\n[tr TipConvertPGN]\n([tr Database] -> [tr CopyAllGames] -> [tr FileNew])"
    progressWindow [tr ScidUp] "$::tr(OpeningTheDatabase): $fName...\n\n$tip" $::tr(Cancel)
    set err [catch {sc_base open PGN "$fName"} ::file::lastOpened]
    closeProgressWindow
    if {$err} {
      ERROR::MessageBox "$fName\n"
    } else {
      catch { sc_base extra $::file::lastOpened type 3 }
    }
  } elseif {"$ext" == ".epd"} {
    # EPD file:
    set err [catch {sc_base create MEMORY "$fName"} ::file::lastOpened]
    if {$err} {
      ERROR::MessageBox "$fName\n"
    } else {
      importPgnFile $::file::lastOpened [list "$fName"]
      sc_base extra $::file::lastOpened type 3
    }
  } else {
    if {$ext == ".si5" || $ext eq ""} {
      set dbType "SCID5"
    } elseif {$ext == ".si4"} {
      set dbType "SCID4"
    } else {
      tk_messageBox -title "[tr ScidUp]: opening file" -message "Unsupported database format:  $ext"
      return 1;
    }
    progressWindow [tr ScidUp] "$::tr(OpeningTheDatabase): [file tail "$fName"]..." $::tr(Cancel)
    set err [catch {sc_base open $dbType $fName} ::file::lastOpened]
    closeProgressWindow
    if {$err} {
      if { $::errorCode == $::ERROR::NameDataLoss } { set err 0 }
      ERROR::MessageBox "$fName\n"
    }
  }

  return $err
}

################################################################################
# ::file::Upgrade
#   Upgrades an old (version 3) Scid database to version 4.
# Visibility:
#   Public.
# Inputs:
#   - name: Base path without extension (e.g. "/path/to/base" for base.si3).
# Returns:
#   - Integer error code: 0 on success; 1 on failure.
#   - None (empty string) when the user declines confirmation dialogs.
# Side effects:
#   - May show `tk_messageBox` confirmation dialogs.
#   - Copies `.sg3/.sn3/.si3` files to `.sg4/.sn4/.si4`.
#   - Opens the upgraded base via `sc_base open` and writes `::file::lastOpened`.
#   - Compacts the upgraded base via `sc_base compact` on success.
#   - Shows progress UI via `progressWindow` / `closeProgressWindow`.
#   - May delete partially created `.sg4/.sn4/.si4` files on failure.
################################################################################
proc ::file::Upgrade {name} {
  if {[file readable "$name.si4"]} {
    set msg [string trim $::tr(ConfirmOpenNew)]
    set res [tk_messageBox -title [tr ScidUp] -type yesno -icon info -message $msg]
    if {$res == "no"} { return }
    return [::file::Open_ "$name.si4"]
  }

  set msg [string trim $::tr(ConfirmUpgrade)]
  set res [tk_messageBox -title [tr ScidUp] -type yesno -icon info -message $msg]
  if {$res == "no"} { return }

  set err [catch {
    file copy "$name.sg3"  "$name.sg4"
    file copy "$name.sn3"  "$name.sn4"
    file copy "$name.si3"  "$name.si4" }]
  if {$err} {
    ERROR::MessageBox "$name\n"
    return 1
  }

  progressWindow [tr ScidUp] "$::tr(Opening): [file tail $name]..." $::tr(Cancel)
  set err [catch {sc_base open $name} ::file::lastOpened]
  closeProgressWindow
  if {$::errorCode == $::ERROR::NameDataLoss} {
    ERROR::MessageBox "$name\n"
    set err 0
  }
  if {$err} {
    ERROR::MessageBox "$name\n"
    catch {
      file delete "$name.sg4"
      file delete "$name.sn4"
      file delete "$name.si4" }
  } else {
    progressWindow [tr ScidUp] [concat $::tr(CompactDatabase) "..."] $::tr(Cancel)
    set err_compact [catch {sc_base compact $::file::lastOpened}]
    closeProgressWindow
    if {$err_compact} { ERROR::MessageBox }
  }
  return $err
}

################################################################################
# ::file::Close
#   Closes a database (defaulting to the current base).
# Visibility:
#   Public.
# Inputs:
#   - base: Optional base slot number; defaults to the current base.
# Returns:
#   - None.
# Side effects:
#   - Switches to the target base via `sc_base switch` to confirm discarding changes.
#   - Destroys `.treeWin$base` if it exists.
#   - Calls `::search::CloseAll`.
#   - Closes the base via `sc_base close`.
#   - Notifies clipbase modification via `::notify::DatabaseModified` when the user
#     chooses to discard changes into the clipbase.
#   - Switches back to the original base (or the clipbase when the current base is
#     being closed) via `::file::SwitchToBase`.
################################################################################
proc ::file::Close {{base -1}} {
  # Remember the current base:
  set current [sc_base current]
  if {$base < 0} { set base $current }
  if {![sc_base inUse $base]} { return }
  # Switch to the base which will be closed, and check for changes:
  sc_base switch $base
  set confirm [::game::ConfirmDiscard]
  if {$confirm == 0} {
    sc_base switch $current
    return
  }
  # Close Tree window whenever a base is closed/switched:
  if {[winfo exists .treeWin$base]} { destroy .treeWin$base }

  ::search::CloseAll

  # If base to close was the current one, reset to clipbase
  if { $current == $base } { set current 9 }

  if {[catch {sc_base close $base}]} {
    ERROR::MessageBox
  }

  if {$confirm == 2} { ::notify::DatabaseModified $::clipbase_db }

  # Now switch back to the original base
  ::file::SwitchToBase $current 0
}

################################################################################
# ::file::SwitchToBase
#   Switches the active database slot.
# Visibility:
#   Public.
# Inputs:
#   - b: Base slot number.
#   - saveHistory: Unused; retained for compatibility with existing call sites.
# Returns:
#   - 0 on success.
#   - 1 on error (e.g. `sc_base switch` throws).
# Side effects:
#   - On success, updates `::curr_db`.
#   - Always notifies listeners via `::notify::GameChanged` and
#     `::notify::DatabaseChanged`.
################################################################################
proc ::file::SwitchToBase {{b} {saveHistory 1}} {
  set err 1
  if {![catch {sc_base switch $b} res]} {
    set err 0
    set ::curr_db $res
  }
  ::notify::GameChanged
  ::notify::DatabaseChanged
  return $err
}

################################################################################
# ::file::BaseName
# Visibility:
#   Public.
# Inputs:
#   - baseIdx: Base slot number.
# Returns:
#   - The base filename for the slot. If it ends with `.si5`, the extension is removed.
# Side effects:
#   - None.
################################################################################
proc ::file::BaseName {baseIdx} {
  set fname [file tail [sc_base filename $baseIdx]]
  set ext [string tolower [file extension $fname] ]
  if {$ext == ".si5"} {
    return [file rootname $fname]
  }
  return $fname
}

################################################################################
# ::file::autoLoadBases.load
#   Automatically opens the bases listed in `::autoLoadBases`.
# Visibility:
#   Private (startup helper).
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - May open multiple bases via `::file::Open`.
#   - Removes entries from `::autoLoadBases` that fail to open.
################################################################################
proc ::file::autoLoadBases.load {} {
  if {![info exists ::autoLoadBases]} { return }
  foreach base $::autoLoadBases {
    if {[::file::Open $base] != 0} {
      set idx [lsearch -exact $::autoLoadBases $base]
      if {$idx != -1} { set ::autoLoadBases [lreplace $::autoLoadBases $idx $idx] }
    }
  }
}

################################################################################
# ::file::autoLoadBases.save
#   Writes the current `::autoLoadBases` list to a Tcl script stream.
# Visibility:
#   Private (persistence helper).
# Inputs:
#   - channelId: A writable Tcl channel.
# Returns:
#   - None.
# Side effects:
#   - Writes to the provided channel via `puts`.
################################################################################
proc ::file::autoLoadBases.save { {channelId} } {
  if {![info exists ::autoLoadBases]} { return }
  puts $channelId "set ::autoLoadBases [list $::autoLoadBases]"
}

################################################################################
# ::file::autoLoadBases.find
#   Finds a base slot's filename in `::autoLoadBases`.
# Visibility:
#   Private (startup helper).
# Inputs:
#   - baseIdx: Base slot number.
# Returns:
#   - The index within `::autoLoadBases` when found.
#   - -1 when not found or when the list is unset / filename lookup fails.
# Side effects:
#   - None.
################################################################################
proc ::file::autoLoadBases.find { {baseIdx} } {
  if {![info exists ::autoLoadBases]} { return -1 }
  if {[ catch {set base [sc_base filename $baseIdx]} ]} { return -1}
  return [lsearch -exact $::autoLoadBases $base]
}

################################################################################
# ::file::autoLoadBases.add
#   Adds a base slot's filename to `::autoLoadBases`.
# Visibility:
#   Private (startup helper).
# Inputs:
#   - baseIdx: Base slot number.
# Returns:
#   - None.
# Side effects:
#   - Appends to `::autoLoadBases`.
################################################################################
proc ::file::autoLoadBases.add { {baseIdx} } {
  if {[ catch {set base [sc_base filename $baseIdx]} ]} { return }
  lappend ::autoLoadBases $base
}

################################################################################
# ::file::autoLoadBases.remove
#   Removes a base slot's filename from `::autoLoadBases`.
# Visibility:
#   Private (startup helper).
# Inputs:
#   - baseIdx: Base slot number.
# Returns:
#   - The removed entry's index when found.
#   - -1 when not found or when `::autoLoadBases` is unset.
#   - None (empty string) when `sc_base filename` fails.
# Side effects:
#   - Updates `::autoLoadBases` when an entry is removed.
################################################################################
proc ::file::autoLoadBases.remove { {baseIdx} } {
  if {![info exists ::autoLoadBases]} { return -1 }
  if {[ catch {set base [sc_base filename $baseIdx]} ]} { return }
  set idx [lsearch -exact $::autoLoadBases $base]
  if {$idx != -1} {
    set ::autoLoadBases [lreplace $::autoLoadBases $idx $idx]
  }
  return $idx
}
