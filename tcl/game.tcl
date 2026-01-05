
################################################################################
# ::game::Clear
#   Clears the current game after confirming whether unsaved changes should be
#   discarded.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - "cancel" when the user cancels discarding changes.
#   - None otherwise.
# Side effects:
#   - May call `::notify::DatabaseModified` for either `::curr_db` or
#     `::clipbase_db`, depending on how the user chooses to proceed.
#   - Clears the current game via `sc_game new`.
#   - Calls `::notify::GameChanged`.
################################################################################
proc ::game::Clear {} {
  set confirm [::game::ConfirmDiscard]
  if {$confirm == 0} { return "cancel"}
  if {$confirm == 1} { ::notify::DatabaseModified $::curr_db }
  if {$confirm == 2} { ::notify::DatabaseModified $::clipbase_db }

  sc_game new
  ::notify::GameChanged
}

################################################################################
# ::game::Strip
#   Removes all comments or variations from the current game.
# Visibility:
#   Public.
# Inputs:
#   - type: String identifying what to strip (passed through to `sc_game strip`).
# Returns:
#   - None.
# Side effects:
#   - Records undo state via `undoFeature save`.
#   - Mutates the current game via `sc_game strip`.
#   - Shows a `tk_messageBox` on failure.
#   - Refreshes UI via `updateBoard -pgn` and `updateTitle` on success.
################################################################################
proc ::game::Strip {type} {
  undoFeature save
  if {[catch {sc_game strip $type} result]} {
    tk_messageBox -parent . -type ok -icon info -title "Scid" -message $result
    return
  }
  updateBoard -pgn
  updateTitle
}

################################################################################
# ::game::TruncateBegin
#   Truncates the current game to the current position by removing all moves
#   before the current position.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Records undo state via `undoFeature save`.
#   - Mutates the current game via `sc_game truncate -start`.
#   - Shows a `tk_messageBox` on failure.
#   - Refreshes UI via `updateBoard -pgn` and `updateTitle` on success.
################################################################################
proc ::game::TruncateBegin {} {
  undoFeature save
  if {[catch {sc_game truncate -start} result]} {
    tk_messageBox -parent . -type ok -icon info -title "Scid" -message $result
    return
  }
  updateBoard -pgn
  updateTitle
}

################################################################################
# ::game::Truncate
#   Truncates the current game to the current position by removing all moves
#   after the current position.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Records undo state via `undoFeature save`.
#   - Mutates the current game via `sc_game truncate`.
#   - Shows a `tk_messageBox` on failure.
#   - Refreshes UI via `updateBoard -pgn` and `updateTitle` on success.
################################################################################
proc ::game::Truncate {} {
  undoFeature save
  if {[catch {sc_game truncate} result]} {
    tk_messageBox -parent . -type ok -icon info -title "Scid" -message $result
    return
  }
  updateBoard -pgn
  updateTitle
}

################################################################################
# ::game::LoadNextPrev
#   Loads the next or previous game within the active filter.
# Visibility:
#   Public.
# Inputs:
#   - action: "previous" or "next" (passed through to `sc_filter`).
# Returns:
#   - None.
# Side effects:
#   - Loads a game via `::game::Load` when `sc_filter $action` returns a non-zero
#     game number.
################################################################################
proc ::game::LoadNextPrev {action} {
  set number [sc_filter $action]
  if {$number == 0} {
    return
  }
  ::game::Load $number
}

################################################################################
# ::game::Reload
#   Reloads the current game from the active database.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Reloads the current game via `::game::Load [sc_game number]` when a base is
#     in use and the current game number is valid.
################################################################################
proc ::game::Reload {} {
  if {![sc_base inUse]} { return }
  if {[sc_game number] < 1} { return }
  ::game::Load [sc_game number]
}

################################################################################
# ::game::LoadRandom
#   Loads a random game from the active database and filter.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Loads a random filtered game via `::game::Load`.
################################################################################
proc ::game::LoadRandom {} {
  set db [sc_base current]
  set filter "dbfilter"
  set ngames [sc_filter count $db $filter]
  if {$ngames == 0} { return }
  set r [expr {(int (rand() * $ngames))} ]
  set gnumber [sc_base gameslist $db $r 1 $filter N+]
  ::game::Load [split [lindex $gnumber 0] "_"]
}

################################################################################
# ::game::LoadMenu
#   Shows a context menu for actions on a specific game (browse, load, merge).
# Visibility:
#   Public.
# Inputs:
#   - w: Widget path used as the menu parent and name prefix.
#   - base: Base slot number for the target game.
#   - gnum: Game number within the base.
#   - x, y: Screen coordinates for menu placement.
# Returns:
#   - None.
# Side effects:
#   - Creates/configures a Tk `menu` widget.
#   - Posts the menu and binds menu items to actions (`::gbrowser::new`,
#     `::file::SwitchToBase` + `::game::Load`, and `mergeGame`).
################################################################################
proc ::game::LoadMenu {w base gnum x y} {
  set m $w.gLoadMenu
  if {! [winfo exists $m]} {
    menu $m
    $m add command -label $::tr(BrowseGame)
    $m add command -label $::tr(LoadGame)
    $m add command -label $::tr(MergeGame)
  }
  $m entryconfigure 0 -command [list ::gbrowser::new $base $gnum]
  $m entryconfigure 1 -command [list apply {{base gnum} {
    ::file::SwitchToBase $base 0
    ::game::Load $gnum
  } ::} $base $gnum]
  $m entryconfigure 2 -command [list mergeGame $base $gnum]
  event generate $w <ButtonRelease-1>
  $m post $x $y
  event generate $m <ButtonPress-1>
}


# ::game::moveEntryNumber
#
#   Entry variable for GotoMoveNumber dialog.
#
set ::game::moveEntryNumber ""
trace add variable ::game::moveEntryNumber write {::utils::validate::Regexp {^[0-9]*$}}

################################################################################
# ::game::GotoMoveNumber
#   Prompts for a move number and navigates to it in the current game.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Creates and displays a modal dialog `.mnumDialog`.
#   - Updates `::game::moveEntryNumber`.
#   - May move to a specific ply via `sc_move ply`.
#   - Refreshes the board via `updateBoard -pgn` when the user confirms.
################################################################################
proc ::game::GotoMoveNumber {} {
  set ::game::moveEntryNumber ""
  set w [toplevel .mnumDialog]
  wm title $w "Scid: [tr GameGotoMove]"
  grab $w
  set f [ttk::frame $w.f]
  pack $f -expand 1

  ttk::label $f.label -text $::tr(GotoMoveNumber)
  pack $f.label -side top -pady 5 -padx 5

  ttk::entry $f.entry -width 8 -textvariable ::game::moveEntryNumber
  bind $f.entry <Escape> { .mnumDialog.f.buttons.cancel invoke }
  bind $f.entry <Return> { .mnumDialog.f.buttons.load invoke }
  pack $f.entry -side top -pady 5

  set b [ttk::frame $f.buttons]
  pack $b -side top -fill x
  dialogbutton $b.load -text "OK" -command {
    grab release .mnumDialog
    if {$::game::moveEntryNumber > 0} {
      catch {sc_move ply [expr {($::game::moveEntryNumber - 1) * 2}]}
    }
    focus .
    destroy .mnumDialog
    updateBoard -pgn
  }
  dialogbutton $b.cancel -text $::tr(Cancel) -command {
    focus .
    grab release .mnumDialog
    destroy .mnumDialog
    focus .
  }
  packbuttons right $b.cancel $b.load

  set x [ expr {[winfo width .] / 4 + [winfo rootx .] } ]
  set y [ expr {[winfo height .] / 4 + [winfo rooty .] } ]
  wm geometry $w "+$x+$y"

  focus $f.entry
}

################################################################################
# ::game::mergeInBase
#   Merges a game from one base into the current game of another base.
# Visibility:
#   Public.
# Inputs:
#   - srcBase: Source base slot number.
#   - destBase: Destination base slot number (becomes the active base).
#   - gnum: Game number in `srcBase` to be merged.
# Returns:
#   - None.
# Side effects:
#   - Switches the active base via `::file::SwitchToBase`.
#   - Merges the source game via `mergeGame`.
################################################################################
proc ::game::mergeInBase { srcBase destBase gnum } {
  ::file::SwitchToBase $destBase
  mergeGame $srcBase $gnum
}



# Scid (Shane's Chess Information Database)
#
# Copyright (C) 2012-2015 Fulvio Benini
#
# Scid is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.

################################################################################
# ::game::Load
#   Loads a game into the current context, optionally positioning to a specific
#   ply.
# Visibility:
#   Public.
# Inputs:
#   - selection: Game identifier for `sc_game load` (commonly a game number, but
#     also supports composite forms used elsewhere in Scid).
#   - ply: Optional ply index; when provided, navigates via `sc_move ply`.
# Returns:
#   - 0 when the user cancels discarding changes, or when `sc_game load` fails.
#   - None on success.
# Side effects:
#   - May call `::notify::DatabaseModified` for either `::curr_db` or
#     `::clipbase_db`, depending on how the user chooses to proceed.
#   - Loads the game via `sc_game load`.
#   - May move to a ply via `sc_move ply`.
#   - Configures board orientation via `::board::flipAuto` based on the `FlipB`
#     tag in `sc_game tag get Extra` (defaulting to -1 when absent).
#   - Calls `::notify::GameChanged` on both success and load failure.
################################################################################
proc ::game::Load { selection {ply ""} } {
  set confirm [::game::ConfirmDiscard]
  if {$confirm == 0} { return 0}
  if {$confirm == 1} { ::notify::DatabaseModified $::curr_db }
  if {$confirm == 2} { ::notify::DatabaseModified $::clipbase_db }

  if {[catch {sc_game load $selection}]} {
    ERROR::MessageBox
    ::notify::GameChanged
    return 0
  }

  if {$ply != ""} { sc_move ply $ply }

  set extraTags [sc_game tag get Extra]
  regexp {FlipB "([01])"\n} $extraTags -> flipB
  if {![info exists flipB]} { set flipB -1 }
  ::board::flipAuto .main.board $flipB

  ::notify::GameChanged
}


################################################################################
# ::game::ConfirmDiscard
#   Prompts the user to decide how to handle unsaved changes in the current game.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - 0 to cancel the caller's action.
#   - 1 to continue after saving to the current database.
#   - 2 to continue after saving to the clipbase.
#   - 3 to continue after discarding changes (or when there are no changes).
# Side effects:
#   - Shows a modal confirmation dialog `.confirmDiscard` when the game is altered.
#   - May save the game via `sc_game save`.
#   - Updates `::game::answer` (dialog result state).
# Notes:
#   - When this returns 1 or 2, the caller is expected to invoke
#     `::notify::DatabaseModified` for the affected database.
################################################################################
proc ::game::ConfirmDiscard {} {
  if {! [sc_game altered]} { return 3 }

  #Default value: cancel action
  set ::game::answer 0

  set fname [::file::BaseName $::curr_db]
  set gnum [sc_game number]
  set players "[sc_game info white] - [sc_game info black]\n"
  if {[string equal " - \n" $players]} { set players "" }

  set w .confirmDiscard
  ::win::createDialog $w
  wm resizable $w 0 0
  wm title $w "Scid: [tr Save]"

  ttk::frame $w.msg
  ttk::label $w.msg.image -image tb_iconSave
  ttk::frame $w.msg.txt
  ttk::label $w.msg.txt.l1 -text "$players$fname: [tr game] $gnum" -relief groove
  ttk::label $w.msg.txt.l2 -text $::tr(ClearGameDialog) -wraplength 360 -font font_Bold -justify left
  grid $w.msg.txt.l1 -row 0 -sticky news -pady 4 -padx 2
  grid $w.msg.txt.l2 -row 1 -sticky news
  grid $w.msg.txt   -row 0 -column 0 -pady 6 -padx 10 -sticky w
  grid $w.msg.image -row 0 -column 1 -pady 6 -padx 6 -sticky ne

  #The first button that gets keyboard focus when pressing <tab>
  #Coincide with default value
  ttk::button $w.backBtn -text $::tr(GoBack) -command {
    destroy .confirmDiscard
  }

  ttk::button $w.saveBtn -text [tr SaveAndContinue] -image tb_BD_Save -compound left -command {
    set gnum [sc_game number]
    if {[catch {sc_game save $gnum $::curr_db}]} {
      ERROR::MessageBox
      set ::game::answer 0
    } else {
      set ::game::answer 1
	}
    destroy .confirmDiscard
  }

  ttk::button $w.clipbaseBtn -text [tr EditCopy] -image tb_BD_SaveAs -compound left -command {
    if {[catch {sc_game save 0 $::clipbase_db}]} {
      ERROR::MessageBox
      set ::game::answer 0
    } else {
	  set gnum [sc_base numGames $::clipbase_db]
      set ::game::answer 2
    }
    destroy .confirmDiscard
  }

  ttk::button $w.discardBtn -text [tr DiscardChangesAndContinue] -image tb_BD_VarDelete   -compound left -command {
    set ::game::answer 3
    destroy .confirmDiscard
  }

  grid $w.msg         -row 0 -columnspan 2
  grid $w.saveBtn     -row 1 -sticky nwe -padx 10 -pady 4 -columnspan 2
  grid $w.clipbaseBtn -row 2 -sticky nwe -padx 10 -pady 4 -columnspan 2
  grid $w.discardBtn  -row 3 -sticky nwe -padx 10 -pady 4 -columnspan 2
  grid $w.backBtn     -row 4 -column 1 -sticky e -padx 10 -pady "14 4"
  grid columnconfigure $w 2 -weight 1

  tk::PlaceWindow $w
  grab $w
  tkwait window $w
  return $::game::answer
}

# Grouping intercommunication between windows
# When complete this should be moved to a new notify.tcl file
namespace eval ::notify {
  ################################################################################
  # ::notify::GameChanged
  #   Notifies the UI that the current game (or its header information) has changed.
  # Visibility:
  #   Public.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Updates main game UI via `updateMainGame`.
  #   - Triggers a full position update via `::notify::PosChanged newgame`.
  #   - Refreshes dependent windows (`::windows::gamelist::Refresh`, `::maint::Refresh`).
  ################################################################################
  proc GameChanged {} {
    updateMainGame
    ::notify::PosChanged newgame
    ::windows::gamelist::Refresh 0
    ::maint::Refresh
  }

  ################################################################################
  # ::notify::PosChanged
  #   Notifies the UI and engines that the current position and/or game text has
  #   changed.
  # Visibility:
  #   Public.
  # Inputs:
  #   - pgn: Optional string flag. Non-empty indicates the game text needs a refresh.
  #     The value "pgnonly" indicates that only PGN text has changed.
  #     The value "newgame" indicates a new game was loaded/created.
  #   - animate: Optional non-empty value enables board animation (where supported).
  # Returns:
  #   - None.
  # Side effects:
  #   - Updates the board marks and pieces via `::board::setmarks` and `::board::update`.
  #   - Schedules `::notify::privGameTextChanged` and `::notify::privPosChanged` via
  #     idle callbacks.
  #   - Generates `<<NotifyNewGame>>` events when `pgn` is "newgame".
  #   - Notifies the engine window via `::enginewin::onPosChanged` (except for "pgnonly").
  ################################################################################
  proc PosChanged {{pgn ""} {animate ""}} {
    set pgnNeedsUpdate [expr {$pgn ne ""}]

    if {$pgnNeedsUpdate} {
      after cancel ::notify::privGameTextChanged
    } else {
      ::pgn::update_current_move
    }

    ::board::setmarks .main.board [sc_pos getComment]
    ::board::update .main.board [sc_pos board] [expr {$animate ne ""}]

    after cancel ::notify::privPosChanged
    if {$pgnNeedsUpdate} { after idle ::notify::privGameTextChanged }
    after idle ::notify::privPosChanged

    if {$pgn ne "pgnonly"} {
      # During the idle loop the engines can send Info messages for
      # the old position. Send now the new position to avoid that.
      if {$pgn eq "newgame"} {
        foreach wnd [::win::getWindows] {
          event generate $wnd <<NotifyNewGame>>
        }
      }
      ::enginewin::onPosChanged

      # TODO: Move here the function in privPosChanged that don't care about
      #       the game text and are not slow.
    }
  }

  ################################################################################
  # ::notify::privGameTextChanged
  #   Performs deferred updates that depend on the game text (tags, comments, PGN).
  # Visibility:
  #   Private.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Refreshes PGN and graphs views.
  ################################################################################
  proc privGameTextChanged {} {
    ::pgn::Refresh 1
    ::tools::graphs::score::Refresh 0
  }

  ################################################################################
  # ::notify::privPosChanged
  #   Performs deferred updates that depend on the current position and/or game
  #   text.
  # Visibility:
  #   Private.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Updates status, title, toolbars, analysis panes, tree filter, and other UI.
  ################################################################################
  proc privPosChanged {} {
    moveEntry_Clear
    updateStatusBar
    updateMainToolbar
    updateTitle
    if {$::showGameInfo} { updateGameInfo }
    updateAnalysis 1
    updateAnalysis 2
    ::windows::commenteditor::Refresh
    if {[winfo exists .twinchecker]} { updateTwinChecker }
    if {[winfo exists .bookWin]} { ::book::refresh }
    if {[winfo exists .bookTuningWin]} { ::book::refreshTuning }
    updateNoveltyWin
    ::updateTreeFilter
  }

  ################################################################################
  # ::notify::DatabaseChanged
  #   Notifies the UI that the current database has changed (or a new base was opened).
  # Visibility:
  #   Public.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Updates `::curr_db` from `sc_base current`.
  #   - Refreshes switcher, stats, maintenance, menus, and graphs.
  #   - Sets `::treeWin` based on `.treeWin$::curr_db` existence.
  #   - Refreshes the ECO graph window if present.
  ################################################################################
  proc DatabaseChanged {} {
    set ::curr_db [sc_base current]
    ::windows::switcher::Refresh
    ::windows::stats::refresh_wnd
    ::maint::Refresh
    updateStatusBar
    ::tools::graphs::filter::Refresh
    ::tools::graphs::absfilter::Refresh
    set ::treeWin [winfo exists .treeWin$::curr_db]
    menuUpdateBases
    if {[winfo exists .ecograph]} { ::windows::eco::update }
  }

  ################################################################################
  # ::notify::DatabaseModified
  #   Notifies the UI that a database's contents were modified.
  # Visibility:
  #   Public.
  # Inputs:
  #   - dbase: Base slot number that was modified.
  # Returns:
  #   - None.
  # Side effects:
  #   - Refreshes menus, tree filter, gamelist, switcher, stats, maintenance, and graphs.
  #   - Notifies search UI via `::search::DatabaseModified`.
  #   - Refreshes the ECO graph window if present.
  ################################################################################
  proc DatabaseModified {dbase} {
    menuUpdateBases
    ::updateTreeFilter $dbase
    ::tree::dorefresh $dbase
    ::windows::gamelist::DatabaseModified $dbase
    ::windows::switcher::Refresh $dbase
    ::windows::stats::refresh_wnd
    ::maint::Refresh
    updateStatusBar
    ::search::DatabaseModified $dbase
    ::tools::graphs::filter::Refresh
    ::tools::graphs::absfilter::Refresh
    if {[winfo exists .ecograph]} { ::windows::eco::update }
  }

  ################################################################################
  # ::notify::filter
  #   Notifies the UI that a database filter has changed (typically due to searches).
  # Visibility:
  #   Public.
  # Inputs:
  #   - dbase: Base slot number whose filter changed.
  #   - filter: Filter name.
  # Returns:
  #   - None.
  # Side effects:
  #   - Generates `<<NotifyFilter>>` for windows and search panes.
  #   - Refreshes the tree and, for the main "dbfilter", refreshes stats/maintenance/graphs.
  #   - Refreshes the ECO graph window if present.
  ################################################################################
  proc filter {dbase filter} {
    # TODO: Avoid direct access to ::search::dbase_
    foreach wnd [concat [::win::getWindows] [array names ::search::dbase_]] {
      event generate $wnd <<NotifyFilter>> -when tail -data [list $dbase $filter]
    }
    # TODO: Update the old code to handle <<NotifyFilter>> events
    ::tree::dorefresh $dbase $filter
    if {$filter eq "dbfilter"} {
      ::windows::stats::refresh_wnd
      ::maint::Refresh
      ::tools::graphs::filter::Refresh
      ::tools::graphs::absfilter::Refresh
      if {[winfo exists .ecograph]} { ::windows::eco::update }
    }
  }

  ################################################################################
  # ::notify::EngineBestMove
  #   Notifies the UI that an engine's best-move evaluation has changed.
  # Visibility:
  #   Public.
  # Inputs:
  #   - engineID: Engine identifier.
  #   - bestmove: Best move string. When empty, indicates the engine is closed,
  #     disconnected, or locked.
  #   - evaluation: Engine evaluation payload (format depends on caller).
  # Returns:
  #   - None.
  # Side effects:
  #   - Updates the main evaluation bar via `::updateMainEvalBar`.
  ################################################################################
  proc EngineBestMove {engineID bestmove evaluation} {
    ::updateMainEvalBar $engineID $bestmove $evaluation
  }
}
