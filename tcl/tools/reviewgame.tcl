### reviewgame.tcl: part of Scid.
### Copyright (C) 2009  Pascal Georges
###
######################################################################
### Try to guess the moves of a game
#

namespace eval reviewgame {
  set engineSlot 6
  set window ".reviewgame"
  set timeShort 3
  set timeExtended 15
  set margin 0.3
  set prevFen ""
  set sequence 0
  
  array set analysisEngine {}
  
  set progressBarStep 1
  set progressBarTimer 0
}

################################################################################
# ::reviewgame::start
#   Launches the game review window and begins the training loop.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Starts a UCI engine in slot `::reviewgame::engineSlot` (if available).
#   - Creates and configures toplevel `::reviewgame::window`.
#   - Reads current game tags via `sc_game tags get`.
#   - Sets the global interaction handler via `::setInteractionHandler`.
#   - Binds window events (destroy/help) and initialises session counters.
#   - Calls `::reviewgame::resetValues` and enters `::reviewgame::mainLoop`.
################################################################################
proc ::reviewgame::start {} {
  if { ! [::reviewgame::launchengine] } {
    tk_messageBox -type ok -icon warning -title "Scid" -message "This feature require at least one UCI engine"
    return
  }

  set w $::reviewgame::window
  createToplevel $w
  setTitle $w [::tr "GameReview" ]
  wm minsize $w 200 200
  
  ttk::frame $w.fgameinfo
  set welo [sc_game tags get WhiteElo]
  set belo [sc_game tags get BlackElo]
  if { $welo == "0"} { set welo "-" }
  if { $belo == "0"} { set belo "-" }
  ttk::label $w.fgameinfo.l1 -text "[sc_game tags get White] ($welo) - [sc_game tags get Black] ($belo)"
  set result [sc_game tags get Result]
  if { $result == "1" } { set result "1-0" }
  if { $result == "0" } { set result "0-1" }
  if { $result == "=" } { set result "1/2 - 1/2" }
  ttk::label $w.fgameinfo.l2 -text "$result"
  pack $w.fgameinfo.l1 $w.fgameinfo.l2
  pack $w.fgameinfo -expand 1 -fill both
  
  ttk::frame $w.fparam
  ttk::label $w.fparam.ltime1 -text "[::tr Time] ([::tr sec])"
  ttk::spinbox $w.fparam.time1 -from 1 -to 120 -textvariable ::reviewgame::timeShort -width 7
  ttk::label $w.fparam.ltime2 -text "[::tr GameReviewTimeExtended] ([::tr sec])"
  ttk::spinbox $w.fparam.time2 -from 3 -to 300 -textvariable ::reviewgame::timeExtended -width 7
  ttk::label $w.fparam.lmargin -text "[::tr GameReviewMargin]"
  ttk::spinbox $w.fparam.margin -from 0.1 -to 1.0 -increment 0.1 -textvariable ::reviewgame::margin -width 7
  
  set row 0
  grid $w.fparam.ltime1 -column 0 -row $row -sticky nw
  grid $w.fparam.time1 -column 1 -row $row -sticky nw
  incr row
  grid $w.fparam.ltime2 -column 0 -row $row -sticky nw
  grid $w.fparam.time2 -column 1 -row $row -sticky nw
  incr row
  grid $w.fparam.lmargin -column 0 -row $row -sticky nw
  grid $w.fparam.margin -column 1 -row $row -sticky nw
  
  pack $w.fparam -expand 1 -fill both
  
  ttk::frame $w.finfo
  pack $w.finfo -expand 1 -fill both
  ttk::progressbar $w.finfo.pb -orient horizontal -length 300 -value 0 -mode determinate
  ttk::label $w.finfo.pblabel -image tb_stop -compound left
  ttk::label $w.finfo.sc1 -text "[::tr GameReviewEngineScore]"
  ttk::label $w.finfo.sc2 -text "[::tr GameReviewGameMoveScore]"
  ttk::label $w.finfo.sc3 -foreground dodgerblue3 -text ""
  ttk::label $w.finfo.eval1 -text ""
  ttk::label $w.finfo.eval2 -text ""
  ttk::label $w.finfo.eval3 -text "" -wraplength 400
  ttk::button $w.finfo.proceed -textvar ::tr(Continue) -command ::reviewgame::proceed
  ttk::button $w.finfo.extended -text "[::tr GameReviewReCalculate]" -command ::reviewgame::extendedTime
  ttk::button $w.finfo.sol -text [::tr ShowSolution ] -command ::reviewgame::showSolution

  set row 0
  grid $w.finfo.sc1 -column 0 -row $row -sticky nw
  grid $w.finfo.eval1 -column 1 -row $row -sticky nw -padx 10
  incr row
  grid $w.finfo.sc2 -column 0 -row $row -sticky nw
  grid $w.finfo.eval2 -column 1 -row $row -sticky nw -padx 10
  incr row
  grid $w.finfo.sc3 -column 0 -row $row -sticky nw
  grid $w.finfo.eval3 -column 1 -row $row -sticky nw -padx 10
  incr row
  grid $w.finfo.pb -column 0 -row $row -sticky w -columnspan 2 -pady { 10 0 }
  incr row
  grid $w.finfo.pblabel -column 0 -row $row -sticky we -columnspan 2
  incr row
  grid $w.finfo.proceed -column 0 -row $row -sticky nw
  grid $w.finfo.extended -column 1 -row $row -sticky nw
  incr row
  grid $w.finfo.sol -column 0 -row $row  -sticky nw
  incr row

  # Display statistics
  ttk::label $w.finfo.stats -text ""
  grid $w.finfo.stats -column 0 -row $row -sticky nw -columnspan 2 -pady { 10 0 }

  ttk::frame $w.fbuttons
  pack $w.fbuttons -fill x
  ttk::button $w.fbuttons.close -textvar ::tr(Abort) -command ::reviewgame::endTraining
  pack $w.fbuttons.close -expand 1 -fill x
  
  set ::reviewgame::boardFlipped [::board::isFlipped .main.board]
  
  bind $w <Destroy> "if {\[string equal $w %W\]} {::reviewgame::endTraining}"
  bind $w <F1> { helpWindow ReviewGame }
  ::createToplevelFinalize $w
  set ::reviewgame::movesLikePlayer 0
  set ::reviewgame::movesLikeEngine 0
  set ::reviewgame::numberMovesPlayed 0
  ::setInteractionHandler "::reviewgame::callback"
  ::reviewgame::resetValues
  ::reviewgame::mainLoop
}

################################################################################
# ::reviewgame::clearEvaluation
#   Clears any displayed solution/evaluation text in the review window.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Updates widgets under `::reviewgame::window.finfo` (solution label and
#     evaluation fields).
################################################################################
proc ::reviewgame::clearEvaluation {} {
  set w $::reviewgame::window
  $w.finfo.sol configure -text "[::tr ShowSolution]"
  $w.finfo.eval1 configure -text ""
  $w.finfo.eval2 configure -text ""
  $w.finfo.eval3 configure -text ""
  $w.finfo.sc3 configure -text ""
}

################################################################################
# ::reviewgame::callback
#   Handles play-mode callbacks while a review session is active.
# Visibility:
#   Public.
# Inputs:
#   - cmd: Callback command name.
#   - args: Additional callback arguments (ignored by this implementation).
# Returns:
#   - 1/0 indicating whether the requested action is permitted/handled.
#     "moveForward" returns 1; "stop" calls `::reviewgame::endTraining` and
#     returns 0.
# Side effects:
#   - On "stop", calls `::reviewgame::endTraining`.
################################################################################
proc ::reviewgame::callback {cmd args} {
  switch $cmd {
      premove { # TODO: currently we just return true if it is the engine turn.
        return [expr { $::reviewgame::sequence != 2 || ![::reviewgame::isPlayerTurn] }]
      }
      stop { ::reviewgame::endTraining }
      moveForward { return 1 }
  }
  return 0
}

################################################################################
# ::reviewgame::showSolution
#   Reveals the next game move in the UI.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Updates `$::reviewgame::window.finfo.sol` with `sc_game info nextMove`.
#   - Sets `::reviewgame::solutionDisplayed`.
################################################################################
proc ::reviewgame::showSolution {} {
  set w $::reviewgame::window
  $w.finfo.sol configure -text "[ sc_game info nextMove ]"
  set ::reviewgame::solutionDisplayed 1
}
################################################################################
# ::reviewgame::endTraining
#   Aborts the current review session and closes the review window.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Cancels scheduled timers (`::reviewgame::mainLoop`, `::reviewgame::stopAnalyze`).
#   - Sets `::reviewgame::bailout` and resets `::reviewgame::sequence`.
#   - Stops any in-flight analysis (`::reviewgame::stopAnalyze`).
#   - Closes `::reviewgame::window` via `::win::closeWindow`.
#   - Resets the global interaction handler via `::setInteractionHandler ""`.
#   - Attempts to close the UCI engine in slot `::reviewgame::engineSlot`.
################################################################################
proc ::reviewgame::endTraining {} {
  set w $::reviewgame::window
  
  after cancel ::reviewgame::mainLoop
  set ::reviewgame::bailout 1
  set ::reviewgame::sequence 0
  after cancel ::reviewgame::stopAnalyze
  ::reviewgame::stopAnalyze
  focus .
  bind $w <Destroy> {}
  ::win::closeWindow $w
  ::setInteractionHandler ""
  
  catch { ::uci::closeUCIengine $::reviewgame::engineSlot }
}
################################################################################
# ::reviewgame::isPlayerTurn
#   Determines whether it is currently the human player's turn from the bottom.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - 1 if the side-to-move corresponds to the bottom player; otherwise 0.
# Side effects:
#   - None.
################################################################################
proc ::reviewgame::isPlayerTurn {} {
  if { [sc_pos side] == "white" &&  ![::board::isFlipped .main.board] || [sc_pos side] == "black" &&  [::board::isFlipped .main.board] } {
    return 1
  }
  return 0
}
################################################################################
# ::reviewgame::mainLoop
#   Drives the review session state machine (analyse game move, analyse position,
#   prompt the user, and validate the played move).
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Cancels and re-schedules itself via `after`.
#   - Updates multiple UI widgets under `::reviewgame::window.finfo`.
#   - May display warning message boxes via `::reviewgame::checkConsistency` and
#     `::reviewgame::checkPlayerMove`.
#   - May flip the main board (`::board::flip`) to keep the player at the bottom.
#   - Runs analysis via `::reviewgame::startAnalyze` and waits via `vwait`.
#   - Calls `::reviewgame::checkPlayerMove` and `::reviewgame::updateStats`.
################################################################################
proc ::reviewgame::mainLoop {} {
  global ::reviewgame::sequence ::reviewgame::useExtendedTime
  set w $::reviewgame::window
  
  after cancel ::reviewgame::mainLoop
  
  if { $useExtendedTime } {
    set ::reviewgame::thinkingTime $::reviewgame::timeExtended
  } else {
    set ::reviewgame::thinkingTime $::reviewgame::timeShort
  }
  
  # check player side, if not at bottom, flip the board
  if { ((! [::reviewgame::isPlayerTurn] && $sequence == 0) || ! [ checkConsistency ]) && \
       [ sc_game info nextMoveNT ] != "" } {
      ::board::flip .main.board
      set ::reviewgame::boardFlipped [::board::isFlipped .main.board]
#      ::notify::PosChanged "" -animate
  }
  
  $w.finfo.proceed configure -state disabled
  $w.finfo.sol configure -state disabled
  
  # Phase 1 : analyze the move really played during the game
  if {$sequence == 0} {
    set ::reviewgame::prevFen [sc_pos fen]
    set ::reviewgame::movePlayed [ sc_game info nextMoveNT ]
    if {$::reviewgame::movePlayed == ""} {
      $w.finfo.pblabel configure -image tb_stop -text ""
      return
    }
    sc_move forward
    set ::reviewgame::nextGameMove [ sc_game info nextMove ]
    sc_move back
    $w.finfo.pblabel configure -image tb_stop -text "[::tr GameReviewAnalyzingMovePlayedDuringTheGame]"
    ::reviewgame::startAnalyze $::reviewgame::thinkingTime $::reviewgame::movePlayed
    vwait ::reviewgame::sequence
    if { $::reviewgame::bailout } { return }
  }
  
  # Phase 2 : find the best engine move in current position
  if { $sequence == 1 } {
    $w.finfo.pblabel configure -image tb_stop -text "[::tr GameReviewAnalyzingThePosition]"
    ::reviewgame::startAnalyze $::reviewgame::thinkingTime
    vwait ::reviewgame::sequence
    if { $::reviewgame::bailout } { return }
  }
  
  $w.finfo.pblabel configure -image tb_play -text "[::tr GameReviewEnterYourMove]"
  $w.finfo.sol configure -state normal
  $w.finfo.proceed configure -state normal
  
  # is this player's turn (which always plays from bottom of the board) ?
  if { [sc_pos fen] == $::reviewgame::prevFen } {
    after 1000 ::reviewgame::mainLoop
    return
  }
  
  ::reviewgame::clearEvaluation
  checkPlayerMove
  
  $w.finfo.extended configure -state normal
  updateStats
  set ::reviewgame::useExtendedTime 0
  after 1000 ::reviewgame::mainLoop
}
################################################################################
# ::reviewgame::checkPlayerMove
#   Validates the user's last move against the game move and the engine's choice.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Reads and mutates game state via `sc_move`, `sc_game`, `sc_pos`, and `sc_var`.
#   - May show warning `tk_messageBox` dialogs (e.g. when the position changes).
#   - May annotate the game (NAG, comments, and variations) for poor moves.
#   - Updates UI evaluation fields and status messages.
#   - May advance the game (`::move::Forward`) depending on outcome.
#   - Updates session counters (`::reviewgame::numberMovesPlayed`, etc.).
################################################################################
proc ::reviewgame::checkPlayerMove {} {
  global ::reviewgame::sequence ::reviewgame::useExtendedTime ::reviewgame::analysisEngine ::animateDelay
  set w $::reviewgame::window
  set moveForward 1

  # check for position change
  sc_move back
  set actFen [sc_pos fen]
  sc_move forward
  if { $actFen != $::reviewgame::prevFen } {
      tk_messageBox -type ok -icon warning -title "Scid" -message "Position changed. New evaluation required!"
      ::reviewgame::resetValues
      set ::reviewgame::sequence 0
      sc_var exit
      ::notify::PosChanged "" -animate
      return
  }
  
  incr ::reviewgame::numberMovesPlayed
  # Phase 3 : ponder on user's move if different of best engine move and move played
  # We know user has played
  set user_move [sc_game info previousMoveNT]
  set engine_move [ lindex $analysisEngine(moves,2) 0]

  # ponder on user's move if he did not play the same move as in match or the engine
  if {$user_move != $::reviewgame::movePlayed && $user_move != $engine_move} {
    $w.finfo.pblabel configure -image tb_stop -text "[::tr GameReviewCheckingYourMove]"
    ::reviewgame::startAnalyze $::reviewgame::thinkingTime ;#$user_move
    vwait ::reviewgame::sequence
    if { $::reviewgame::bailout } { return }
    $w.finfo.pblabel configure -image tb_stop -text "[::tr GameReviewYourMoveWasAnalyzed]"
    # display user's score
    $w.finfo.eval3 configure -text "$analysisEngine(score,2)\t[::trans $user_move]"
  }
  
  # User guessed the correct move played in game
  if {$user_move == $::reviewgame::movePlayed } {
    set ::reviewgame::sequence 0
    
    $w.finfo.sc3 configure -text "[::tr GameReviewYouPlayedSameMove]" -foreground "sea green"
    set result "$analysisEngine(score,1)\t[::trans $::reviewgame::movePlayed]"
    $w.finfo.eval3 configure -text $result
    if { ! $::reviewgame::solutionDisplayed } {
      incr ::reviewgame::movesLikePlayer
    }
    
    # display played move score
    $w.finfo.eval2 configure -text $result
    # display engine's score
    $w.finfo.eval1 configure -text "$analysisEngine(score,2)\t[::trans [lindex $analysisEngine(moves,2) 0]]"
    set sequence 0
  } elseif { $user_move == $engine_move || [ isGoodScore $analysisEngine(score,2) $analysisEngine(score,3)  ] } {
    set ::reviewgame::sequence 0
    
    # User guessed engine's move
    if {$user_move == $engine_move} {
      $w.finfo.sc3 configure -text "[::tr GameReviewYouPlayedLikeTheEngine]" -foreground "sea green"
      $w.finfo.eval3 configure -text "$analysisEngine(score,2)\t[::trans $engine_move]"
      incr ::reviewgame::movesLikeEngine
    } else  {
      $w.finfo.sc3 configure -text "[::tr GameReviewNotEngineMoveButGoodMove]" -foreground dodgerblue3
      $w.finfo.eval3 configure -text "$analysisEngine(score,3)\t[::trans $user_move]"
    }
    sc_var exit
    # animate one move backward and one forward to show the changes to the user
    # without animation it may be confusion what happend
    # maybe an other then the global variable should be used, but this make sure the animation is finished
    after $animateDelay set continueNextMove 1
    ::notify::PosChanged "" -animate
    vwait continueNextMove
    ::move::Forward
    after $animateDelay set continueNextMove 1
    vwait continueNextMove
    # display played move score and two next game move. User can look what happend
    $w.finfo.eval2 configure -text "$analysisEngine(score,1)\t[::trans $::reviewgame::movePlayed] $::reviewgame::nextGameMove"
    # display engine's score
    $w.finfo.eval1 configure -text "$analysisEngine(score,2)\t[::trans [lindex $analysisEngine(moves,2) 0]]"
  } else  {
    # user played a bad move : comment it and restart the process
    set ::reviewgame::sequence 2
    
    $w.finfo.sc3 configure -text "[::tr GameReviewMoveNotGood]" -foreground red
    $w.finfo.eval3 configure -text "$analysisEngine(score,3)\t[::trans $user_move]\n([::trans $analysisEngine(moves,3)])"
    sc_pos addNag "?"
    
    # Add variations for the bad move and the engine move
    sc_pos setComment "$analysisEngine(score,3)"
    sc_move addSan $analysisEngine(moves,3)
    set ::reviewgame::sequence 2
    sc_var exit
    sc_var create
    sc_move addSan [lindex $analysisEngine(moves,2) 0]
    sc_pos setComment "Engine: $analysisEngine(score,2)"
    sc_move addSan [lrange $analysisEngine(moves,2) 1 end]
    sc_var exit
    ::notify::PosChanged "" -animate
    set moveForward 0
    
    # allows a re-calculation
    $w.finfo.extended configure -state normal
    
    # display played move score
    $w.finfo.eval2 configure -text "$analysisEngine(score,1)"
    # display engine's score
    $w.finfo.eval1 configure -text "$analysisEngine(score,2)"
  }
  if { $moveForward } {
      sc_var exit
      ::move::Forward
  }
}
################################################################################
# ::reviewgame::updateStats
#   Updates the displayed per-session statistics ("moves like player/engine").
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Updates `$::reviewgame::window.finfo.stats`.
#   - Reads current player name via `sc_game info`.
################################################################################
proc ::reviewgame::updateStats {} {
  set l $::reviewgame::window.finfo.stats
  if { ![::board::isFlipped .main.board] } {
    set player [sc_game info white]
  } else  {
    set player [sc_game info black]
  }
  
  $l configure -text "[::tr GameReviewMovesPlayedLike] $player : $::reviewgame::movesLikePlayer / $::reviewgame::numberMovesPlayed\n[::tr GameReviewMovesPlayedEngine] : $::reviewgame::movesLikeEngine / $::reviewgame::numberMovesPlayed"
}
################################################################################
# ::reviewgame::isGoodScore
#   Determines whether a move is acceptable given the configured score margin.
# Visibility:
#   Private.
# Inputs:
#   - engine: Engine score for the best move (numeric, from the engine output).
#   - player: Engine score for the player's move (numeric, from the engine output).
# Returns:
#   - 1 if the player's score is within `::reviewgame::margin` of the engine score
#     (from the player's perspective); otherwise 0.
# Side effects:
#   - Reads `::reviewgame::margin` and board orientation via `::board::isFlipped`.
################################################################################
proc ::reviewgame::isGoodScore {engine player} {
  global ::reviewgame::margin
  if { ![::board::isFlipped .main.board] } {
    # if player plays white
    if {$player >= [expr $engine - $margin]} {
      return 1
    }
  } else  {
    if {$player <= [expr $engine + $margin]} {
      return 1
    }
  }
  return 0
}
################################################################################
# ::reviewgame::resetValues
#   Resets per-cycle state used by the review session state machine.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Resets `::reviewgame::sequence`.
#   - Clears analysis state flags (`::reviewgame::analysisEngine(analyzeMode)`,
#     `::reviewgame::bailout`, `::reviewgame::useExtendedTime`,
#     `::reviewgame::solutionDisplayed`).
################################################################################
proc ::reviewgame::resetValues {} {
  set ::reviewgame::sequence 0
  set ::reviewgame::analysisEngine(analyzeMode) 0
  set ::reviewgame::bailout 0
  set ::reviewgame::useExtendedTime 0
  set ::reviewgame::solutionDisplayed 0
}

################################################################################
# ::reviewgame::launchengine
#   Starts the first enabled UCI engine for use by the review session.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - 1 if an engine was found and started; otherwise 0.
# Side effects:
#   - Resets UCI state via `::uci::resetUciInfo`.
#   - Starts an engine via `::uci::startEngine` in slot `::reviewgame::engineSlot`.
#   - Updates `::reviewgame::analysisEngine(analyzeMode)`.
################################################################################
proc ::reviewgame::launchengine {} {
  global ::reviewgame::analysisEngine
  
  ::uci::resetUciInfo $::reviewgame::engineSlot
  set analysisEngine(analyzeMode) 0
  
  # find engine
  set engineFound 0
  set index 0
  foreach e $::engines(list) {
    if {[lindex $e 7] != 0} {
      set engineFound 1
      break
    }
    incr index
  }
  if { ! $engineFound } {
    return 0
  }
  
  ::uci::startEngine $index $::reviewgame::engineSlot ;# start engine in analysis mode
  return 1
}

################################################################################
# ::reviewgame::sendToEngine
#   Sends a command to the configured analysis engine.
# Visibility:
#   Private.
# Inputs:
#   - text: UCI command text to send.
# Returns:
#   - None.
# Side effects:
#   - Writes to the configured engine slot via `::uci::sendToEngine`.
################################################################################
proc ::reviewgame::sendToEngine {text} {
  ::uci::sendToEngine $::reviewgame::engineSlot $text
}

################################################################################
# ::reviewgame::startAnalyze
#   Starts infinite analysis from the current position (optionally after a move)
#   and schedules a timed stop.
# Visibility:
#   Private.
# Inputs:
#   - analysisTime: Analysis duration in seconds.
#   - move: Optional SAN move to apply temporarily before analysing.
# Returns:
#   - None.
# Side effects:
#   - Cancels any pending `::reviewgame::stopAnalyze` timer.
#   - If analysis is already active, sends UCI `exit` before restarting.
#   - Schedules progress bar updates (`::reviewgame::updateProgressBar`).
#   - Updates `::analysis(fen$::reviewgame::engineSlot)`.
#   - Sends UCI `position ...` and `go infinite` to the engine.
#   - Schedules `::reviewgame::stopAnalyze` after `analysisTime` seconds.
################################################################################
proc ::reviewgame::startAnalyze { analysisTime { move "" } } {
  global ::reviewgame::analysisEngine ::reviewgame::engineSlot
  
  set pb $::reviewgame::window.finfo.pb
  set length [$pb cget -maximum]
  set ::reviewgame::progressBarTimer  [expr ( $analysisTime * 1000 * $::reviewgame::progressBarStep ) / $length ]
  after $::reviewgame::progressBarTimer ::reviewgame::updateProgressBar
  
  # Check that the engine has not already had analyze mode started:
  if {$analysisEngine(analyzeMode)} {
    ::reviewgame::sendToEngine "exit"
  }
  set analysisEngine(analyzeMode) 1
  after cancel ::reviewgame::stopAnalyze
  
  # we want to ponder on a particular move, hence we need to switch to a temporary position so
  # UCI code can correctly format the variations
  if {$move != ""} {
    sc_game push copyfast
    sc_move addSan $move
    set ::analysis(fen$engineSlot) [sc_pos fen]
    sc_game pop
  } else  {
    set ::analysis(fen$engineSlot) [sc_pos fen]
  }
  
  ::reviewgame::sendToEngine "position fen $::analysis(fen$engineSlot) $move"
  ::reviewgame::sendToEngine "go infinite"
  after [expr 1000 * $analysisTime] "::reviewgame::stopAnalyze $move"
}
################################################################################
# ::reviewgame::stopAnalyze
#   Stops analysis, captures the current PV for the active phase, and advances
#   `::reviewgame::sequence` to release any `vwait` in the main loop.
# Visibility:
#   Private.
# Inputs:
#   - move: Optional move string passed through from `startAnalyze`.
# Returns:
#   - None. Returns immediately if `::reviewgame::analysisEngine(analyzeMode)` is
#     false.
# Side effects:
#   - Cancels progress bar updates (`::reviewgame::updateProgressBar`).
#   - Resets the progress bar value (if it exists).
#   - Increments `::reviewgame::sequence`.
#   - Updates `::reviewgame::analysisEngine(score,$sequence)` and
#     `::reviewgame::analysisEngine(moves,$sequence)` from `::analysis(multiPV...)`.
#   - When `::reviewgame::sequence` is 1, negates the captured score so it is
#     from White's perspective.
#   - Sends UCI `stop` to the engine.
################################################################################
proc ::reviewgame::stopAnalyze { { move "" } } {
  global ::reviewgame::analysisEngine ::reviewgame::sequence
  
  # Check that the engine has already had analyze mode started:
  if { ! $analysisEngine(analyzeMode) } { return }
  
  after cancel ::reviewgame::updateProgressBar
  if { [winfo exists $::reviewgame::window.finfo.pb]} {
    $::reviewgame::window.finfo.pb configure -value 0
  }

  incr ::reviewgame::sequence
  set pv [lindex $::analysis(multiPV$::reviewgame::engineSlot) 0]
  set analysisEngine(score,$sequence) [lindex $pv 1]
  if { $sequence == 1 } { ;# change score to white perspective
      set analysisEngine(score,$sequence) [expr 0 - $analysisEngine(score,$sequence)]
  }
  set analysisEngine(moves,$sequence) [lindex $pv 2]
  
  set analysisEngine(analyzeMode) 0
  ::reviewgame::sendToEngine "stop"
}
################################################################################
# ::reviewgame::proceed
#   Skips the current guess and advances to the next training cycle.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Clears evaluation UI and exits any active variation (`sc_var exit`).
#   - Advances two plies (`::move::Forward` twice).
#   - Resets per-cycle state and schedules `::reviewgame::mainLoop`.
################################################################################
proc ::reviewgame::proceed {} {
  # skip this move, go to next cycle
  ::reviewgame::clearEvaluation
  sc_var exit
  ::move::Forward
  ::move::Forward
  ::reviewgame::resetValues
  after 1000 ::reviewgame::mainLoop
}
################################################################################
# ::reviewgame::extendedTime
#   Re-runs analysis for the current position using the extended time control.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - No-ops if the engine is currently analysing.
#   - May move back one ply (`::move::Back`) to return to the player's turn.
#   - Sets `::reviewgame::useExtendedTime`, resets `::reviewgame::sequence`, and
#     re-enters `::reviewgame::mainLoop`.
################################################################################
proc ::reviewgame::extendedTime {} {
  # if already calculating, do nothing
  if { $::reviewgame::analysisEngine(analyzeMode)} {
    return
  }
  
  if { ![::reviewgame::isPlayerTurn] } {
    ::move::Back
  }
  
  set ::reviewgame::useExtendedTime 1
  set ::reviewgame::sequence 0
  ::reviewgame::mainLoop
}
################################################################################
# ::reviewgame::updateProgressBar
#   Advances the progress bar and reschedules itself.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Calls `$::reviewgame::window.finfo.pb step`.
#   - Schedules itself via `after` using `::reviewgame::progressBarTimer`.
################################################################################
proc ::reviewgame::updateProgressBar {} {
  $::reviewgame::window.finfo.pb step $::reviewgame::progressBarStep
  after $::reviewgame::progressBarTimer ::reviewgame::updateProgressBar
}
################################################################################
# ::reviewgame::checkConsistency
#   Validates that the board orientation has not changed mid-session.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - 1 if consistent; otherwise 0.
# Side effects:
#   - Shows a warning `tk_messageBox` if the board was rotated.
################################################################################
proc ::reviewgame::checkConsistency {} {
  if { $::reviewgame::boardFlipped != [::board::isFlipped .main.board] } {
    tk_messageBox -type ok -icon warning -title "Scid" -message "Player side is not at bottom. Board is rotated!"
    return 0
  }
  return 1
}

###
### End of file: reviewgame.tcl
###
