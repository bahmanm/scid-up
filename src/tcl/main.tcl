# Copyright (C) 1999-2004 Shane Hudson
# Copyright (C) 2006-2009 Pascal Georges
# Copyright (C) 2008-2011 Alexander Wagner
# Copyright (C) 2013-2016 Fulvio Benini
#
# This file is part of Scid (Shane's Chess Information Database).
#
# Scid is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.
#
# Scid is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Scid.  If not, see <http://www.gnu.org/licenses/>.

###
### main.tcl: Routines for creating and updating the main window.
###

############################################################
# Keyboard move entry:
#   Handles letters, digits and BackSpace/Delete keys.
#   Note that king- and queen-side castling moves are denoted
#   "OK" and "OQ" respectively.
#   The letters n, r, q, k, o and l are promoted to uppercase
#   automatically. A "b" can match to a b-pawn or Bishop move,
#   so in some rare cases, a capital B may be needed for the
#   Bishop move to distinguish it from the pawn move.

set moveEntry(Text) ""
set moveEntry(List) {}

################################################################################
# moveEntry_Clear
#   Clears the keyboard move-entry buffer.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Resets `moveEntry(Text)` and `moveEntry(List)`.
################################################################################
proc moveEntry_Clear {} {
    global moveEntry
    set moveEntry(Text) ""
    set moveEntry(List) {}
}

################################################################################
# moveEntry_Complete
#   Attempts to commit the currently selected keyboard-entered move.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - 0 when there is no matching candidate move.
#   - Otherwise, the result of `addSanMove`.
# Side effects:
#   - Clears the move-entry buffer via `moveEntry_Clear`.
#   - May mutate the current game by calling `addSanMove`.
################################################################################
proc moveEntry_Complete {} {
    lassign $::moveEntry(List) move
    if {$move eq ""} { return 0 }

    if {$move == "OK"} { set move "O-O" }
    if {$move == "OQ"} { set move "O-O-O" }
    moveEntry_Clear
    return [addSanMove [::untrans $move]]
}

################################################################################
# moveEntry_Backspace
#   Removes the last character from the keyboard move-entry buffer.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - The return value of `moveEntry_Char` (match count or move-commit result).
# Side effects:
#   - Updates `moveEntry(Text)` and recomputes `moveEntry(List)`.
#   - Updates UI status via `updateStatusBar` (through `moveEntry_Char`).
################################################################################
proc moveEntry_Backspace {} {
    global moveEntry
    set moveEntry(Text) [string range $moveEntry(Text) 0 \
            [expr {[string length $moveEntry(Text)] - 2}]]
    moveEntry_Char ""
}

################################################################################
# moveEntry_Char
#   Adds a character to the keyboard move-entry buffer and updates candidate
#   moves.
# Visibility:
#   Private.
# Inputs:
#   - ch: The character to append to `moveEntry(Text)`.
# Returns:
#   - (int) Number of matching candidates after filtering.
#   - Or, when a move is auto-committed, the return value of `moveEntry_Complete`.
# Side effects:
#   - Updates `moveEntry(Text)` and `moveEntry(List)`.
#   - Queries legal moves via `sc_pos moves`.
#   - May probe the null move via `sc_game SANtoUCI "--"`.
#   - Updates UI status via `updateStatusBar`.
#   - May commit a move to the game via `moveEntry_Complete`.
################################################################################
proc moveEntry_Char {ch} {
    global moveEntry
    set oldMoveText $moveEntry(Text)
    set oldMoveList $moveEntry(List)
    append moveEntry(Text) $ch
    set moveEntry(List) [lmap move [sc_pos moves $moveEntry(Coord)] {
        # Translate and remove any occurrence of "x", "=", "+", or "#"
        set move [string map [list "x" "" "=" "" "+" "" "#" ""] [::trans $move]]
        # Replace castling moves
        switch -- $move {
            "O-O" { set move "OK" }
            "O-O-O" { set move "OQ" }
        }
        # Add the move if it matches the prefix
        if {[string match -nocase "$moveEntry(Text)*" $move]} {
            # Add extra sub-elements for sorting the list
            set exact_prefix_len [strPrefixLen $moveEntry(Text) $move]
            list [expr {$exact_prefix_len * -1}] [string length $move] $move
        } else {
            continue
        }
    }]
    # Sort the moves list (and remove the extra sub-elements)
    set moveEntry(List) [lmap elem [lsort $moveEntry(List)] { lindex $elem 2 }]
    # Add the null move if it is valid
    if {$moveEntry(Text) in [list "-" "--"] && ![catch {sc_game SANtoUCI "--"}]} {
        lappend moveEntry(List) "--"
    }
    set len [llength $moveEntry(List)]
    lassign $moveEntry(List) move move2
    if {$len == 2 && [string equal -nocase $move $move2]} {
        # Check for the special case where the user has entered a b-pawn
        # capture that clashes with a Bishop move (e.g. bxc4 and Bxc4):
        set len 1
    }
    if {$len == 0} {
        # No matching moves, so do not accept this character as input:
        set moveEntry(Text) $oldMoveText
        set moveEntry(List) $oldMoveList
    } elseif {$len == 1} {
        # Exactly one matching move, so make it if AutoExpand is on,
        # or if it equals the move entered. Note the comparison is
        # case insensitive to allow for 'b' to match both pawn and
        # Bishop moves.
        if {$moveEntry(AutoExpand) || [string equal -nocase $moveEntry(Text) $move]} {
            return [moveEntry_Complete]
        }
    }
    updateStatusBar
    return $len
}

################################################################################
# updateMainGame
#   Refreshes main-window player metadata for the current game.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Updates `gamePlayers(nameW)`, `gamePlayers(nameB)`, `gamePlayers(eloW)`,
#     `gamePlayers(eloB)`, and clears the clock fields.
#   - Reads game metadata via `sc_game info`.
################################################################################
proc updateMainGame {} {
    global gamePlayers
    set gamePlayers(nameW)  [sc_game info white]
    set gamePlayers(nameB)  [sc_game info black]
    set eloW                [sc_game info welo]
    set gamePlayers(eloW)   [expr {$eloW == 0 ? "" : "($eloW)"}]
    set eloB                [sc_game info belo]
    set gamePlayers(eloB)   [expr {$eloB == 0 ? "" : "($eloB)"}]
    set gamePlayers(clockW) ""
    set gamePlayers(clockB) ""
    set gamePlayers(movetime) ""
}

################################################################################
# updateTitle
#   Updates the application window titles to reflect the current database/game.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Updates the root window title (`.`) and main window title (`.main`).
#   - Reads database metadata via `sc_base filename` / `sc_base numGames`.
#   - Reads game metadata via `sc_game info` and `sc_game altered`.
################################################################################
proc updateTitle {} {
    set title "[tr ScidUp] - "
    set fname [sc_base filename $::curr_db]
    set fname [file tail $fname]
    append title "$fname ($::tr(game) "
    append title "[::utils::thousands [sc_game number]] / "
    append title "[::utils::thousands [sc_base numGames $::curr_db]])"
    ::setTitle . $title
    set white [sc_game info white]
    set black [sc_game info black]
    if {[string length $white] > 2 &&  [string length $black] > 2} {
        if {$fname == {[clipbase]} } { set fname clipbase }
        set altered ""
        if {[sc_game altered]} { set altered "*" }
        ::setTitle .main "($fname$altered): $white -- $black"
    } else {
        ::setTitle .main $title
    }
}

################################################################################
# updateStatusBar
#   Updates the main status area (info text, evaluation bar, and context alerts).
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Updates `.main.board` info/alerts via `::board::setInfo*`.
#   - Updates `.main.board` evaluation bar via `::board::updateEvalBar`.
#   - Reads/updates `::gamePlayers(clockW)`, `::gamePlayers(clockB)`, and
#     `::gamePlayers(movetime)`.
#   - May set/unset `::guessedAddMove` and update `::gameLastMove`.
#   - Reads game/position state via `sc_pos` / `sc_game`.
################################################################################
proc updateStatusBar {} {
    if {! [winfo exists .main]} { return }

    if {$::menuHelpMessage != ""} {
        ::board::setInfoAlert .main.board "[tr Help]:" "$::menuHelpMessage" "black" ""
        return
    }

    if {$::autoplayMode == 1} {
        ::board::setInfoAlert .main.board "Autoplay:" [tr Stop] "red" "cancelAutoplay"
        return
    }

    if {[info exists ::interactionHandler]} {
        set pInfo [{*}$::interactionHandler info]
        if {[llength $pInfo] != 4} {
            ::board::setInfoAlert .main.board "Playing..." [tr Stop] "red" {{*}$::interactionHandler stop}
        } else {
            ::board::setInfoAlert .main.board {*}pInfo
        }
        return
    }

    # show [%clk] command (if we are not playing)
    set toMove  [sc_pos side]
    set comment [sc_pos getComment]
    ::board::updateEvalBar .main.board [getScorefromComment $comment 10]
    if { ![gameclock::isRunning] } {
        set ::gamePlayers(clockW) ""
        set ::gamePlayers(clockB) ""
        set ::gamePlayers(movetime) ""
        set clkExp {.*?\[%clk\s*(.*?)\s*\].*}
        lassign [sc_pos getPrevComment] prevCom movetime
        regexp $clkExp $comment -> ::gamePlayers(clockW)
        regexp $clkExp $prevCom -> ::gamePlayers(clockB)
        regexp $clkExp $movetime -> movetime
        set _mt [clock_to_seconds $movetime]
        set _cw [clock_to_seconds $::gamePlayers(clockW)]
        if {$_mt ne "" && $_cw ne ""} {
            set ::gamePlayers(movetime) [format_clock_from_seconds [expr {$_mt - $_cw}]]
        }
        if {$toMove == "white"} {
            set temp_swap $::gamePlayers(clockW)
            set ::gamePlayers(clockW) $::gamePlayers(clockB)
            set ::gamePlayers(clockB) $temp_swap
        }
        set ::gamePlayers(clockW) [format_clock $::gamePlayers(clockW)]
        set ::gamePlayers(clockB) [format_clock $::gamePlayers(clockB)]
    }

    if {[info exists ::guessedAddMove]} {
        set ::gameLastMove [lindex $::guessedAddMove 1]
        ::board::setInfoAlert .main.board [lindex $::guessedAddMove 0] "\[click to change\]" "DodgerBlue3" ".main.menuaddchoice"
        unset ::guessedAddMove
        return
    }

    global moveEntry
    if {$moveEntry(Text) != ""} {
        set msg "\[ $moveEntry(Text) \]  "
        foreach thisMove $moveEntry(List) {
            append msg "$thisMove "
        }
        ::board::setInfoAlert .main.board "Enter Move:" "$msg" "DodgerBlue3" ""
        return
    }

    # remove technical comments, notify only human readable ones
    regsub -all {\[%.*?\]} $comment {} comment

    set statusBar ""
    set move [sc_game info previousMoveNT]
    if {$move != ""} {
      regsub {K} $move "\u2654" move
      regsub {Q} $move "\u2655" move
      regsub {R} $move "\u2656" move
      regsub {B} $move "\u2657" move
      regsub {N} $move "\u2658" move
      set number "[sc_pos moveNumber]"
      if {$toMove == "white"} {
        incr number -1
        append number ".."
      }
      append statusBar [tr LastMove]
      if {[sc_var level] != 0} { append statusBar " (var)" }
      append statusBar ": $number.$move"
      set statusBar [list $statusBar {}]
      if {$::gamePlayers(movetime) ne ""} {
        lappend statusBar "    \u23F1 $::gamePlayers(movetime)" header
      }
      ::board::setInfo .main.board $statusBar
    } else {
      set msg "[sc_game info date] - [sc_game info event]"
      ::board::setInfoAlert .main.board "[tr Event]:" $msg "DodgerBlue3" "::crosstab::Open"
    }
    set eco [sc_game info ECO]
    ::board::addInfo .main.board $eco
    if {$comment != ""} {
        set headermsg ""
        # If this is the first move, or both movetime and eco are empty,
        # show only the comment.
        if {$move eq "" || ($::gamePlayers(movetime) eq "" && $eco eq "")} {
            set headermsg "[tr Comment]"
        }
        ::board::setInfoAlert .main.board $headermsg "$comment" "green" "::makeCommentWin"
    }
}

################################################################################
# updateMainToolbar
#   Updates main-board navigation/variation toolbar bindings for the current
#   position.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Configures `.main.board` toolbar button commands/images.
#   - Updates `::gameInfoBar(...)` command entries.
#   - Reads position state via `sc_pos isAt ...` and `sc_var level`.
################################################################################
proc updateMainToolbar {} {
  if {[sc_pos isAt start]} {
    ::board::setButtonCmd .main.board leavevar ""
    ::board::setButtonCmd .main.board back ""
    unset -nocomplain ::gameInfoBar(tb_BD_Start)
  } else {
    ::board::setButtonCmd .main.board leavevar [list ::move::ExitVarOrStart]
    ::board::setButtonCmd .main.board back [list ::move::Back]
    set ::gameInfoBar(tb_BD_Start) "::move::Start"
  }
  if {[sc_pos isAt end] || [sc_pos isAt vend]} {
    ::board::setButtonCmd .main.board forward ""
    ::board::setButtonCmd .main.board endvar ""
    unset -nocomplain ::gameInfoBar(tb_BD_End)
    unset -nocomplain ::gameInfoBar(tb_BD_Autoplay)
  } else {
    ::board::setButtonCmd .main.board forward [list ::move::Forward]
    ::board::setButtonCmd .main.board endvar [list ::move::EndVar]
    set ::gameInfoBar(tb_BD_End) "::move::End"
    set ::gameInfoBar(tb_BD_Autoplay) "startAutoplay"
  }

  if {[sc_var level] == 0} {
    unset -nocomplain ::gameInfoBar(tb_BD_VarDelete)
    unset -nocomplain ::gameInfoBar(tb_BD_VarPromote)
    unset -nocomplain ::gameInfoBar(tb_BD_VarLeave)
    unset -nocomplain ::gameInfoBar(tb_BD_BackToMainline)
    ::board::setButtonImg .main.board leavevar tb_BD_BackStart
  } else {
    set ::gameInfoBar(tb_BD_VarDelete) { ::pgn::deleteVar }
    set ::gameInfoBar(tb_BD_VarPromote) { ::pgn::mainVar }
    set ::gameInfoBar(tb_BD_VarLeave) { ::move::ExitVar }
    set ::gameInfoBar(tb_BD_BackToMainline) { while {[sc_var level] != 0} {::move::ExitVar} }
    ::board::setButtonImg .main.board leavevar tb_BD_exitvar
  }

  set ::gameInfoBar(tb_BD_SetupBoard) "setupBoard"
  set ::gameInfoBar(tb_BD_SelectMarker) "::selectMarker"
}

################################################################################
# ::updateTreeFilter
#   Updates position-dependent "tree" filters for windows that track the current
#   board position.
# Visibility:
#   Private.
# Inputs:
#   - base (int|string, optional): Database slot to prioritise (passed through to
#     the window discovery helpers).
# Returns:
#   - None.
# Side effects:
#   - Mutates `::treeFilterUpdating_` / `::treeFilterUpdatingBases_` for
#     cancellation and restart handling.
#   - Runs `sc_filter search <base> "tree" board` for affected bases.
#   - Updates progress UI via `progressBarSet` / `::progressBarCancel`.
#   - Notifies listeners via `::notify::filter <base> tree`.
#   - May schedule a restart via `after idle` if the position changes mid-update.
################################################################################
proc ::updateTreeFilter {{base ""}} {
    if { [info exists ::treeFilterUpdating_] } {
        set ::treeFilterUpdating_ {}
        ::progressBarCancel
        return
    }

    set ::treeFilterUpdating_ {}
    set ::treeFilterUpdatingBases_ [::windows::gamelist::listTreeBases $base]
    lappend ::treeFilterUpdatingBases_ {*}[::tree::listTreeBases $base]
    foreach elem [lsort -unique -index 0 $::treeFilterUpdatingBases_] {
        lassign $elem base filter progressbar

        set ::treeFilterUpdating_ [lsearch -all -inline -exact -index 0 $::treeFilterUpdatingBases_ $base]
        if { [llength $::treeFilterUpdating_] == 0 } {
            # canceled while updating another base
            continue
        }

        #TODO: don't do a full database search if there is only one filter.
        #set n_filters [llength [lsort -unique -index 1 $::treeFilterUpdating_]]

        progressBarSet {*}$progressbar
        set err [catch {sc_filter search $base "tree" board}]
        if {$err && $::errorCode != $::ERROR::UserCancel} {
            ERROR::MessageBox
        }
        if { [llength $::treeFilterUpdating_] == 0 } {
            # Restart if the position changed before the update finished.
            after idle {
                unset ::treeFilterUpdating_
                ::updateTreeFilter
            }
            return
        }
        ::notify::filter $base tree
    }
    unset ::treeFilterUpdating_
}

################################################################################
# ::cancelUpdateTreeFilter
#   Cancels (or narrows) an in-progress `::updateTreeFilter` run.
# Visibility:
#   Private.
# Inputs:
#   - progressbar: Progress-bar descriptor as stored in the update tracking list.
# Returns:
#   - None.
# Side effects:
#   - Mutates `::treeFilterUpdating_` / `::treeFilterUpdatingBases_` to remove the
#     cancelled target.
#   - May call `::progressBarCancel` when cancelling the last remaining update.
################################################################################
proc ::cancelUpdateTreeFilter {progressbar} {
    if {![info exists ::treeFilterUpdating_]} {
        return
    }
    set idx [lsearch -exact -index 2 $::treeFilterUpdating_ $progressbar]
    if {$idx != -1} {
        if {[llength $::treeFilterUpdating_] == 1} {
            ::progressBarCancel
        } else {
            set ::treeFilterUpdating_ [lreplace $::treeFilterUpdating_ $idx $idx]
        }
    } else {
        set idx [lsearch -exact -index 2 $::treeFilterUpdatingBases_ $progressbar]
        if {$idx != -1} {
            set ::treeFilterUpdatingBases_ [lreplace $::treeFilterUpdatingBases_ $idx $idx]
        }
    }
}

################################################################################
# ::updateMainEvalBar
#   Updates the main evaluation bar (and optional best-move arrow) from engine
#   output.
# Visibility:
#   Private.
# Inputs:
#   - engineID: Engine window/slot identifier reporting the evaluation.
#   - bestmove: Best move in SAN (possibly containing chess-piece glyphs).
#   - evaluation: Numeric evaluation value understood by `::board::updateEvalBar`.
# Returns:
#   - None.
# Side effects:
#   - Updates `.main.board` evaluation bar via `::board::updateEvalBar`.
#   - When enabled, draws the best-move arrow via `::board::mark::DrawBestMove`.
#   - Tracks the "owning" engine in `::mainEvalBarEngineID_`.
#   - May unset `::mainEvalBarEngineID_` when the engine clears its output.
################################################################################
proc ::updateMainEvalBar {engineID bestmove evaluation} {
    if {! $::showEvalBar(.main) || ![winfo exists .main.board]} { return }

    if {![info exists ::mainEvalBarEngineID_]} {
        set ::mainEvalBarEngineID_ $engineID
    }
    if {$engineID == $::mainEvalBarEngineID_} {
        ::board::updateEvalBar .main.board $evaluation
        if {$::showMainEvalBarArrow} {
            set bestmove [string map {"\u2654" K "\u2655" Q "\u2656" R "\u2657" B "\u2658" N} [::untrans $bestmove]]
            catch { sc_game SANtoUCI $bestmove } moveUCI
            ::board::mark::DrawBestMove .main.board $moveUCI
        }
        if {$bestmove eq "" && $evaluation eq ""} {
            unset ::mainEvalBarEngineID_
        }
    }
}

################################################################################
# ::createMainEvalBarMenu
#   Creates the evaluation-bar context menu for selecting/starting engines and
#   toggling evaluation features.
# Visibility:
#   Private.
# Inputs:
#   - w: Widget path of the evaluation bar/board.
# Returns:
#   - (string) Path of the created menu widget (`$w.evalbar_menu`).
# Side effects:
#   - Creates/destroys `$w.evalbar_menu`.
#   - May start/stop engines via `::enginewin::start` / `::enginewin::stop`.
#   - May update `::mainEvalBarEngineID_` and `::showMainEvalBarArrow`.
################################################################################
proc ::createMainEvalBarMenu {w} {
    if {[winfo exists $w.evalbar_menu]} { destroy $w.evalbar_menu }
    menu $w.evalbar_menu

    set engines {}
    set enginewins [enginewin::listEngines]
    foreach {elem} $enginewins {
        lassign $elem engID engName running
        if {!$running} {
            lappend engines [list $engID $engName]
            continue
        }
        if {[info exists ::mainEvalBarEngineID_] && $engID == $::mainEvalBarEngineID_} {
            set ::mainEvalBarCheckbutton 1
            $w.evalbar_menu add checkbutton -variable ::mainEvalBarCheckbutton -label $engName -command {
                ::enginewin::stop $::mainEvalBarEngineID_
            }
        } else {
            $w.evalbar_menu add command -label $engName \
                -command [list apply {{engID} { set ::mainEvalBarEngineID_ [::enginewin::start $engID] }} $engID]
        }
    }
    foreach {engName} [enginecfg::names] {
        if {[lsearch -exact -index 1 $enginewins $engName] == -1} {
            lappend engines [list "" $engName]
        }
    }
    $w.evalbar_menu add separator
    foreach {elem} $engines {
        lassign $elem engID engName
        $w.evalbar_menu add command -label $engName -command [list apply {{engID engName} {
            if {[info exists ::mainEvalBarEngineID_]} {
                ::enginewin::stop $::mainEvalBarEngineID_
            }
            set ::mainEvalBarEngineID_ [::enginewin::start $engID $engName]
        }} $engID $engName]
    }

    $w.evalbar_menu add command -label [tr NewLocalEngine] -command {
        set newEngName [::enginecfg::dlgNewLocal]
        if {$newEngName ne ""} {
            ::enginewin::start "" $newEngName
        }
    }
    $w.evalbar_menu add separator
    $w.evalbar_menu add checkbutton -variable ::showMainEvalBarArrow -label [tr BestMoveArrow] -command {
        ::board::mark::DrawBestMove ".main.board" ""
    }
    $w.evalbar_menu add separator
    $w.evalbar_menu add command -label [tr Hide] \
        -command { {*}$::gameInfoBar(tb_BD_Scorebar) }

    return $w.evalbar_menu
}

################################################################################
# toggleRotateBoard
#   Flips the main board orientation.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Updates `.main.board` orientation via `::board::flip`.
################################################################################
proc toggleRotateBoard {} {
    ::board::flip .main.board
}




############################################################
### The board:

################################################################################
# toggleShowMaterial
#   Toggles material display in the main game-info view.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Toggles material display via `::board::toggleMaterial`.
#   - Synchronises `::gameInfo(showMaterial)` with the new visibility state.
################################################################################
proc toggleShowMaterial { {boardPath .main.board} } {
    set ::gameInfo(showMaterial) [::board::toggleMaterial $boardPath]
}
################################################################################
# main_mousewheelHandler
#   Handles mouse-wheel navigation in the main window.
# Visibility:
#   Private.
# Inputs:
#   - direction: Signed scroll direction (negative for back, positive for forward).
# Returns:
#   - None.
# Side effects:
#   - Navigates the game via `::move::Back` or `::move::Forward`.
################################################################################
proc main_mousewheelHandler {direction} {
    if {$direction < 0} {
        ::move::Back
    } else {
        ::move::Forward
    }
}

################################################################################
# getNextMoves
#   Returns a short textual preview of upcoming main-line moves.
# Visibility:
#   Private.
# Inputs:
#   - num (int, optional): Maximum number of half-moves to include (default 4).
# Returns:
#   - (string) A space-prefixed string containing up to `num` moves.
# Side effects:
#   - Temporarily advances the game via `sc_move forward`, then restores the
#     original position via `sc_move back`.
################################################################################
proc getNextMoves { {num 4} } {
    set tmp ""
    set count 0
    while { [sc_game info nextMove] != "" && $count < $num} {
        append tmp " [sc_game info nextMove]"
        sc_move forward
        incr count
    }
    sc_move back $count
    return $tmp
}
################################################################################
# showVars
#   Displays a temporary variations chooser for quick selection via keyboard.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - No-op when `::autoplayMode == 1`, when there are no variations, or when the
#     `.variations` window already exists.
#   - Creates the `.variations` toplevel with a `ttk::treeview` list.
#   - Enters the selected variation via `::move::EnterVar`.
#   - Temporarily moves into/out of variations via `sc_var moveInto` / `sc_var exit`.
#   - Captures/restores focus and grab via `::tk::SetFocusGrab` /
#     `::tk::RestoreFocusGrab`.
################################################################################
proc showVars {} {
    if {$::autoplayMode == 1} { return }

    set numVars [sc_var count]
    # No need to display an empty menu
    if {$numVars == 0} { return }

    set w .variations
    if {[winfo exists $w]} { return }

    # Present a menu of the possible variations
    toplevel $w
    ::setTitle $w $::tr(Variations)
    setWinLocation $w
    set h [expr {$numVars + 1}]
    if { $h> 19} { set h 19 }
    ttk::treeview $w.lbVar -columns {0} -show {} -selectmode browse
    $w.lbVar configure -height $h
    $w.lbVar column 0 -width 250
    pack $w.lbVar -side left -fill both -expand 1

    #insert main line
    set move [sc_game info nextMove]
    set j 0
    if {$move == ""} {
        set move "($::tr(empty))"
    } else  {
        $w.lbVar insert {} end -id $j -values [list "0: [getNextMoves 5]"]
        incr j
    }

    # insert variations
    set varList [sc_var list]
    for {set i 0} {$i < $numVars} {incr i} {
        set move [::trans [lindex $varList $i]]
        if {$move == ""} {
            set move "($::tr(empty))"
        } else  {
            sc_var moveInto $i
            append move [getNextMoves 5]
            sc_var exit
        }
        set str "[expr {$i + 1}]: $move"
        $w.lbVar insert {} end -id $j -values [list "$str"]
        incr j
    }
    $w.lbVar focus 0
    $w.lbVar selection set 0

    bind $w <Configure> [list recordWinSize $w]
    bind $w <Escape> [list destroy $w]
    bind $w <Left> [list destroy $w]
    bind $w <Right> [list apply {{w} {
        ::move::EnterVar [${w}.lbVar selection]
        destroy $w
    } ::} $w]
    bind $w <Return> [list event generate $w <Right>]
    bind $w <ButtonRelease-1> [list event generate $w <Right>]

    tkwait visibility $w
    ::tk::SetFocusGrab $w $w.lbVar
    tkwait window $w
    ::tk::RestoreFocusGrab $w $w.lbVar
}
################################################################################
# updateBoard
#   Notifies listeners that the current position has changed.
# Visibility:
#   Public.
# Inputs:
#   - args: Optional flags forwarded to `::notify::PosChanged` (e.g. `-pgn`,
#     `-animate`).
# Returns:
#   - None.
# Side effects:
#   - Triggers UI refresh via `::notify::PosChanged`.
################################################################################
proc updateBoard {args} {
    ::notify::PosChanged {*}$args
}


################################################################################
# updateGameInfo
#   Regenerates the main-window game-info panel content.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Replaces `.main.gameInfo.text` contents and toggles wrapping/tagging.
#   - Renders the game info text via `::htext::display` and `sc_game info`.
#   - Updates player photos via `togglePhotosSize 0`.
################################################################################
proc updateGameInfo {} {
    global gameInfo

    .main.gameInfo.text configure -state normal
    .main.gameInfo.text delete 0.0 end
    ::htext::display .main.gameInfo.text [sc_game info -hide $gameInfo(hideNextMove) \
            -material $gameInfo(showMaterial) \
            -cfull $gameInfo(fullComment) \
            -fen $gameInfo(showFEN)]
    if {$gameInfo(wrap)} {
        .main.gameInfo.text configure -wrap word
        .main.gameInfo.text tag configure wrap -lmargin2 10
        .main.gameInfo.text tag add wrap 1.0 end
    } else {
        .main.gameInfo.text configure -wrap none
    }
    .main.gameInfo.text configure -state disabled
    togglePhotosSize 0
}

set photosMinimized 0
################################################################################
# togglePhotosSize
#   Toggles whether the player photos are shown minimised or full-height.
# Visibility:
#   Private.
# Inputs:
#   - toggle (bool/int, optional): When true, flips `::photosMinimized`.
# Returns:
#   - None.
# Side effects:
#   - Places/unplaces `.main.photoW` / `.main.photoB` relative to
#     `.main.gameInfo.text`.
#   - Updates photo image data via `updatePlayerPhotos`.
#   - Mutates `::photosMinimized`.
################################################################################
proc togglePhotosSize {{toggle 1}} {
    place forget .main.photoW
    place forget .main.photoB
    if {! $::gameInfo(photos)} { return }

    updatePlayerPhotos
    if {$toggle} { set ::photosMinimized [expr {!$::photosMinimized}] }

    set distance [expr {[image width photoB] + 2}]
    if { $distance < 10 } { set distance 82 }

    if {$::photosMinimized} {
        place .main.photoW -in .main.gameInfo.text -x -17 -relx 1.0 -relheight 0.15 -width 15 -anchor ne
        place .main.photoB -in .main.gameInfo.text -x -1 -relx 1.0  -relheight 0.15 -width 15 -anchor ne
    } else  {
        place .main.photoW -in .main.gameInfo.text -x -$distance -relx 1.0 -relheight 1 -width [image width photoW] -anchor ne
        place .main.photoB -in .main.gameInfo.text -x -1 -relx 1.0 -relheight 1 -width [image width photoB] -anchor ne
    }
}


################################################################################
# readPhotoFile
#   Indexes a Scid photo file (`.spf`) and optionally generates/uses its `.spi`
#   index.
# Visibility:
#   Private.
# Inputs:
#   - fname: Path to a `.spf` file.
# Returns:
#   - (int) Number of photos indexed from the file.
# Side effects:
#   - Populates `::unsafe::photobegin(*)`, `::unsafe::photosize(*)`, and
#     `::unsafe::spffile(*)`.
#   - May `safeSource` an existing `.spi` file.
#   - May write a new `.spi` file when permissions allow.
#   - Emits startup progress via `::splash::add`.
################################################################################
proc readPhotoFile {fname} {
    set count 0
    set writespi 0

    if {! [regsub {\.spf$} $fname {.spi} spi]} {
        # How does it happend?
        return
    }

    # If SPI file was found then just source it and exit
    if { [file readable $spi]} {
        set count [array size ::unsafe::spffile]
        safeSource $spi fname $fname
        set newcount [array size ::unsafe::spffile]
        if {[expr {$newcount - $count}] > 0} {
            ::splash::add "Found [expr {$newcount - $count}] player photos in [file tail $fname]"
            ::splash::add "Loading information from index file [file tail $spi]"
            return [expr {$newcount - $count}]
        } else {
            set count 0
        }
    }

    # Check for the absence of the SPI file and check for the write permissions
    if { ![file exists $spi] && ![catch {open $spi w} fd_spi]} {
        # SPI file will be written to disk by scid
        set writespi 1
    }

    if {! [file readable $fname]} { return }

    set fd [open $fname]
    while {[gets $fd line] >= 0} {
        # search for the string      photo "Player Name"
        if { [regexp {^photo \"(.*)\" \{$} $line -> name] } {
            set count [expr {$count + 1 }]
            set begin [tell $fd]
            # skip data block
            while {1} {
                set end [tell $fd]
                gets $fd line
                if {[regexp {.*\}.*} $line ]} {break}
            }
            set trimname [trimString $name]
            set size [expr {$end - $begin }]
            set ::unsafe::photobegin($trimname) $begin
            set ::unsafe::photosize($trimname) $size
            set ::unsafe::spffile($trimname) $fname
            if { $writespi } {
                # writing SPI file to disk
                puts $fd_spi "set \"photobegin($trimname)\" $begin"
                puts $fd_spi "set \"photosize($trimname)\" $size"
                puts $fd_spi "set \"spffile($trimname)\" \"\$fname\""
            }
        }
    }
    if {$count > 0 && $writespi} {
        ::splash::add "Found $count player photos in [file tail $fname]"
        ::splash::add "Index file [file tail $spi] was generated succesfully"
    }
    if {$count > 0 && !$writespi} {
        ::splash::add "Found $count player photos in [file tail $fname]"
        ::splash::add "Could not generate index file [file tail $spi]"
        ::splash::add "Use spf2spi script to generate [file tail $spi] file "
    }

    if { $writespi } { close $fd_spi }
    close $fd
    return $count
}


################################################################################
# trimString
# Visibility:
#   Private.
# Inputs:
#   - data: String to normalise.
# Returns:
#   - (string) Lowercased string with the first two spaces removed.
# Side effects:
#   - None.
################################################################################
proc trimString {data} {
    set data [string tolower $data]
    set strindex [string first "\ " $data]
    set data [string replace $data $strindex $strindex]
    set strindex [string first "\ " $data]
    set data [string replace $data $strindex $strindex]
    return $data
}


################################################################################
# getphoto
#   Retrieves raw photo data for a player from an indexed `.spf` file.
# Visibility:
#   Public.
# Inputs:
#   - name: Normalised key used in `::unsafe::spffile(*)`.
# Returns:
#   - (string) Photo data block (may be empty when not found).
# Side effects:
#   - Reads from disk using offsets stored in `::unsafe::photobegin(*)` and
#     `::unsafe::photosize(*)`.
################################################################################
proc getphoto {name} {
    set data ""
    if {[info exists ::unsafe::spffile($name)]} {
        set fd [open $::unsafe::spffile($name)]
        seek $fd $::unsafe::photobegin($name) start
        set data [read $fd $::unsafe::photosize($name) ]
        close $fd
    }
    return $data
}


################################################################################
# loadPlayersPhoto
#   Initialises player-photo images and indexes available `.spf` photo files.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - (list) `{nImages nFiles}` for indexed photo entries and `.spf` files.
# Side effects:
#   - Creates Tk images `photoW` and `photoB`.
#   - Clears `::gamePlayers(photoW)` / `::gamePlayers(photoB)`.
#   - Scans `::scidDataDir`, `::scidUserDir`, `::scidConfigDir`, and
#     `[file join $::scidShareDir "photos"]` (and `::scidPhotoDir` when set).
#   - Populates photo index arrays via `readPhotoFile`.
################################################################################
proc loadPlayersPhoto {} {
  set ::gamePlayers(photoW) {}
  set ::gamePlayers(photoB) {}
  image create photo photoW
  image create photo photoB

  # Directories where Scid searches for the photo files
  set photodirs [list $::scidDataDir $::scidUserDir $::scidConfigDir [file join $::scidShareDir "photos"]]
  if {[info exists ::scidPhotoDir]} { lappend photodirs $::scidPhotoDir }

  # Read all Scid photo (*.spf) files in the Scid data/user/config directories:
  set nImg 0
  set nFiles 0
  foreach dir $photodirs {
      foreach photofile [glob -nocomplain -directory $dir "*.spf"] {
          set n [readPhotoFile $photofile]
          if {$n > 0} {
              incr nFiles
              incr nImg $n
          }
      }
  }

  return [list $nImg $nFiles]
}
loadPlayersPhoto

################################################################################
# normalizePlayerName
#   Normalises a player/engine name for photo lookup.
# Visibility:
#   Public.
# Inputs:
#   - engine: Raw player or engine name.
# Returns:
#   - (list) `{normalisedName spelledName}`.
# Side effects:
#   - May consult name spelling via `sc_name retrievename`.
#   - May consult `::unsafe::spffile(*)` to shorten engine-style names.
################################################################################
proc normalizePlayerName { engine } {
    set spelled $engine
    catch {
        set spell_name [sc_name retrievename $engine]
        if {$spell_name != ""} {
            set engine $spell_name
            set spelled $spell_name
        }
    }
    set engine [string tolower $engine]

    if { [string first "deep " $engine] == 0 } {
        # strip "deep "
        set engine [string range $engine 5 end]
    }
    # delete two first blank to make "The King" same as "TheKing"
    # or "Green Light Chess" as "Greenlightchess"
    set strindex [string first "\ " $engine]
    set engine [string replace $engine $strindex $strindex]
    set strindex [string first "\ " $engine]
    set engine [string replace $engine $strindex $strindex]
    set strindex [string first "," $engine]
    set slen [string len $engine]
    if { $strindex == -1 && $slen > 2 } {
        #seems to be a engine name:
        # search until longest name matches an engine name
        set slen [string len $engine]
        for { set strindex $slen} {![info exists ::unsafe::spffile([string range $engine 0 $strindex])]\
                    && $strindex > 2 } {set strindex [expr {$strindex - 1}] } { }
        set engine [string range $engine 0 $strindex]
    }
    return [list $engine $spelled]
}


################################################################################
# updatePlayerPhotos
#   Updates `photoW` and `photoB` image contents for the current game's players.
# Visibility:
#   Public.
# Inputs:
#   - force: Reserved for future use (currently unused).
# Returns:
#   - None.
# Side effects:
#   - Mutates `::gamePlayers(photoW)` / `::gamePlayers(photoB)` as the "last
#     rendered" names.
#   - Recreates `photoW` / `photoB` image data via `image create photo ... -data`.
################################################################################
proc updatePlayerPhotos {{force ""}} {
    foreach {name img} {nameW photoW nameB photoB} {
        set spellname $::gamePlayers($name)
        if {$::gamePlayers($img) != $spellname} {
            set ::gamePlayers($img) $spellname
            lassign [normalizePlayerName $spellname] spellname
            image create photo $img -data [getphoto $spellname]
        }
    }
}

#########################################################
### Chess move input

# Globals for mouse-based move input:

set selectedSq -1
set bestSq -1

set EMPTY 0
set KING 1
set QUEEN 2
set ROOK 3
set BISHOP 4
set KNIGHT 5
set PAWN 6

################################################################################
# getPromoPiece
#   Prompts the user to select a promotion piece.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - (int) Piece selector: 2=queen, 3=rook, 4=bishop, 5=knight.
# Side effects:
#   - Creates and destroys `.promoWin`.
#   - Temporarily grabs focus via `grab` / `tkwait window`.
#   - Uses global `::result` to communicate selection.
################################################################################
proc getPromoPiece {} {
    set w .promoWin
    set ::result 2
    toplevel $w
    # wm transient $w .main
    ::setTitle $w [tr ScidUp]
    wm resizable $w 0 0
    set col "w"
    if { [sc_pos side] == "black" } { set col "b" }
    ttk::button $w.bq -image ${col}q45 -command [list apply {{w result} { set ::result $result; destroy $w }} $w 2]
    ttk::button $w.br -image ${col}r45 -command [list apply {{w result} { set ::result $result; destroy $w }} $w 3]
    ttk::button $w.bb -image ${col}b45 -command [list apply {{w result} { set ::result $result; destroy $w }} $w 4]
    ttk::button $w.bn -image ${col}n45 -command [list apply {{w result} { set ::result $result; destroy $w }} $w 5]
    pack $w.bq $w.br $w.bb $w.bn -side left
    bind $w <Escape> [list apply {{w} { set ::result 2; destroy $w } ::} $w]
    bind $w <Return> [list apply {{w} { set ::result 2; destroy $w } ::} $w]
    update
    catch { grab $w }
    tkwait window $w
    return $::result
}

################################################################################
# confirmReplaceMove
#   Prompts for how to handle adding a move when a move already exists (unless
#   the review window is open).
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - "replace" to replace/truncate the existing continuation.
#   - "mainline" to create a new main line.
#   - "var" to add the move as a new variation.
#   - "cancel" to abort.
# Side effects:
#   - Returns `"var"` without prompting when `::reviewgame::window` exists.
#   - Otherwise shows a modal `tk_dialog`.
#   - Temporarily adjusts `*Dialog.msg.wrapLength` option.
################################################################################
proc confirmReplaceMove {} {
    if {[winfo exists $::reviewgame::window]} {
        return "var"
    }

    option add *Dialog.msg.wrapLength 4i interactive
    catch {tk_dialog .dialog "[tr ScidUp]: $::tr(ReplaceMove)?" \
                $::tr(ReplaceMoveMessage) "" 0 \
                $::tr(ReplaceMove) $::tr(NewMainLine) \
                $::tr(AddNewVar) $::tr(Cancel)} answer
    option add *Dialog.msg.wrapLength 3i interactive
    if {$answer == 0} { return "replace" }
    if {$answer == 1} { return "mainline" }
    if {$answer == 2} { return "var" }
    return "cancel"
}

################################################################################
# addMoveEx
#   Adds a move to the current game, optionally creating a new line/variation.
# Visibility:
#   Private.
# Inputs:
#   - move: Move in SAN or UCI notation.
#   - action (string, optional): How to handle existing continuations
#     (`replace`, `mainline`, `var`). Defaults to `var`.
# Returns:
#   - 1 on success.
#   - 0 on failure.
# Side effects:
#   - Records undo state via `undoFeature save`.
#   - May create/promote variations via `sc_var create` / `sc_var promote`.
#   - Mutates the game via `sc_move addSan`.
#   - On error, reverts via `undoFeature undo`.
#   - Triggers UI refresh via `::notify::PosChanged -pgn -animate`.
################################################################################
proc addMoveEx {{move} {action "var"}} {
    undoFeature save
    if {[catch {
        if {![sc_pos isAt vend]} {
            switch -- $action {
                mainline { sc_var create; set ::guessedAddMove [list "New Main Line"]}
                var      { sc_var create; set ::guessedAddMove [list "New Variation"]}
                replace  { set ::guessedAddMove [list "Replaced Main Line"]}
            }
            lappend ::guessedAddMove $move
        }

        sc_move addSan $move

        if {$action == "mainline"} {
            sc_var promote
            sc_move forward 1
        }
    }]} {
        # On error:
        undoFeature undo
        return 0
    }

    ::notify::PosChanged -pgn -animate
    return 1
}

################################################################################
# addMove
#   Adds a move to the current game using board-square indices.
# Visibility:
#   Public.
# Inputs:
#   - sq1: Source square index.
#   - sq2: Destination square index.
#   - animate (string, optional): Animation flag forwarded to `addMoveUCI`.
# Returns:
#   - 1 on success.
#   - 0 on failure.
# Side effects:
#   - May mutate the current game via `addMoveUCI`.
################################################################################
proc addMove { sq1 sq2 {animate "-animate"}} {
    set moveUCI [::board::san $sq2][::board::san $sq1]
    return [addMoveUCI $moveUCI $animate]
}

################################################################################
# addSanMove
#   Adds a SAN move to the current game.
# Visibility:
#   Public.
# Inputs:
#   - san: SAN move string.
# Returns:
#   - 1 on success.
#   - 0 on failure.
# Side effects:
#   - Converts SAN to UCI via `sc_game SANtoUCI`.
#   - May mutate the current game via `addMoveUCI`.
################################################################################
proc addSanMove { {san} } {
    if {[catch {sc_game SANtoUCI $san} moveUCI]} {
        return 0
    }
    return [addMoveUCI $moveUCI]
}

################################################################################
# addMoveUCI
#   Adds a UCI move to the current game (handling promotions and null moves).
# Visibility:
#   Public.
# Inputs:
#   - moveUCI: UCI move string (e.g. "e2e4", "e7e8q", "0000").
#   - animate (string, optional): Animation flag forwarded to UI refresh.
# Returns:
#   - 1 on success.
#   - 0 on failure.
# Side effects:
#   - May prompt for promotion via `getPromoPiece`.
#   - May consult `::interactionHandler` to block moves.
#   - May follow an existing continuation via `::move::Follow`.
#   - Otherwise may add a move/variation via `addMoveEx`.
#   - May send the move to external hardware via `::novag::addMove`.
#   - Schedules a sound announcement via `after idle`.
################################################################################
proc addMoveUCI {{moveUCI} {animate "-animate"}} {
    set sq1 [::board::sq [string range $moveUCI 0 1] ]
    set sq2 [::board::sq [string range $moveUCI 2 3] ]

    if { [string length $moveUCI] == 4 && $sq1 != $sq2 && [sc_pos isPromotion $sq1 $sq2] } {
        switch -- [getPromoPiece] {
            2 { set promoLetter "q"}
            3 { set promoLetter "r"}
            4 { set promoLetter "b"}
            5 { set promoLetter "n"}
            default {set promoLetter ""}
        }
        append moveUCI $promoLetter
    } else {
        # If it is King takes king then treat it as entering a null move:
        set board [sc_pos board]
        set k1 [string tolower [string index $board $sq1]]
        set k2 [string tolower [string index $board $sq2]]
        if {$moveUCI eq "0000" || ($k1 == "k"  &&  $k2 == "k")} { set moveUCI "null" }
    }

    if {[info exists ::interactionHandler] && [{*}$::interactionHandler premove $moveUCI]} { return 0 } ;# not player's turn

    if {! [::move::Follow $moveUCI] && ! [addMoveEx $moveUCI]} {
        return 0
    }

    if {$::novag::connected} {
        ::novag::addMove "$moveUCI"
    }

    set san [sc_game info previous]
    after idle [list ::utils::sound::AnnounceNewMove $san]

    return 1
}

################################################################################
# suggestMove
#   Determines whether the UI should suggest a move for the current square.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - 1 when suggestion logic should run.
#   - 0 when suggestions are disabled.
# Side effects:
#   - May consult `::interactionHandler`.
################################################################################
proc suggestMove {} {
    if {! $::suggestMoves} { return 0}
    if {[info exists ::interactionHandler]} {
        return [{*}$::interactionHandler suggestMove]
    }
    return 1
}

################################################################################
# enterSquare
#   Highlights a suggested move when the pointer enters a square.
# Visibility:
#   Private.
# Inputs:
#   - square: Board square index under the pointer.
# Returns:
#   - None.
# Side effects:
#   - Updates `bestSq`.
#   - May query `sc_pos bestSquare`.
#   - Colours squares on `.main.board` via `::board::colorSquare`.
################################################################################
proc enterSquare { square } {
    global bestSq bestcolor selectedSq
    if {$selectedSq == -1} {
        set bestSq -1
        if {[::suggestMove]} {
            set bestSq [sc_pos bestSquare $square]
            if {$bestSq != -1} {
                ::board::colorSquare .main.board $square $bestcolor
                ::board::colorSquare .main.board $bestSq $bestcolor
            }
        }
    }
}

################################################################################
# leaveSquare
#   Clears any suggestion highlight when the pointer leaves a square.
# Visibility:
#   Private.
# Inputs:
#   - square: Board square index under the pointer.
# Returns:
#   - None.
# Side effects:
#   - Restores default colouring via `::board::colorSquare`.
################################################################################
proc leaveSquare { square } {
    global selectedSq bestSq
    if {$selectedSq == -1} {
        ::board::colorSquare .main.board $bestSq
        ::board::colorSquare .main.board $square
    }
}

################################################################################
# pressSquare
#   Handles left-click on a square (selection or completing a two-click move).
# Visibility:
#   Private.
# Inputs:
#   - square: Board square index clicked.
# Returns:
#   - None.
# Side effects:
#   - Updates `selectedSq` and colours squares via `::board::colorSquare`.
#   - May start dragging via `::board::setDragSquare`.
#   - May commit a move via `addMove`.
################################################################################
proc pressSquare { square } {
    global selectedSq highcolor

    if {$selectedSq == -1} {
        set selectedSq $square
        ::board::colorSquare .main.board $square $highcolor
        # Drag this piece if it is the same color as the side to move:
        set c [string index [sc_pos side] 0]  ;# will be "w" or "b"
        set p [string index [::board::piece .main.board $square] 0] ;# "w", "b" or "e"
        if {$c == $p} {
            ::board::setDragSquare .main.board $square
        }
    } else {
        ::board::setDragSquare .main.board -1
        ::board::colorSquare .main.board $selectedSq
        ::board::colorSquare .main.board $square
        set tmp $selectedSq
        set selectedSq -1
        if {$square != $tmp} {
            addMove $square $tmp
        }
        enterSquare $square
    }
}

################################################################################
# releaseSquare
#   Handles mouse-button release and finalises drag moves on the main board.
# Visibility:
#   Private.
# Inputs:
#   - w: Board widget path.
#   - x: Pointer x coordinate.
#   - y: Pointer y coordinate.
# Returns:
#   - None.
# Side effects:
#   - Clears drag state via `::board::setDragSquare`.
#   - May commit a move via `addMove`.
#   - Updates `selectedSq` and square colouring via `::board::colorSquare`.
################################################################################
proc releaseSquare { w x y } {
    global selectedSq bestSq

    ::board::setDragSquare $w -1
    set square [::board::getSquare $w $x $y]
    if {$square < 0} {
        set selectedSq -1
        return
    }

    if {$square == $selectedSq} {
        if {[::suggestMove]} {
            # User pressed and released on same square, so make the
            # suggested move if there is one:
            set selectedSq -1
            ::board::colorSquare $w $bestSq
            ::board::colorSquare $w $square
            addMove $square $bestSq
            enterSquare $square
        } else {
            # Current square is the square user pressed the button on,
            # so we do nothing.
        }
    } elseif {$selectedSq != -1} {
        # User has dragged to another square, so try to add this as a move:
        set tmp $selectedSq
        set selectedSq -1
        addMove $square $tmp ""
        ::board::colorSquare $w $square
        ::board::colorSquare $w $tmp
    }
}

################################################################################
# addMarker
#   Adds or removes square markers/arrows for the current position.
# Visibility:
#   Private.
# Inputs:
#   - w: Board widget path.
#   - x: Pointer x coordinate.
#   - y: Pointer y coordinate.
# Returns:
#   - None.
# Side effects:
#   - Uses `::markStartSq` to track the first click for arrow creation.
#   - Updates the current position comment via `sc_pos setComment`.
#   - Triggers a PGN-only refresh via `::notify::PosChanged pgnonly`.
################################################################################
proc addMarker {w x y} {
    set sq [::board::getSquare $w $x $y]
    if {! [info exists ::markStartSq]} {
        set ::markStartSq [::board::san $sq]
        return
    }

    set from $::markStartSq
    unset ::markStartSq
    set to [::board::san $sq]
    if {$from == "" || $to == ""} { return }

    if {$from == $to } {
        set cmd "$::markType,$to,$::markColor"
        set cmd_erase "\[a-z\]*,$to,\[a-z\]*"
    } else {
        set cmd "arrow,$from,$to,$::markColor"
        set cmd_erase "arrow,$from,$to,\[a-z\]*"
    }
    set oldComment [sc_pos getComment]
    regsub -all " *\\\[%draw $cmd\\\]" $oldComment "" newComment
    if {$newComment == $oldComment} {
        regsub -all " *\\\[%draw $cmd_erase\\\]" $oldComment "" newComment
        append newComment " \[%draw $cmd\]"
    }

    sc_pos setComment $newComment
    ::notify::PosChanged pgnonly
}

################################################################################
# selectMarker
#   Opens a small popup to choose marker type and colour for annotations.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Creates the `.mainSelectMarker` toplevel.
#   - Updates `::markType` and `::markColor` via radio-button selection.
################################################################################
proc selectMarker {} {
    set w_ .mainSelectMarker
    toplevel $w_
    if {! $::macOS } {
        wm attributes $w_ -topmost 1
    } else {
        # On macOS, TK 8.6.16, the mouse events are weird.
        # Right-clicks are sent to this window, even if they happens outside.
        # With "wm overrideredirect $w_ 1" the <Leave> message is not sent.
        bind $w_ <Leave> {
            if {[string last . %W] == 0 &&
                [string first %W [winfo containing %X %Y]] != 0} {
                destroy %W
            }
        }
    }
    lassign [winfo pointerxy .] x y
    set x [expr {max(0, $x - 20)}]
    set y [expr {max(0, $y - 40)}]
    wm geometry $w_ "+$x+$y"

    ttk::frame $w_.markers
    set i 0
    foreach {marker lbl} {
        full █
        circle ◯
        disk ⬤
        + +
        - -
        X X
        ! !
        ? ?
        = =
        A A
        B B
        C C
        D D
        E E
        F F
        0 0
        1 1
        2 2
        3 3
        4 4
        5 5
        6 6
        7 7
        8 8
        9 9
    } {
        radiobutton $w_.markers.mark_$marker \
            -indicatoron "false" \
            -foreground "$::markColor" -background "light gray" -selectcolor "dark gray" \
            -text "$lbl" -width 2 \
            -variable "::markType" -value "$marker"
        grid $w_.markers.mark_$marker -row [expr {$i % 5}] -column [expr {int($i / 5)}]
        incr i
    }
    ttk::frame $w_.colors
    set i 0
    foreach color {
        green
        red
        orange
        yellow
        blue
        darkBlue
        purple
        white
        black
        gray
    } {
        radiobutton $w_.colors.col_$color \
            -indicatoron "false" \
            -background "$color" -selectcolor "$color" \
            -text " " -width 2 \
            -variable "::markColor" -value "$color" \
            -command [list apply {{btns} {
                foreach b $btns { $b configure -foreground $::markColor }
            }} [winfo children $w_.markers] ]
        grid $w_.colors.col_$color -row [expr {$i / 2}] -column [expr {int($i % 2)}]
        incr i
    }
    grid $w_.colors $w_.markers -sticky nsew -pady 12 -padx 12
}

################################################################################
# addNag
#   Adds a NAG (Numeric Annotation Glyph) at the current position.
# Visibility:
#   Public.
# Inputs:
#   - nag: NAG integer/string to add.
# Returns:
#   - None.
# Side effects:
#   - Records undo state via `undoFeature save`.
#   - Updates the position via `sc_pos addNag`.
#   - Triggers a PGN-only refresh via `::notify::PosChanged pgnonly`.
################################################################################
proc addNag {nag} {
    undoFeature save
    sc_pos addNag "$nag"
    ::notify::PosChanged pgnonly
}

################################################################################
# undoFeature
#   Executes a game undo/redo operation and refreshes the UI when needed.
# Visibility:
#   Public.
# Inputs:
#   - action: One of `save`, `undo`, `redo`, or `undoAll`.
# Returns:
#   - None.
# Side effects:
#   - Updates the undo stack via `sc_game undoPoint`.
#   - Performs undo/redo via `sc_game undo` / `sc_game redo` / `sc_game undoAll`.
#   - Notifies UI via `notify::GameChanged` for actions that change state.
################################################################################
proc undoFeature {action} {
    if {$action == "save"} {
        sc_game undoPoint
    } elseif {$action == "undo"} {
        sc_game undo
        notify::GameChanged
    } elseif {$action == "redo"} {
        sc_game redo
        notify::GameChanged
    } elseif {$action == "undoAll"} {
        sc_game undoAll
        notify::GameChanged
    }
}

################################################################################
# setInteractionHandler
#   Installs (or clears) the global interaction-handler command prefix.
# Visibility:
#   Public.
# Inputs:
#   - callback: Command prefix (Tcl list) invoked as `{*}$::interactionHandler <subcmd> ...`.
#     Use an empty string to clear the handler. The handler is expected to support
#     subcommands such as `info`, `stop`, `premove`, `suggestMove`, and `move*` veto
#     checks.
# Returns:
#   - None.
# Side effects:
#   - Sets/unsets `::interactionHandler`.
#   - Triggers UI refresh via `::notify::PosChanged`.
################################################################################
proc setInteractionHandler { callback } {
    if {$callback eq ""} {
        unset -nocomplain ::interactionHandler
    } else {
        # Canonicalise the command prefix as a proper list for safe `{*}` dispatch.
        set ::interactionHandler [list {*}$callback]
    }
    ::notify::PosChanged
}

################################################################################
# resizeMainBoard
#   Resizes the main board to fit the available docked-window space.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - When `::autoResizeBoard` is enabled, updates `::boardSize` by calling
#     `::board::resizeAuto`.
#   - Reads widget geometry via `winfo` and forces layout via `update idletasks`.
################################################################################
proc resizeMainBoard {} {
  if { $::autoResizeBoard } {
    update idletasks
    set availw [winfo width .main]
    set availh [winfo height .main]
    if {$::showGameInfo} {
      set gameInfoH [winfo height .main.gameInfo]
      set availh [expr {$availh - $gameInfoH}]
    }
    if { [llength [pack slaves .main.tb]] != 0 } {
      set tbH [winfo height .main.tb]
      set availh [expr {$availh - $tbH}]
    }
    set ::boardSize [::board::resizeAuto .main.board "0 0 $availw $availh"]
  }
}
################################################################################
# toggleGameInfo
#   Shows or hides the main game-info panel.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Grids or ungrids `.main.gameInfo` based on `::showGameInfo`.
#   - Regenerates content via `updateGameInfo`.
################################################################################
proc toggleGameInfo {} {
  if {$::showGameInfo} {
    grid .main.gameInfo -row 3 -column 0 -sticky news
  } else  {
    grid forget .main.gameInfo
  }
  updateGameInfo
}
################################################################################
# CreateMainBoard
#   Creates and wires the main board UI (board widget, toolbars, bindings).
# Visibility:
#   Public.
# Inputs:
#   - w: Main window path (typically `.main`).
# Returns:
#   - None.
# Side effects:
#   - Creates UI widgets under `$w` (board, toolbars, menus, and game-info panel).
#   - Registers options via `::options.store`.
#   - Binds keyboard and mouse interactions for move entry and markers.
#   - Performs initial refresh via `updateMainGame`, `updateStatusBar`,
#     `updateMainToolbar`, and `updateTitle`.
################################################################################
proc CreateMainBoard { {w} } {
  ::win::createWindow $w [ ::tr "Board" ]

  CreateGameInfo

  ::board::new $w.board $::boardSize
  ::board::showMarks $w.board $::gameInfo(showMarks)
  ::board::coords $w.board $::boardCoords
  ::board::bindEvalBar $w.board <ButtonRelease> "
    tk_popup \[::createMainEvalBarMenu $w.board \] %X %Y
  "
  ::options.store ::showEvalBar($w) 1
  ::options.store ::showMainEvalBarArrow 1
  if {$::showEvalBar($w)} { ::board::toggleEvalBar $w.board }
  if {$::gameInfo(showMaterial)} { ::board::toggleMaterial $w.board }

  ::board::addNamesBar $w.board gamePlayers
  ::board::addInfoBar $w.board gameInfoBar

  set ::gameInfoBar(tb_BD_Material) [list ::toggleShowMaterial $w.board]
  set ::gameInfoBar(tb_BD_Scorebar) [list apply {{w} {
    set ::showEvalBar($w) [::board::toggleEvalBar $w.board]
    unset -nocomplain ::mainEvalBarEngineID_
    ::board::updateEvalBar .main.board ""
    ::board::mark::DrawBestMove $w.board ""
  }} $w]

  menu .main.menuaddchoice
  .main.menuaddchoice add command -label " Undo" -image tb_BD_Undo -compound left \
      -command {undoFeature undo}
  .main.menuaddchoice add command -label " $::tr(ReplaceMove)" -image tb_BD_Replace -compound left \
      -command {sc_game undo; addMoveEx $::gameLastMove replace}
  .main.menuaddchoice add command -label " $::tr(NewMainLine)" -image tb_BD_NewMainline -compound left \
      -command {sc_game undo; addMoveEx $::gameLastMove mainline}
  .main.menuaddchoice add command -label " $::tr(AddNewVar)" -image tb_BD_NewVar -compound left \
      -command {sc_game undo; addMoveEx $::gameLastMove var}

  InitToolbar .main.tb

  for {set i 0} { $i < 64 } { incr i } {
    ::board::bind $w.board $i <Enter> [list enterSquare $i]
    ::board::bind $w.board $i <Leave> [list leaveSquare $i]
    ::board::bind $w.board $i <ButtonPress-1> [list pressSquare $i]
    ::board::bind $w.board $i <Control-ButtonPress-1> [list addMarker $w.board %X %Y]
    ::board::bind $w.board $i <Control-ButtonRelease-1> [list addMarker $w.board %X %Y]
    ::board::bind $w.board $i <ButtonPress-$::MB3> [list addMarker $w.board %X %Y]
    ::board::bind $w.board $i <ButtonRelease-$::MB3> [list addMarker $w.board %X %Y]
    ::board::bind $w.board $i <B1-Motion> [list ::board::dragPiece $w.board %X %Y]
    ::board::bind $w.board $i <ButtonRelease-1> [list releaseSquare $w.board %X %Y]
  }

  bind $w <Key> {
    set ch %A
    if {(%s & 0xC) == 0 && $ch ne "" && [moveEntry_Char $ch]} {
      break
    }
  }
  bind $w <BackSpace> moveEntry_Backspace
  bind $w <Delete> moveEntry_Backspace
  bind $w <space> moveEntry_Complete
  bind $w <ButtonRelease> [list focus $w]
  bind $w <Configure> {+::resizeMainBoard }

  bindMouseWheel $w "main_mousewheelHandler"
  foreach e "$w.board $w.board.bd $w.board.bar" {
    bindtags $e [linsert [bindtags $e] 2 $w]
  }

  ttk::frame $w.space
  grid $w.space -row 4 -column 0 -columnspan 3 -sticky nsew
  grid rowconfigure $w 3 -weight 0
  grid rowconfigure $w 4 -weight 1

  grid columnconfigure $w 0 -weight 1
  grid $w.board -row 2 -column 0 -sticky we ;# -padx 5 -pady 5

  updateMainGame
  toggleGameInfo
  updateStatusBar
  updateMainToolbar
  updateTitle
}

################################################################################
# CreateGameInfo
#   Creates and configures the main game-info panel and its context menu.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Creates `.main.gameInfo` widgets and initialises hypertext rendering via
#     `::htext::init`.
#   - Creates photo labels `.main.photoW` / `.main.photoB` bound to
#     `togglePhotosSize`.
#   - Creates `.main.gameInfo.menu` for toggles and delete action.
################################################################################
proc CreateGameInfo {} {
  # .gameInfo is the game information widget:
  #
  autoscrollText y .main.gameInfo .main.gameInfo.text Treeview
  .main.gameInfo.text configure -width 20 -height 6 -wrap none -state disabled -cursor top_left_arrow
  ::htext::init .main.gameInfo.text

  # Set up player photos:
  ttk::label .main.photoW -image photoW -anchor ne
  ttk::label .main.photoB -image photoB -anchor ne
  bind .main.photoW <ButtonPress-1> [list togglePhotosSize]
  bind .main.photoB <ButtonPress-1> [list togglePhotosSize]

  # Right-mouse button menu for gameInfo frame:
  menu .main.gameInfo.menu -tearoff 0

  .main.gameInfo.menu add checkbutton -label GInfoHideNext \
          -variable gameInfo(hideNextMove) -offvalue 0 -onvalue 1 -command updateBoard

  .main.gameInfo.menu add checkbutton -label GInfoMaterial -variable gameInfo(showMaterial) -offvalue 0 -onvalue 1 \
          -command { ::toggleShowMaterial }

  .main.gameInfo.menu add checkbutton -label GInfoFEN \
          -variable gameInfo(showFEN) -offvalue 0 -onvalue 1 -command updateBoard

  .main.gameInfo.menu add checkbutton -label GInfoMarks \
          -variable gameInfo(showMarks) -offvalue 0 -onvalue 1 -command {
              ::board::showMarks .main.board $gameInfo(showMarks)
              updateBoard }

  .main.gameInfo.menu add checkbutton -label GInfoWrap \
          -variable gameInfo(wrap) -offvalue 0 -onvalue 1 -command updateBoard

  .main.gameInfo.menu add checkbutton -label GInfoFullComment \
          -variable gameInfo(fullComment) -offvalue 0 -onvalue 1 -command updateBoard

  .main.gameInfo.menu add checkbutton -label GInfoPhotos \
          -variable gameInfo(photos) -offvalue 0 -onvalue 1 \
          -command {togglePhotosSize 0}

  .main.gameInfo.menu add separator

  .main.gameInfo.menu add command -label GInfoDelete -command {
      sc_base gameflag [sc_base current] [sc_game number] invert del
      ::notify::DatabaseModified [sc_base current]
  }

  bind .main.gameInfo.text <ButtonPress-$::MB3> {
    tk_popup .main.gameInfo.menu %X %Y
  }

  translateMenuLabels .main.gameInfo.menu
}

################################################################################
# setToolbarTooltips
#   Registers tooltips for main toolbar buttons.
# Visibility:
#   Private.
# Inputs:
#   - tb: Toolbar frame widget path.
# Returns:
#   - None.
# Side effects:
#   - Calls `::utils::tooltip::Set` for each toolbar button.
################################################################################
proc setToolbarTooltips { tb } {
    foreach {b m} {
	newdb FileNew open FileOpen finder FileFinder
	save GameReplace closedb FileClose bkm FileBookmarks
	gprev GamePrev gnext GameNext
	newgame GameNew copy EditCopy paste EditPaste
	boardsearch SearchCurrent
	headersearch SearchHeader materialsearch SearchMaterial
	switcher WindowsSwitcher glist WindowsGList pgn WindowsPGN tmt WindowsTmt
	maint WindowsMaint eco WindowsECO tree WindowsTree crosstab ToolsCross
	engine ToolsAnalysis } {
	::utils::tooltip::Set $tb.$b $::helpMessage($::language,$m)
    }
}

################################################################################
# InitToolbar
#   Creates the main toolbar (buttons, menus, and default layout).
# Visibility:
#   Private.
# Inputs:
#   - tb: Toolbar frame widget path (typically `.main.tb`).
# Returns:
#   - None.
# Side effects:
#   - Creates toolbar widgets and wires commands for common actions.
#   - Refreshes bookmarks menu via `::bookmarks::RefreshMenu`.
#   - Registers tooltips via `setToolbarTooltips`.
#   - Applies current toolbar visibility via `redrawToolbar`.
################################################################################
proc InitToolbar {{tb}} {
	ttk::frame $tb -relief raised -border 1
	ttk::button $tb.newdb -image tb_newdb -command ::file::New -padding {2 0}
	ttk::button .main.tb.open -image tb_open -command ::file::Open -padding {2 0}
	ttk::button .main.tb.save -image tb_save  -padding {2 0} -command {
	  if {[sc_game number] != 0} {
		#busyCursor .
		gameReplace
		# catch {.save.buttons.save invoke}
		#unbusyCursor .
	  } else {
		gameAdd
	  }
	}
	ttk::button .main.tb.closedb -image tb_closedb -command ::file::Close -padding {2 0}
	ttk::button .main.tb.finder -image tb_finder -command ::file::finder::Open -padding {2 0}
	ttk::menubutton .main.tb.bkm -image tb_bkm -menu .main.tb.bkm.menu -padding {2 0}
	menu .main.tb.bkm.menu
	::bookmarks::RefreshMenu .main.tb.bkm.menu

	ttk::frame .main.tb.space1 -width 4
	ttk::button .main.tb.newgame -image tb_newgame -command ::game::Clear -padding {2 0}
	ttk::button .main.tb.copy -image tb_copy -command ::gameAddToClipbase -padding {2 0}
	ttk::button .main.tb.paste -image tb_paste \
		-command {catch {sc_clipbase paste}; updateBoard -pgn} -padding {2 0}
	ttk::frame .main.tb.space2 -width 4
	ttk::button .main.tb.gprev -image tb_gprev -command {::game::LoadNextPrev previous} -padding {2 0}
	ttk::button .main.tb.gnext -image tb_gnext -command {::game::LoadNextPrev next} -padding {2 0}
	ttk::frame .main.tb.space3 -width 4
	ttk::button .main.tb.boardsearch -image tb_boardsearch -command ::search::board -padding {2 0}
	ttk::button .main.tb.headersearch -image tb_headersearch -command ::search::header -padding {2 0}
	ttk::button .main.tb.materialsearch -image tb_materialsearch -command ::search::material -padding {2 0}
	ttk::frame .main.tb.space4 -width 4
	ttk::button .main.tb.switcher -image tb_switcher -command ::windows::switcher::Open -padding {2 0}
	ttk::button .main.tb.glist -image tb_glist -command ::windows::gamelist::Open -padding {2 0}
	ttk::button .main.tb.pgn -image tb_pgn -command ::pgn::OpenClose -padding {2 0}
	ttk::button .main.tb.tmt -image tb_tmt -command ::tourney::toggle -padding {2 0}
	ttk::button .main.tb.maint -image tb_maint -command ::maint::OpenClose -padding {2 0}
	ttk::button .main.tb.eco -image tb_eco -command ::windows::eco::OpenClose -padding {2 0}
	ttk::button .main.tb.tree -image tb_tree -command ::tree::make -padding {2 0}
	ttk::button .main.tb.crosstab -image tb_crosstab -command ::crosstab::OpenClose -padding {2 0}
	ttk::button .main.tb.engine -image tb_engine -command ::enginewin::Open -padding {2 0}
	ttk::button .main.tb.help -image tb_help -command {helpWindow Index} -padding {2 0}

	foreach i {newdb open save closedb finder bkm newgame copy paste gprev gnext \
		  boardsearch headersearch materialsearch \
		  switcher glist pgn tmt maint eco tree crosstab engine help} {
	  .main.tb.$i configure -takefocus 0
	}

    setToolbarTooltips $tb
	redrawToolbar
}

################################################################################
# toggleToolbarButton
#   Toggles a single toolbar button in the toolbar configuration UI.
# Visibility:
#   Private.
# Inputs:
#   - b: Container widget path holding the button widgets.
#   - i: Toolbar button key (e.g. `open`, `save`).
# Returns:
#   - None.
# Side effects:
#   - Mutates `::toolbar_temp($i)` and persists to `::toolbar_state($i)`.
#   - Updates the button state (`pressed` / `!pressed`).
#   - Reapplies layout via `redrawToolbar`.
################################################################################
proc toggleToolbarButton { b i } {
    if { $::toolbar_temp($i) } {
	set ::toolbar_temp($i) 0
	$b.$i state !pressed
    } else {
	set ::toolbar_temp($i) 1
	$b.$i state pressed
    }
    array set ::toolbar_state [array get ::toolbar_temp]
    redrawToolbar
}

################################################################################
# toggleAllToolbarButtons
#   Enables or disables all toolbar buttons in the toolbar configuration UI.
# Visibility:
#   Private.
# Inputs:
#   - b: Container widget path holding the button widgets.
#   - state: Boolean-like value (1 to enable all, 0 to disable all).
# Returns:
#   - None.
# Side effects:
#   - Mutates `::toolbar_temp(*)` and persists to `::toolbar_state(*)`.
#   - Updates each button widget state (`pressed` / `!pressed`).
#   - Reapplies layout via `redrawToolbar`.
################################################################################
proc toggleAllToolbarButtons { b state } {
    foreach i [array names ::toolbar_temp] {
	set ::toolbar_temp($i) $state
	if { $state } { $b.$i state pressed } else { $b.$i state !pressed }
    }
    array set ::toolbar_state [array get ::toolbar_temp]
    redrawToolbar
}

################################################################################
# ConfigToolbar
#   Builds the toolbar configuration UI inside the given container.
# Visibility:
#   Public.
# Inputs:
#   - w: Container widget path.
# Returns:
#   - None.
# Side effects:
#   - Creates a grid of toggle buttons and updates `::toolbar_state`.
#   - Wires "all on/off" controls.
#   - Registers tooltips via `setToolbarTooltips`.
################################################################################
proc ConfigToolbar { w } {
  array set ::toolbar_temp [array get ::toolbar_state]
  pack [ttk::frame $w.f] -side top -fill x
  set col 0
  set row 0
  foreach i {newdb open closedb finder save bkm row gprev gnext row newgame copy paste row boardsearch headersearch \
		 materialsearch row switcher glist pgn tmt maint eco tree crosstab engine } {
      if { $i eq "row" } { incr row; set col 0 } else {
		  ttk::button $w.f.$i -image tb_$i -command [list toggleToolbarButton $w.f $i]
	  if { $::toolbar_temp($i) } { $w.f.$i state pressed }
	  grid $w.f.$i -row $row -column $col -sticky news -padx 4 -pady "0 8"
	  incr col
      }
  }
  setToolbarTooltips $w.f
  addHorizontalRule $w
  pack [ttk::frame $w.b] -side bottom -fill x
	  ttk::button $w.on -text "+ [::utils::string::Capital $::tr(all)]" -command [list toggleAllToolbarButtons $w.f 1]
	  ttk::button $w.off -text "- [::utils::string::Capital $::tr(all)]" -command [list toggleAllToolbarButtons $w.f 0]

  pack $w.on $w.off -side left -padx 2 -pady "5 0"
}

################################################################################
# redrawToolbar
#   Applies the current `::toolbar_state` by repacking toolbar widgets.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Packs/unpacks `.main.tb` children and may hide `.main.tb` entirely.
################################################################################
proc redrawToolbar {} {
  foreach i [winfo children .main.tb] { pack forget $i }
  set seenAny 0
  set seen 0
  foreach i {newdb open closedb finder save bkm} {
    if {$::toolbar_state($i)} {
      set seen 1; set seenAny 1
      pack .main.tb.$i -side left -pady 1 -padx 0 -ipadx 0 -pady 0 -ipady 0
    }
  }
  if {$seen} { pack .main.tb.space1 -side left }
  set seen 0
  foreach i {gprev gnext} {
    if {$::toolbar_state($i)} {
      set seen 1; set seenAny 1
      pack .main.tb.$i -side left -pady 1 -padx 0 -ipadx 0 -pady 0 -ipady 0
    }
  }
  if {$seen} { pack .main.tb.space2 -side left }
  set seen 0
  foreach i {newgame copy paste} {
    if {$::toolbar_state($i)} {
      set seen 1; set seenAny 1
      pack .main.tb.$i -side left -pady 1 -padx 0 -ipadx 0 -pady 0 -ipady 0
    }
  }
  if {$seen} { pack .main.tb.space3 -side left }
  set seen 0
  foreach i {boardsearch headersearch materialsearch} {
    if {$::toolbar_state($i)} {
      set seen 1; set seenAny 1
      pack .main.tb.$i -side left -pady 1 -padx 0 -ipadx 0 -pady 0 -ipady 0
    }
  }
  if {$seen} { pack .main.tb.space4 -side left }
  set seen 0
  foreach i {switcher glist pgn tmt maint eco tree crosstab engine} {
    if {$::toolbar_state($i)} {
      set seen 1; set seenAny 1
      pack .main.tb.$i -side left -pady 1 -padx 0 -ipadx 0 -pady 0 -ipady 0
    }
  }
  if {$seenAny} {
    grid .main.tb -row 0 -column 0 -columnspan 3 -sticky we
  } else {
    grid forget .main.tb
  }
}

##############################
