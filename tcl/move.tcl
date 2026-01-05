# Copyright (C) 2009-2015 Fulvio Benini
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

### move.tcl
### Functions for moving within a game.

namespace eval ::move {}

################################################################################
# ::move::drawVarArrows
#   Determines whether variation arrows should be (re)drawn for the main board.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - `1` when at least one next-move/variation arrow is missing, otherwise `0`.
# Side effects:
#   - Reads global flags: `::showVarArrows`, `::autoplayMode`.
#   - May consult `::interactionHandler drawVarArrows` (when present).
#   - Reads game state via `sc_var list UCI`, `sc_game info nextMoveUCI`, and
#     existing board marks via `::board::_mark(.main.board)`.
################################################################################
proc ::move::drawVarArrows {} {
	if {! $::showVarArrows || $::autoplayMode ||
		([info exists ::interactionHandler] && [{*}$::interactionHandler drawVarArrows] == 0)} {
		return 0
	}

	set bDrawArrow 0
	set varList [sc_var list UCI]

	if {$varList != ""} {
		set move [sc_game info nextMoveUCI]
		if {$move != ""} { set varList [linsert $varList 0 $move] }
		foreach { move } $varList {
			set bDrawn 0
			set sq_start [ ::board::sq [ string range $move 0 1 ] ]
			set sq_end [ ::board::sq [ string range $move 2 3 ] ]
			foreach mark $::board::_mark(.main.board) {
				if { [lindex $mark 0] == "arrow" } {
					if {[lindex $mark 1] == $sq_start && [lindex $mark 2] == $sq_end} {
						set bDrawn 1
						break
					}
				}
			}
			if {! $bDrawn } { set bDrawArrow 1; break }
		}
	}

	return $bDrawArrow
}

################################################################################
# ::move::showVarArrows
#   Draws mainline and variation arrows on the main board.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Adds arrows to `.main.board` via `::board::mark::add`.
#   - Reads game state via `sc_game info nextMoveUCI` and `sc_var list UCI`.
################################################################################
proc ::move::showVarArrows {} {
	set move [sc_game info nextMoveUCI]
	if {$move != ""} {
		set sq_start [ ::board::sq [ string range $move 0 1 ] ]
		set sq_end [ ::board::sq [ string range $move 2 3 ] ]
		::board::mark::add ".main.board" "arrow" $sq_start $sq_end "#0000ff"
	}
	set varList [sc_var list UCI]
	foreach { move } $varList {
		set sq_start [ ::board::sq [ string range $move 0 1 ] ]
		set sq_end [ ::board::sq [ string range $move 2 3 ] ]
		::board::mark::add ".main.board" "arrow" $sq_start $sq_end "#00aaff"
	}
}

################################################################################
# ::move::Start
#   Moves to the start of the game and refreshes the board.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - May consult `::interactionHandler moveStart` (when present).
#   - Calls `sc_move start`, `updateBoard`, and may draw variation arrows.
################################################################################
proc ::move::Start {} {
	if {[info exists ::interactionHandler] && [{*}$::interactionHandler moveStart] == 0} {
		return
	}
	sc_move start
	updateBoard
	if {[::move::drawVarArrows]} { ::move::showVarArrows }
}

################################################################################
# ::move::End
#   Moves to the end of the game and refreshes the board.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - May consult `::interactionHandler moveEnd` (when present).
#   - Calls `sc_move end`, `updateBoard`, and may draw variation arrows.
################################################################################
proc ::move::End {} {
	if {[info exists ::interactionHandler] && [{*}$::interactionHandler moveEnd] == 0} {
		return
	}
	sc_move end
	updateBoard
	if {[::move::drawVarArrows]} { ::move::showVarArrows }
}

################################################################################
# ::move::EndVar
#   Moves to the end of the current variation line and refreshes the board.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - May consult `::interactionHandler moveEnd` (when present).
#   - Calls `sc_move endVar`, `updateBoard`, and may draw variation arrows.
################################################################################
proc ::move::EndVar {} {
	if {[info exists ::interactionHandler] && [{*}$::interactionHandler moveEnd] == 0} {
		return
	}
	sc_move endVar
	updateBoard
	if {[::move::drawVarArrows]} { ::move::showVarArrows }
}

################################################################################
# ::move::EnterVar
#   Follows the main line or enters a numbered variation.
# Visibility:
#   Public.
# Inputs:
#   - `var_num`: Variation index, where `0` means “follow main line”, and `n>0`
#     enters variation `n-1`.
# Returns:
#   - None.
# Side effects:
#   - Calls `sc_move forward` or `sc_var moveInto`.
#   - Calls `::notify::PosChanged "" -animate`.
#   - Calls `::utils::sound::AnnounceForward`.
################################################################################
proc ::move::EnterVar {var_num} {
	if {$var_num == 0} {
		sc_move forward
	} else {
		sc_var moveInto [expr {$var_num - 1}]
	}
	::notify::PosChanged "" -animate
	::utils::sound::AnnounceForward [sc_game info previous]
}

################################################################################
# ::move::ExitVar
#   Exits the current variation back to its parent line.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - `0` when not currently inside a variation, otherwise an empty result.
# Side effects:
#   - May consult `::interactionHandler moveExitVar` (when present).
#   - Calls `sc_var exit`, `updateBoard`, and may draw variation arrows.
################################################################################
proc ::move::ExitVar {} {
	if {[sc_var level] == 0 } { return 0; }
	if {[info exists ::interactionHandler] && [{*}$::interactionHandler moveExitVar] == 0} {
		return
	}
	sc_var exit;
	updateBoard
	if {[::move::drawVarArrows]} { ::move::showVarArrows }
}

################################################################################
# ::move::ExitVarOrStart
#   Exits a variation if possible; otherwise moves to the start of the game.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Calls `::move::ExitVar` and, when it returns `0`, calls `::move::Start`.
################################################################################
proc ::move::ExitVarOrStart {} {
	if {[::move::ExitVar] eq 0} {
		::move::Start
	}
}

################################################################################
# ::move::Back
#   Moves backwards in the game, handling variation boundaries and UI updates.
# Visibility:
#   Public.
# Inputs:
#   - `count` (optional): Number of plies to move back (default: 1).
# Returns:
#   - None.
# Side effects:
#   - May consult `::interactionHandler moveBack` (when present).
#   - Calls `sc_move back`, may call `sc_var exit` if landing on vstart.
#   - Calls either `::notify::PosChanged "" -animate` + `AnnounceBack` (count=1)
#     or `updateBoard` (count>1).
#   - May draw variation arrows.
################################################################################
proc ::move::Back {{count 1}} {
	if {[sc_pos isAt start]} { return }
	if {[sc_pos isAt vstart]} { ::move::ExitVar; return }
	if {[info exists ::interactionHandler] && [{*}$::interactionHandler moveBack] == 0} {
		return
	}

	sc_move back $count

	if {[sc_pos isAt vstart]} { sc_var exit }

	if {$count == 1} {
		::notify::PosChanged "" -animate
		::utils::sound::AnnounceBack
	} else {
		updateBoard
	}

	if {[::move::drawVarArrows]} { ::move::showVarArrows }
}

################################################################################
# ::move::Forward
#   Moves forwards in the game or, when applicable, shows arrows/variation chooser.
# Visibility:
#   Public.
# Inputs:
#   - `count` (optional): Number of plies to move forward (default: 1).
# Returns:
#   - None.
# Side effects:
#   - May consult `::interactionHandler moveForward` (when present).
#   - When arrows should be drawn and/or the variation popup is enabled and
#     variations exist, draws arrows and/or calls `showVars` instead of moving.
#   - Otherwise calls `sc_move forward`, `::notify::PosChanged "" -animate`, and
#     may call `AnnounceForward` (count=1).
################################################################################
proc ::move::Forward {{count 1}} {
	if {[sc_pos isAt end] || [sc_pos isAt vend]} { return }
	if {[info exists ::interactionHandler] && [{*}$::interactionHandler moveForward] == 0} {
		return
	}

	set bArrows [::move::drawVarArrows]
	set bVarPopup [expr {$::showVarPopup && ! $::autoplayMode && [sc_var count] != 0}]

	if {$bArrows || $bVarPopup} {
		if {$bArrows} { ::move::showVarArrows }
		if {$bVarPopup} { showVars }
	} else {
		sc_move forward $count
		::notify::PosChanged "" -animate
		if {$count == 1} {
			::utils::sound::AnnounceForward [sc_game info previous]
		}
	}
}

################################################################################
# ::move::Follow
#   Follows the main line or enters a variation matching a UCI move.
# Visibility:
#   Public.
# Inputs:
#   - `moveUCI` (optional): UCI move string to follow (defaults to empty).
# Returns:
#   - `1` if `moveUCI` matches the next move or a variation move, otherwise `0`.
# Side effects:
#   - Calls `::move::EnterVar` when a match is found.
#   - Reads move candidates via `sc_game info nextMoveUCI` and `sc_var list UCI`.
################################################################################
proc ::move::Follow {{moveUCI}} {
	if {$moveUCI != "null"} {
		set moveUCI2 "[string range $moveUCI 2 3][string range $moveUCI 0 1][string range $moveUCI 4 end]"
	} else {
		set moveUCI2 "0000"
	}
	set varList [sc_var list UCI]
	set varList [linsert $varList 0 "[sc_game info nextMoveUCI]" ]
	set i 0
	foreach {move} $varList {
		if { [ string compare -nocase $moveUCI $move] == 0 || \
			 [ string compare -nocase $moveUCI2 $move] == 0 } {
			::move::EnterVar $i
			return 1
		}
		incr i
	}
	return 0
}

################################################################################
# ::move::PGNOffset
#   Moves to a PGN location offset and refreshes the board.
# Visibility:
#   Public.
# Inputs:
#   - `location`: PGN location/offset passed to `sc_move pgn`.
# Returns:
#   - None.
# Side effects:
#   - Calls `sc_move pgn`, `updateBoard`, and may draw variation arrows.
################################################################################
proc ::move::PGNOffset { location } {
	sc_move pgn $location
	updateBoard
	if {[::move::drawVarArrows]} { ::move::showVarArrows }
}
