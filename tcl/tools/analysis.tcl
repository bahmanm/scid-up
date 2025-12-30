
###
### analysis.tcl: part of Scid.
### Copyright (C) 1999-2003  Shane Hudson.
### Copyright (C) 2007  Pascal Georges

######################################################################
### Analysis window: uses a chess engine to analyze the board.

# analysis(logMax):
#   The maximum number of log message lines to be saved in a log file.
set analysis(logMax) 5000

# analysis(log_stdout):
#   Set this to 1 if you want Scid-Engine communication log messages
#   to be echoed to stdout.
#
set analysis(log_stdout) 0

set useAnalysisBook 1
set analysisBookSlot 1
set useAnalysisBookName ""
set wentOutOfBook 0
# State variable: 1 <=> engine is making an initial
# assessment of the current position, before progressing
# into the game
set initialAnalysis 0

# State variable: 1 <=> We will not add a variation to
# this move, since this cannot be different from the
# (engine variation to the) main line
set atStartOfLine 0

set batchEnd 1
set stack ""

################################################################################
# resetEngine
# Visibility:
#   Public.
# Inputs:
#   - n (int): Analysis engine slot (typically 1 or 2).
# Returns:
#   - None.
# Side effects:
#   - Writes global array `analysis(...)` for the given engine slot.
#   - Unsets `::uciOptions$n` (UCI option capability cache).
################################################################################
proc resetEngine {n} {
    global analysis
    set analysis(pipe$n) ""             ;# Communication pipe file channel
    set analysis(seen$n) 0              ;# Seen any output from engine yet?
    set analysis(seenEval$n) 0          ;# Seen evaluation line yet?
    set analysis(score$n) 0             ;# Current score in centipawns
    set analysis(prevscore$n) 0         ;# Immediately previous score in centipawns
    set analysis(scoremate$n) 0         ;# Current mating distance (0 if infinite)
    set analysis(prevscoremate$n) 0     ;# Previous mating distance
    set analysis(prevmoves$n) ""        ;# Immediately previous best line out from engine
    set analysis(nodes$n) 0             ;# Number of (kilo)nodes searched
    set analysis(depth$n) 0             ;# Depth in ply
    set analysis(prev_depth$n) 0        ;# Previous depth
    set analysis(time$n) 0              ;# Time in seconds
    set analysis(moves$n) ""            ;# PV (best line) output from engine
    set analysis(seldepth$n) 0
    set analysis(currmove$n) ""         ;# current move output from engine
    set analysis(currmovenumber$n) 0    ;# current move number output from engine
    set analysis(hashfull$n) 0
    set analysis(nps$n) 0
    set analysis(tbhits$n) 0
    set analysis(sbhits$n) 0
    set analysis(cpuload$n) 0
    set analysis(movelist$n) {}         ;# Moves to reach current position
    set analysis(nonStdStart$n) 0       ;# Game has non-standard start
    set analysis(analyzeMode$n) 0       ;# Scid has started analyze mode
    set analysis(automove$n) 0
    set analysis(automoveThinking$n) 0
    set analysis(automoveTime$n) 4000
    set analysis(lastClicks$n) 0
    set analysis(after$n) ""
    set analysis(log$n) ""              ;# Log file channel
    set analysis(logCount$n) 0          ;# Number of lines sent to log file
    set analysis(multiPV$n) {}          ;# multiPV list sorted : depth score moves
    set analysis(multiPVraw$n) {}       ;# same thing but with raw UCI moves
    # Engine protocol flag (unused by the analysis UI for now; kept for debugging).
    # 0 means unknown/not initialised.
    set analysis(protocol$n) 0
    # UCI engine options in format ( name min max ). This is not engine config but its capabilities
    set analysis(uciOptions$n) {}
    # the number of lines in multiPV. If =1 then act the traditional way
    set analysis(multiPVCount$n) 1      ;# number of N-best lines
    set analysis(uciok$n) 0             ;# uciok sent by engine in response to uci command
    set analysis(name$n) ""             ;# engine name
    set analysis(waitForBestMove$n) 0
    set analysis(waitForReadyOk$n) 0
    set analysis(onUciOk$n) ""
    set analysis(movesDisplay$n) 1      ;# if false, hide engine lines, only display scores
    set analysis(lastHistory$n) {}      ;# last best line
    set analysis(maxmovenumber$n) 0     ;# the number of moves in this position
    set analysis(lockEngine$n) 0        ;# the engine is locked to current position
    set analysis(fen$n) {}              ;# the position that engine is analyzing
    set analysis(whenReady$n) {}        ;# list of commands to eval when the engine is ready
    array unset ::uciOptions$n
}

resetEngine 1
resetEngine 2

set annotateMode 0

################################################################################
# calculateNodes
# Visibility:
#   Public.
# Inputs:
#   - n (string|int, optional): Node count as a decimal string (as produced by
#     engines). Defaults to empty.
# Returns:
#   - int: Truncated kilo-nodes (e.g. "12345" -> 12); returns 0 if < 1000.
# Side effects:
#   - None.
################################################################################
proc calculateNodes {{n}} {
    set len [string length $n]
    if { $len < 4 } {
        return 0
    } else {
        set shortn [string range $n 0 [expr {$len - 4}]]
        scan $shortn "%d" nd
        return $nd
    }
}


################################################################################
# resetAnalysis
# Visibility:
#   Public.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Resets analysis statistics in the global `analysis(...)` array.
################################################################################
proc resetAnalysis {{n 1}} {
    global analysis
    set analysis(score$n) 0
    set analysis(scoremate$n) 0
    set analysis(nodes$n) 0
    set analysis(prev_depth$n) 0
    set analysis(depth$n) 0
    set analysis(time$n) 0
    set analysis(moves$n) ""
    set analysis(multiPV$n) {}
    set analysis(multiPVraw$n) {}
    set analysis(lastHistory$n) {}
    set analysis(maxmovenumber$n) 0
}

namespace eval enginelist {
    variable PROTOCOL_UCI_LOCAL 1
    variable PROTOCOL_UCI_NET 2
}

set engines(list) {}

################################################################################
# engine
# Visibility:
#   Public.
# Inputs:
#   - arglist (list): Flat list of attribute/value pairs, e.g.
#       `{Name ... Cmd ... Dir ... Args ... Elo ... Time ... URL ... UCI ...}`.
# Returns:
#   - int (0|1): 1 if the engine entry was accepted, 0 otherwise.
# Side effects:
#   - Appends to global `engines(list)`.
################################################################################
proc engine {arglist} {
    global engines
    array set newEngine {}
    foreach {attr value} $arglist {
        set newEngine($attr) $value
    }
    # Check that required attributes exist:
    if {! [info exists newEngine(Name)]} { return  0 }
    if {! [info exists newEngine(Cmd)]} { return  0 }
    if {! [info exists newEngine(Dir)]} { return  0 }
    # Fill in optional attributes:
    if {! [info exists newEngine(Args)]} { set newEngine(Args) "" }
    if {! [info exists newEngine(Elo)]} { set newEngine(Elo) 0 }
    if {! [info exists newEngine(Time)]} { set newEngine(Time) 0 }
    if {! [info exists newEngine(URL)]} { set newEngine(URL) "" }
    # Scid only supports UCI engines. The `UCI` field is a protocol flag:
    # - ::enginelist::PROTOCOL_UCI_LOCAL : local UCI engine
    # - ::enginelist::PROTOCOL_UCI_NET   : remote UCI engine (network)
    if {! [info exists newEngine(UCI)]} { set newEngine(UCI) $::enginelist::PROTOCOL_UCI_LOCAL }
    if {$newEngine(UCI) ni [list $::enginelist::PROTOCOL_UCI_LOCAL $::enginelist::PROTOCOL_UCI_NET]} {
        error "Unsupported engine protocol flag: $newEngine(UCI)"
    }
    if {! [info exists newEngine(UCIoptions)]} { set newEngine(UCIoptions) "" }

    lappend engines(list) [list $newEngine(Name) $newEngine(Cmd) \
            $newEngine(Args) $newEngine(Dir) \
            $newEngine(Elo) $newEngine(Time) \
            $newEngine(URL) $newEngine(UCI) $newEngine(UCIoptions)]
    return 1
}

################################################################################
# ::enginelist::read
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - int: Result of `catch` (0 on success, non-zero on error).
# Side effects:
#   - Sources the engines configuration file (may call `engine` repeatedly).
################################################################################
proc ::enginelist::read {} {
    return [catch {source [scidConfigFile engines]}]
}

################################################################################
# ::enginelist::write
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - int (0|1): 1 on success, 0 on failure.
# Side effects:
#   - Writes the engines configuration file and rotates a backup (`engines.bak`).
#   - Reads globals: `::scidVersion`, `engines(list)`.
################################################################################
proc ::enginelist::write {} {
    global engines
    
    set enginesFile [scidConfigFile engines]
    set enginesBackupFile [scidConfigFile engines.bak]
    # Try to rename old file to backup file and open new file:
    catch {file rename -force $enginesFile $enginesBackupFile}
    if {[catch {open $enginesFile w} f]} {
        catch {file rename $enginesBackupFile $enginesFile}
        return 0
    }
    
    puts $f "\# Analysis engines list file for Scid $::scidVersion with UCI support"
    puts $f ""
    foreach e $engines(list) {
        set name [lindex $e 0]
        set cmd [lindex $e 1]
        set args [lindex $e 2]
        set dir [lindex $e 3]
        set elo [lindex $e 4]
        set time [lindex $e 5]
        set url [lindex $e 6]
        set uci [lindex $e 7]
        set opt [lindex $e 8]
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
    return 1
}

# Read the user Engine List file now:
#
catch { ::enginelist::read }
if {[llength $engines(list)] == 0} {
    # No engines configured yet; Scid no longer bundles engines.
}

################################################################################
# ::enginelist::date
# Visibility:
#   Public.
# Inputs:
#   - time (int): Seconds since 1970-01-01 (Unix epoch).
# Returns:
#   - string: Local time formatted as "%a %b %d %Y %H:%M".
# Side effects:
#   - None.
################################################################################
proc ::enginelist::date {time} {
    return [clock format $time -format "%a %b %d %Y %H:%M"]
}

################################################################################
# ::enginelist::sort
# Visibility:
#   Public.
# Inputs:
#   - type (string, optional): One of `Name`, `Elo`, `Time`. If empty, the
#     current `engines(sort)` is used.
# Returns:
#   - None.
# Side effects:
#   - Reorders `engines(list)` and updates `engines(sort)`.
#   - If the engine chooser dialog is open, repopulates its tree view.
################################################################################
proc ::enginelist::sort {{type ""}} {
    global engines
    
    if {$type == ""} {
        set type $engines(sort)
    } else {
        set engines(sort) $type
    }
    switch $type {
        Name {
            set engines(list) [lsort -dictionary -index 0 $engines(list)]
        }
        Elo {
            set engines(list) [lsort -dictionary -decreasing -index 4 $engines(list)]
        }
        Time {
            set engines(list) [lsort -integer -decreasing -index 5 $engines(list)]
        }
    }
    
    # If the Engine-open dialog is open, update it:
    #
    set w .enginelist
    if {! [winfo exists $w]} { return }
    set f $w.list.list
    $w.list.list delete [$w.list.list children {}]
    set count 0
    foreach engine $engines(list) {
        set name [lindex $engine 0]
        set elo [lindex $engine 4]
        set time [lindex $engine 5]
        set date [::enginelist::date $time]
        $w.list.list insert {} end -id $count -values [list $name $elo $date]
        incr count
    }
    lassign [$w.list.list children {}] firstItem
    $w.list.list selection set $firstItem
}

################################################################################
# engine.singleclick_
# Visibility:
#   Internal.
# Inputs:
#   - w (widget, optional): Tree view widget.
#   - x (int, optional): Pointer x coordinate.
#   - y (int, optional): Pointer y coordinate.
# Returns:
#   - None.
# Side effects:
#   - Sorts the engine list when the user clicks on a column heading.
################################################################################
proc engine.singleclick_ {{w} {x} {y}} {
    lassign [$w identify $x $y] what
    if {$what == "heading"} {
        set col [$w identify column $x $y]
        ::enginelist::sort [$w column $col -id]
    }
}

################################################################################
# ::enginelist::choose
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - string|int: Engine index into `engines(list)`, or empty string if cancelled.
# Side effects:
#   - Creates and shows the engine chooser dialog and blocks via `tkwait`.
#   - Updates `engines(selection)` and may call `::enginelist::sort`.
################################################################################
proc ::enginelist::choose {} {
    global engines
    set w .enginelist
    if {[winfo exists $w]} {
        raise .enginelist
        return }
    win::createDialog $w
    ::setTitle $w "Scid: [tr ToolsAnalysis]"
    ttk::frame $w.buttons
    ttk::frame $w.list
    # Set up enginelist
    ttk::treeview $w.list.list -columns { "Name" "Elo" "Time" } -height 12 \
        -show headings -selectmode browse -yscrollcommand [list $w.list.ybar set]
    set wid [font measure font_Regular W]
    $w.list.list column Name -width [expr 12 * $wid]
    $w.list.list heading Name -text [tr EngineName]
    $w.list.list column Elo -anchor e -width [expr 4 * $wid]
    $w.list.list heading Elo -text [tr EngineElo]
    $w.list.list column Time -width [expr 12 * $wid]
    $w.list.list heading Time -text [tr EngineTime]
    ttk::scrollbar $w.list.ybar -command [list $w.list.list yview]
    pack $w.list.list $w.list.ybar -side left -fill both -expand 1
    
    # The list of choices:
    pack $w.list -side top -fill y -expand 1
    pack $w.buttons -side top -fill x -pady { 5 0 }
    bind $w.list.list <Double-ButtonRelease-1> "$w.buttons.ok invoke; break"
    bind $w.list.list <ButtonRelease-1> "engine.singleclick_ %W %x %y"
    
    set f $w.buttons
    dialogbutton $f.add -text $::tr(EngineNew...) -command {::enginelist::edit -1}
    dialogbutton $f.edit -text $::tr(EngineEdit...) -command {
        ::enginelist::edit [lindex [.enginelist.list.list selection] 0]
    }
    dialogbutton $f.delete -text $::tr(Delete...) -command {
        ::enginelist::delete [lindex [.enginelist.list.list selection] 0]
    }
    ttk::label $f.sep -text "   "
    dialogbutton $f.ok -text "OK" -command {
        set engines(selection) [lindex [.enginelist.list.list selection] 0]
        destroy .enginelist
    }
    dialogbutton $f.cancel -text $::tr(Cancel) -command {
        set engines(selection) ""
        destroy .enginelist
    }
    packbuttons right $f.cancel $f.ok
    pack $f.add $f.edit $f.delete -side left -padx 1
    
    ::enginelist::sort
    focus $w.list.list
    wm protocol $w WM_DELETE_WINDOW "destroy $w"
    bind $w <F1> { helpWindow Analysis List }
    bind $w <Escape> "destroy $w"
    bind $w.list.list <Return> "$w.buttons.ok invoke; break"
    set engines(selection) ""
    catch {grab $w}
    tkwait window $w
    return $engines(selection)
}

################################################################################
# ::enginelist::setTime
# Visibility:
#   Public.
# Inputs:
#   - index (int): Index into `engines(list)`.
#   - time (int, optional): Seconds since epoch; defaults to the current time.
# Returns:
#   - None.
# Side effects:
#   - Updates the `Time` field of the engine entry in `engines(list)`.
################################################################################
proc ::enginelist::setTime {index {time -1}} {
    global engines
    set e [lindex $engines(list) $index]
    if {$time < 0} { set time [clock seconds] }
    set e [lreplace $e 5 5 $time]
    set engines(list) [lreplace $engines(list) $index $index $e]
}

trace add variable engines(newElo) write [list ::utils::validate::Integer [sc_info limit elo] 0]

################################################################################
# ::enginelist::delete
# Visibility:
#   Public.
# Inputs:
#   - index (int): Index into `engines(list)`.
# Returns:
#   - bool: `true` if removed, `false` if cancelled, empty string on invalid index.
# Side effects:
#   - Prompts the user via `tk_messageBox`.
#   - Modifies `engines(list)`, calls `::enginelist::sort` and `::enginelist::write`.
################################################################################
proc ::enginelist::delete {index} {
    global engines
    if {$index == ""  ||  $index < 0} { return }
    set e [lindex $engines(list) $index]
    set msg "Name: [lindex $e 0]\n"
    append msg "Command: [lindex $e 1]\n\n"
    append msg "Do you really want to remove this engine from the list?"
    set answer [tk_messageBox -title Scid -icon question -type yesno \
            -message $msg]
    if {$answer == "yes"} {
        set engines(list) [lreplace $engines(list) $index $index]
        ::enginelist::sort
        ::enginelist::write
        return true
    }
    return false
}

################################################################################
# ::enginelist::edit
# Visibility:
#   Public.
# Inputs:
#   - index (int): Existing engine index, or -1 to create a new engine entry.
# Returns:
#   - None.
# Side effects:
#   - Creates and shows the engine editor dialog (Tk).
#   - Updates globals under `engines(...)` and, on commit, updates `engines(list)`.
################################################################################
proc ::enginelist::edit {index} {
    global engines
    if {$index == ""} { return }
    
    if {$index >= 0  ||  $index >= [llength $engines(list)]} {
        set e [lindex $engines(list) $index]
    } else {
        set e [list "" "" "" . 0 0 "" $::enginelist::PROTOCOL_UCI_LOCAL {}]
    }
    
    set engines(newIndex) $index
    set engines(newName) [lindex $e 0]
    set engines(newCmd) [lindex $e 1]
    set engines(newArgs) [lindex $e 2]
    set engines(newDir) [lindex $e 3]
    set engines(newElo) [lindex $e 4]
    set engines(newTime) [lindex $e 5]
    set engines(newURL) [lindex $e 6]
    set engines(newProtocol) [lindex $e 7]
    set ::uci::newOptions [lindex $e 8]
    
    set engines(newDate) $::tr(None)
    if {$engines(newTime) > 0 } {
        set engines(newDate) [::enginelist::date $engines(newTime)]
    }
    
    set w .engineEdit
    win::createDialog $w
    ::setTitle $w Scid
    
    set f [ttk::frame $w.f]
    pack $f -side top -fill x -expand yes
    set row 0
    foreach i {Name Cmd Args Dir} {
        ttk::label $f.l$i -text $i
        if {[info exists ::tr(Engine$i)]} {
            $f.l$i configure -text $::tr(Engine$i)
        }
        ttk::entry $f.e$i -textvariable engines(new$i) -width 40
        grid $f.l$i -row $row -column 0 -sticky w
        grid $f.e$i -row $row -column 1 -sticky we
        
        # Browse button for choosing an executable file:
        if {$i == "Cmd"} {
            ttk::button $f.b$i -text "..." -command {
                if {$::windowsOS} {
                    set ftype {
                        {"Applications" {".bat" ".exe"} }
                        {"All files" {"*"} }
                    }
                    set fName [tk_getOpenFile -initialdir $engines(newDir) \
                        -title "Scid: [tr ToolsAnalysis]" -filetypes $ftype]
                } else {
                    set fName [tk_getOpenFile -initialdir $engines(newDir) \
                        -title "Scid: [tr ToolsAnalysis]"]
                }
                if {$fName != ""} {
                    set engines(newCmd) $fName
                    # Set the directory from the executable path if possible:
                    set engines(newDir) [file dirname $fName]
                    if {$engines(newDir) == ""} [ set engines(newDir) .]
                }
            }
            grid $f.b$i -row $row -column 2 -sticky we
        }
        
        if {$i == "Dir"} {
            ttk::button $f.current -text " . " -command {
                set engines(newDir) .
            }
            ttk::button $f.user -text "~/.scid" -command {
                set engines(newDir) $scidUserDir
            }
            if {$::windowsOS} {
                $f.user configure -text "scid.exe dir"
            }
            grid $f.current -row $row -column 2 -sticky we
            grid $f.user -row $row -column 3 -sticky we
        }
        
        if {$i == "URL"} {
            ttk::button $f.bURL -text [tr FileOpen] -command {
                if {$engines(newURL) != ""} { openURL $engines(newURL) }
            }
            grid $f.bURL -row $row -column 2 -sticky we
        }
        
        incr row
    }
    
    grid columnconfigure $f 1 -weight 1
    
    ttk::button $f.bConfigUCI -text $::tr(ConfigureUCIengine) -command {
        ::uci::uciConfig 2 [ toAbsPath $engines(newCmd) ] $engines(newArgs) \
                [ toAbsPath $engines(newDir) ] $::uci::newOptions
    }
    # Mark required fields:
    $f.lName configure -font font_Bold
    $f.lCmd configure -font font_Bold
    $f.lDir configure -font font_Bold
    
    ttk::label $f.lElo -text $::tr(EngineElo)
    ttk::entry $f.eElo -textvariable engines(newElo) -justify right -width 5
    grid $f.lElo -row $row -column 0 -sticky w
    grid $f.eElo -row $row -column 1 -sticky w
    incr row
    grid $f.bConfigUCI -row $row -column 1 -sticky w
    incr row
    
    ttk::label $f.lTime -text $::tr(EngineTime)
    ttk::label $f.eTime -textvariable engines(newDate) -anchor w -width 1
    grid $f.lTime -row $row -column 0 -sticky w
    grid $f.eTime -row $row -column 1 -sticky we
    ttk::button $f.clearTime -text $::tr(Clear) -command {
        set engines(newTime) 0
        set engines(newDate) $::tr(None)
    }
    ttk::button $f.nowTime -text $::tr(Update) -command {
        set engines(newTime) [clock seconds]
        set engines(newDate) [::enginelist::date $engines(newTime)]
    }
    grid $f.clearTime -row $row -column 2 -sticky we
    grid $f.nowTime -row $row -column 3 -sticky we
    
    addHorizontalRule $w
    set f [ttk::frame $w.buttons]
    ttk::button $f.ok -text OK -command {
        if {[string trim $engines(newName)] == ""  ||
            [string trim $engines(newCmd)] == ""  ||
            [string trim $engines(newDir)] == ""} {
            tk_messageBox -title Scid -icon info \
                    -message "The Name, Command and Directory fields must not be empty."
        } else {
            set newEntry [list $engines(newName) $engines(newCmd) \
                    $engines(newArgs) $engines(newDir) \
                    $engines(newElo) $engines(newTime) \
                    $engines(newURL) $engines(newProtocol) $::uci::newOptions]
            if {$engines(newIndex) < 0} {
                lappend engines(list) $newEntry
            } else {
                set engines(list) [lreplace $engines(list) \
                        $engines(newIndex) $engines(newIndex) $newEntry]
            }
            destroy .engineEdit
            ::enginelist::sort
            ::enginelist::write
            raise .enginelist
            focus .enginelist
        }
    }
    ttk::button $f.cancel -text $::tr(Cancel) -command [list apply {{w} {
        destroy $w
        raise .enginelist
        focus .enginelist
    } ::} $w]
    pack $f -side bottom -fill x
    pack $f.cancel $f.ok -side right -padx 2 -pady 2
    ttk::label $f.required -font font_Small -text $::tr(EngineRequired)
    pack $f.required -side left
    
    bind $w <Return> "$f.ok invoke"
    bind $w <Escape> "destroy $w; raise .enginelist; focus .enginelist"
    bind $w <F1> { helpWindow Analysis List }
    focus $w.f.eName
    wm resizable $w 1 0
    catch {grab $w}
}

################################################################################
# autoplay
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Advances through the game (main line and/or variations).
#   - May start/stop engine analysis and add annotations.
#   - Mutates multiple global state variables (e.g. `::autoplayMode`,
#     `::annotateMode`, `::initialAnalysis`, `::wentOutOfBook`, and `analysis(...)`).
################################################################################
proc autoplay {} {
    global autoplayDelay autoplayMode annotateMode analysis
    
    # Was autoplay stopped by the user since the last time the timer ran out?
    # If so, silently exit this handler
    #
    if { $autoplayMode == 0 } {
        return
    }
    
    # Add annotation if needed
    #
    if { $annotateMode } {
        addAnnotation
    }
    
    if { $::initialAnalysis } {
        # Stop analysis if it is running
        # We do not want initial super-accuracy
        #
        stopEngineAnalysis 1
        set annotateMode 1
        # First do the book analysis (if this is configured)
        # The latter condition is handled by the operation itself
        set ::wentOutOfBook 0
        bookAnnotation 1
        # Start the engine
        startEngineAnalysis 1 1
    
    # Autoplay comes in two flavours:
    # + It can run through a game, with or without annotation
    # + It can be annotating just opening sections of games
    # See if such streak ends here and now
    #
    } elseif { [sc_pos isAt end] || ($annotateMode && $::isBatchOpening && ([sc_pos moveNumber] > $::isBatchOpeningMoves)) } {
        
        # Stop the engine
        #
        stopEngineAnalysis 1
        
        # Are we running a batch analysis?
        #
        if { $annotateMode && $::isBatch } {
            # First replace the game we just finished
            #
            set gameNo [sc_game number]
            if { $gameNo != 0 } {
                sc_game save $gameNo
            }
            
            # See if we must advance to the next game
            #
            if { $gameNo < $::batchEnd } {
                incr gameNo
                sc_game load $gameNo
                updateTitle
                updateBoard -pgn
                # First do book analysis
                #
                set ::wentOutOfBook 0
                bookAnnotation 1
                # Start with initial assessment of the position
                #
                set ::initialAnalysis 1
                # Start the engine
                #
                startEngineAnalysis 1 1
            } else {
                # End of batch, stop
                #
                cancelAutoplay
                return
            }
        } else {
            # Not in a batch, just stop
            #
            cancelAutoplay
            return
        }
    } elseif { $annotateMode && $::isAnnotateVar } {
        # A construction to prune empty variations here and now
        # It makes no sense to discover only after some engine
        # time that we entered a dead end.
        #
        set emptyVar 1
        while { $emptyVar } {
            set emptyVar 0
            # Are we at the end of a variation?
            # If so, pop back into the parent
            #
            if { [sc_pos isAt vend] } {
                sc_var exit
                set lastVar [::popAnalysisData]
            } else {
                set lastVar [sc_var count]
            }
            # Is there a subvariation here?
            # If so, enter it after pushing where we are
            #
            if { $lastVar > 0 } {
                incr lastVar -1
                sc_var enter $lastVar
                ::pushAnalysisData $lastVar
                # Check if this line is empty
                # If so, we will pop back immediately in the next run
                #
                if { [sc_pos isAt vstart] && [sc_pos isAt vend] } {
                    set emptyVar 1
                } else {
                    # We are in a new line!
                    # Tell the annotator (he might be interested)
                    #
                    updateBoard -pgn
                    set ::atStartOfLine 1
                }
            } else {
                # Just move ahead following the current line
                #
                ::move::Forward
            }
        }
    } else {
        # Just move ahead following the main line
        #
        ::move::Forward
    }
    
    # Respawn
    #
    after $autoplayDelay autoplay
}

################################################################################
# startAutoplay
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Enables autoplay and schedules the first `autoplay` tick.
################################################################################
proc startAutoplay { } {
    set ::autoplayMode 1
    after 100 autoplay
}

################################################################################
# cancelAutoplay
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Disables autoplay/annotation mode.
#   - Cancels pending `after` timer(s) and updates UI state if present.
#   - Notifies the rest of the application via `::notify::PosChanged`.
################################################################################
proc cancelAutoplay {} {
    set ::autoplayMode 0
    set ::annotateMode 0
    #TODO: improve this, do not hardcode the button name
    if {[winfo exists .analysisWin1.b1.annotate]} {
        .analysisWin1.b1.annotate state !pressed
    }
    after cancel autoplay

    #TODO: the position is not changed and the notify should not be necessary
    ::notify::PosChanged
}

################################################################################
# configAnnotation
# Visibility:
#   Internal.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Creates and shows the annotation configuration dialog (Tk).
#   - May stop autoplay if it is currently active.
#   - Adds validation traces to some configuration variables.
################################################################################
proc configAnnotation {} {
    global autoplayDelay tempdelay blunderThreshold
    
    set w .configAnnotation
    # Do not do anything if the window exists
    #
    if { [winfo exists $w] } {
        raise $w
        focus $w
        return
    }
    
    # If the annotation button is pressed while annotation is
    # running, stop the annotation
    if {$::autoplayMode} {
        cancelAutoplay
        return
    }

    trace add variable blunderThreshold write {::utils::validate::Regexp {^[0-9]*\.?[0-9]*$}}
    trace add variable tempdelay write {::utils::validate::Regexp {^[0-9]*\.?[0-9]*$}}
    
    set tempdelay [expr {$autoplayDelay / 1000.0}]
    win::createDialog $w
    ::setTitle $w "Scid: $::tr(Annotate)"
    wm resizable $w 0 0
    set f [ttk::frame $w.f]
    pack $f -expand 1

    ttk::labelframe $f.analyse -text $::tr(GameReview)
    ttk::label $f.analyse.label -text $::tr(AnnotateTime)
    ttk::spinbox $f.analyse.spDelay -width 5 -textvariable tempdelay -from 0.1 -to 999 \
        -validate key -justify right
    ttk::radiobutton  $f.analyse.allmoves     -text $::tr(AnnotateAllMoves)     -variable annotateBlunders -value allmoves
    ttk::radiobutton  $f.analyse.blundersonly -text $::tr(AnnotateBlundersOnly) -variable annotateBlunders -value blundersonly
    ttk::frame $f.analyse.blunderbox
    ttk::label $f.analyse.blunderbox.label -text $::tr(BlundersThreshold:)
    ttk::spinbox $f.analyse.blunderbox.spBlunder -width 4 -textvariable blunderThreshold \
            -from 0.1 -to 3.0 -increment 0.1 -justify right
    ttk::checkbutton $f.analyse.cbBook  -text $::tr(UseBook) -variable ::useAnalysisBook
    # choose a book for analysis
    # load book names
    set bookPath $::scidBooksDir
    set bookList [  lsort -dictionary [ glob -nocomplain -directory $bookPath *.bin ] ]
    
    # No book found
    if { [llength $bookList] == 0 } {
        set ::useAnalysisBook 0
        $f.analyse.cbBook configure -state disabled
    }
    
    set tmp {}
    set idx 0
    set i 0
    foreach file  $bookList {
        lappend tmp [ file tail $file ]
        if {$::book::lastBook == [ file tail $file ] } {
            set idx $i
        }
        incr i
    }
    ttk::combobox $f.analyse.comboBooks -width 12 -values $tmp
    catch { $f.analyse.comboBooks current $idx }
    pack $f.analyse.comboBooks -side bottom -anchor w -padx 20
    pack $f.analyse.cbBook -side bottom -anchor w
    pack $f.analyse.blunderbox.label -side left -padx { 20 0 }
    pack $f.analyse.blunderbox.spBlunder -side left -anchor w
    pack $f.analyse.blunderbox -side bottom -anchor w
    pack $f.analyse.blundersonly -side bottom -anchor w
    pack $f.analyse.allmoves  -side bottom -anchor w
    pack $f.analyse.label -side left -anchor w
    pack $f.analyse.spDelay -side right -anchor e
    bind $w <Escape> { .configAnnotation.f.buttons.cancel invoke }
    bind $w <Return> { .configAnnotation.f.buttons.ok invoke }

    ttk::labelframe   $f.av -text $::tr(AnnotateWhich)
    ttk::radiobutton  $f.av.all     -text $::tr(AnnotateAll)   -variable annotateMoves -value all
    ttk::radiobutton  $f.av.white   -text $::tr(AnnotateWhite) -variable annotateMoves -value white
    ttk::radiobutton  $f.av.black   -text $::tr(AnnotateBlack) -variable annotateMoves -value black
    pack $f.av.all $f.av.white $f.av.black -side top -fill x -anchor w

    ttk::labelframe   $f.comment -text $::tr(Comments)
    ttk::checkbutton  $f.comment.cbAnnotateVar      -text $::tr(AnnotateVariations)         -variable ::isAnnotateVar
    ttk::checkbutton  $f.comment.cbShortAnnotation  -text $::tr(ShortAnnotations)           -variable ::isShortAnnotation
    ttk::checkbutton  $f.comment.cbAddScore         -text $::tr(AddScoreToShortAnnotations) -variable ::addScoreToShortAnnotations
    ttk::checkbutton  $f.comment.cbAddAnnotatorTag  -text $::tr(addAnnotatorTag)            -variable ::addAnnotatorTag
    # Checkmark to enable all-move-scoring
    ttk::checkbutton  $f.comment.scoreAll -text $::tr(ScoreAllMoves) -variable scoreAllMoves
    ttk::checkbutton  $f.comment.cbMarkTactics -text $::tr(MarkTacticalExercises) -variable ::markTacticalExercises
    
    pack $f.comment.scoreAll $f.comment.cbAnnotateVar $f.comment.cbShortAnnotation $f.comment.cbAddScore \
	$f.comment.cbAddAnnotatorTag $f.comment.cbMarkTactics -fill x -anchor w
    # batch annotation of consecutive games, and optional opening errors finder
    ttk::frame $f.batch
    ttk::frame $f.buttons
    grid $f.analyse -row 0 -column 0 -pady { 0 10 } -sticky nswe -padx { 0 10 }
    grid $f.comment -row 0 -column 1 -pady { 0 10 } -sticky nswe -padx { 10 0 }
    grid $f.av -row 1 -column 0 -pady { 10 0 } -sticky nswe -padx { 0 10 }
    grid $f.batch -row 1 -column 1 -pady { 10 0 } -sticky nswe -padx { 10 0 }
    grid $f.buttons -row 2 -column 1 -sticky we

    set to [sc_base numGames $::curr_db]
    if {$to <1} { set to 1}
    ttk::checkbutton $f.batch.cbBatch -text $::tr(AnnotateSeveralGames) -variable ::isBatch
    ttk::spinbox $f.batch.spBatchEnd -width 8 -textvariable ::batchEnd \
            -from 1 -to $to -increment 1 -validate all -validatecommand { regexp {^[0-9]+$} %P }
    ttk::checkbutton $f.batch.cbBatchOpening -text $::tr(FindOpeningErrors) -variable ::isBatchOpening
    ttk::spinbox $f.batch.spBatchOpening -width 2 -textvariable ::isBatchOpeningMoves \
            -from 10 -to 20 -increment 1 -validate all -validatecommand { regexp {^[0-9]+$} %P }
    ttk::label $f.batch.lBatchOpening -text $::tr(moves)
    pack $f.batch.cbBatch -side top -anchor w -pady { 0 0 }
    pack $f.batch.spBatchEnd -side top -padx 20 -anchor w
    pack $f.batch.cbBatchOpening -side top -anchor w
    pack $f.batch.spBatchOpening -side left -anchor w -padx { 20 4 }
    pack $f.batch.lBatchOpening  -side left
    set ::batchEnd $to
    
    ttk::button $f.buttons.cancel -text $::tr(Cancel) -command {
        destroy .configAnnotation
    }
    ttk::button $f.buttons.ok -text "OK" -command {
        set ::useAnalysisBookName [.configAnnotation.f.analyse.comboBooks get]
        set ::book::lastBook $::useAnalysisBookName
        
        # tactical positions is selected, must be in multipv mode
        if {$::markTacticalExercises} {
            if { $::analysis(multiPVCount1) < 2} {
                # TODO: Why not put it at the (apparent) minimum of 2?
                #
                set ::analysis(multiPVCount1) 4
                changePVSize 1
            }
        }
        
        if {$tempdelay < 0.1} { set tempdelay 0.1 }
        set autoplayDelay [expr {int($tempdelay * 1000)}]
        destroy .configAnnotation
        .analysisWin1.b1.annotate state pressed
        # Tell the analysis mode that we want an initial assessment of the
        # position. So: no comments yet, please!
        set ::initialAnalysis 1
        # And start the time slicer
        startAutoplay
    }
    pack $f.buttons.cancel $f.buttons.ok -side right -padx 5 -pady 5
    focus $f.analyse.spDelay
    bind $w <Destroy> { focus . }
}
################################################################################
# bookAnnotation
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Loads and queries the configured opening book (`sc_book`).
#   - Advances the game forward through book moves; may move back one ply.
#   - Updates position comments and resets/updates some `analysis(...)` fields.
################################################################################
proc bookAnnotation { {n 1} } {
    global analysis
    
    if {$::annotateMode && $::useAnalysisBook} {
        
        set prevbookmoves ""
        set bn [ file join $::scidBooksDir $::useAnalysisBookName ]
        sc_book load $bn $::analysisBookSlot
        
        lassign [sc_book moves $::analysisBookSlot] bookmoves
        while {[string length $bookmoves] != 0 && ![sc_pos isAt vend]} {
            # we are in book, so move immediately forward
            ::move::Forward
            set prevbookmoves $bookmoves
            lassign [sc_book moves $::analysisBookSlot] bookmoves
        }
        sc_book close $::analysisBookSlot
        set ::wentOutOfBook 1
        
        set verboseMoveOutOfBook " $::tr(MoveOutOfBook)"
        set verboseLastBookMove " $::tr(LastBookMove)"
        
        set theCatch 0
        if { [ string match -nocase "*[sc_game info previousMoveNT]*" $prevbookmoves ] != 1 } {
            if {$prevbookmoves != ""} {
                sc_pos setComment "[sc_pos getComment]$verboseMoveOutOfBook [::trans $prevbookmoves]"
            } else  {
                sc_pos setComment "[sc_pos getComment]$verboseMoveOutOfBook"
            }
            # last move was out of book: it needs to be analyzed, so take back
            #
            set theCatch [catch {sc_move back 1}]
        } else  {
            sc_pos setComment "[sc_pos getComment]$verboseLastBookMove"
        }
        
        if { ! $theCatch } {
            resetAnalysis
            updateBoard -pgn
        }
        set analysis(prevscore$n)     $analysis(score$n)
        set analysis(prevmoves$n)     $analysis(moves$n)
        set analysis(prevscoremate$n) $analysis(scoremate$n)
        set analysis(prevdepth$n)     $analysis(depth$n)
    }
}

################################################################################
# markExercise
# Visibility:
#   Internal.
# Inputs:
#   - prevscore (double): Previous evaluation score.
#   - score (double): Current evaluation score.
#   - nag (string): NAG to add for the current move (e.g. "!?").
# Returns:
#   - int (0|1): 1 if the position was marked as an exercise, otherwise 0.
# Side effects:
#   - Adds NAG(s) and may set/append comments on the current position.
#   - Reads global config such as `::markTacticalExercises` and `::informant(...)`.
################################################################################
proc markExercise { prevscore score nag} {
    
    sc_pos addNag $nag
    
    if {!$::markTacticalExercises} { return 0 }
    
    # check at which depth the tactical shot is found
    
    set deltamove [expr {$score - $prevscore}]
    # filter tactics so only those with high gains are kept
    if { [expr abs($deltamove)] < $::informant(+/-) } { return 0 }
    # dismiss games where the result is already clear (high score,and we continue in the same way)
    if { [expr $prevscore * $score] >= 0} {
        if { [expr abs($prevscore) ] > $::informant(+--) } { return 0 }
        if { [expr abs($prevscore)] > $::informant(+-) && [expr abs($score) ] < [expr 2 * abs($prevscore)]} { return 0 }
    }
    
    # The best move is much better than others.
    if { [llength $::analysis(multiPV1)] < 2 } {
        return 0
    }
    set sc2 [lindex [ lindex $::analysis(multiPV1) 1 ] 1]
    if { [expr abs( $score - $sc2 )] < 1.5 } { return 0 }
    
    # There is no other winning moves (the best move may not win, of course, but
    # I reject exercises when there are e.g. moves leading to +9, +7 and +5 scores)
    if { [expr $score * $sc2] > 0.0 && [expr abs($score)] > $::informant(+-) && [expr abs($sc2)] > $::informant(+-) } {
        return 0
    }
    
    # The best move does not lose position.
    if {[sc_pos side] == "white" && $score < [expr 0.0 - $::informant(+/-)] } { return 0 }
    if {[sc_pos side] == "black" && $score > $::informant(+/-) } { return 0}
    
    # Move is not obvious: check that it is not the first move guessed at low depths
    set pv [ lindex [ lindex $::analysis(multiPV1) 0 ] 2 ]
    set bm0 [lindex $pv 0]
    foreach depth {1 2 3} {
        set res [ sc_pos analyze -time 1000 -hashkb 32 -pawnkb 1 -searchdepth $depth ]
        set bm$depth [lindex $res 1]
    }
    if { $bm0 == $bm1 && $bm0 == $bm2 && $bm0 == $bm3 } {
        return 0
    }
    
    # find what time is needed to get the solution (use internal analyze function)
    set timer {1 2 5 10 50 100 200 1000}
    set movelist {}
    for {set t 0} {$t < [llength $timer]} { incr t} {
        set res [sc_pos analyze -time [lindex $timer $t] -hashkb 1 -pawnkb 1 -mindepth 0]
        set move_analyze [lindex $res 1]
        lappend movelist $move_analyze
    }
    
    # find at what timing the right move was reliably found
    # only the move is checked, not if the score is close to the expected one
    for {set t [expr [llength $timer] -1]} {$t >= 0} { incr t -1} {
        if { [lindex $movelist $t] != $bm0 } {
            break
        }
    }
    
    set difficulty [expr $t +2]
    
    # If the base opened is read only, like a PGN file, avoids an exception
    catch { sc_base gameflag [sc_base current] [sc_game number] set T }
    sc_pos setComment "****D${difficulty} [format %.1f $prevscore]->[format %.1f $score] [sc_pos getComment]"
    updateBoard
    
    return 1
}

################################################################################
# addAnnotation
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Reads engine analysis from `analysis(...)` and annotates the current game:
#     adds comments, NAGs, and (optionally) engine line variations.
#   - May push/pop variations, move forwards/backwards, and update UI.
#   - Mutates `analysis(prev...)` fields and several global annotation settings.
################################################################################
proc addAnnotation { {n 1} } {
    global analysis annotateMoves annotateBlunders annotateMode blunderThreshold scoreAllMoves autoplayDelay
    
    # Check if we only need to register an initial
    # assessment of the position
    # If so, we do not generate any annotation yet
    #
    if { $::initialAnalysis } {
        set ::initialAnalysis 0
        
        if { $::isBatchOpening && ([sc_pos moveNumber] < $::isBatchOpeningMoves ) } {
            appendAnnotator "opBlunder [sc_pos moveNumber] ([sc_pos side])"
        }
        if { $::addAnnotatorTag } {
            appendAnnotator "$analysis(name1) ([expr {$autoplayDelay / 1000}] sec)"
        }
        
        set analysis(prevscore$n)     $analysis(score$n)
        set analysis(prevmoves$n)     $analysis(moves$n)
        set analysis(prevscoremate$n) $analysis(scoremate$n)
        set analysis(prevdepth$n)     $analysis(depth$n)
        
        return
    }
    
    # Check if we are at the start of a subline
    # If so, we will not include the engine line as a variation.
    # Rationale: this line cannot be different from the line for the
    # main move, that we will include anyway.
    #
    set skipEngineLine $::atStartOfLine
    set ::atStartOfLine 0
            
    # First look in the book selected
    # TODO: Is this dead code by now?
    # TODO: Seek for an opportunity to do book analysis on a move by
    #       move basis, thus allowing variations to be included
    #
    if { ! $::wentOutOfBook && $::useAnalysisBook } {
        bookAnnotation
        return
    }
    
    # Let's try to assess the situation:
    # We are here, now that the engine has analyzed the position reached by
    # our last move. Currently it is the opponent to move:
    #
    set tomove [sc_pos side]

    # And this is his best line:
    #
    set moves $analysis(moves$n)
    # For non-uci lines, trim space characters in <moveno>.[ *][...]<move> 
    set moves [regsub -all {\. *} $moves {.}]
    
    # The best line we could have followed, and the game move we just played instead, are here:
    #
    set prevmoves $analysis(prevmoves$n)
    # For non-uci lines, trim space characters in <moveno>.[ *][...]<move> 
    set prevmoves [regsub -all {\. *} $prevmoves {.}]

    set gamemove  [sc_game info previousMoveNT]
    
    # Bail out if we have a mate
    #
    if { [expr { [string index $gamemove end] == "#" }] } {
        set analysis(prevscore$n)     $analysis(score$n)
        set analysis(prevmoves$n)     $analysis(moves$n)
        set analysis(prevscoremate$n) $analysis(scoremate$n)
        set analysis(prevdepth$n)     $analysis(depth$n)
        return
    }
    
    # We will add a closing line at the end of variation or game
    #
    set addClosingLine 0
    if {  [sc_pos isAt vend] } {
        set addClosingLine 1
    }

    # We do not want to insert a best-line variation into the game
    # if we did play along that line. Even not when annotating all moves.
    # It simply makes no sense to do so (unless we are debugging the engine!)
    # Sooner or later the game will deviate anyway; a variation at that point will
    # do nicely and is probably more accurate as well.
    #
    set bestMovePlayed 0
    set bestMoveIsMate 0
    if { $prevmoves != "" } {
        # Following lines of code have only one goal:
        # Transform an engine move (e.g. "g1f3") into the short notation that we use
        # for moves in our games ("Nf3"), such that they can be (string) compared.
        # We create a scratch copy of the game, add the engine move and then ask
        # the game about the most recent move that was played.
        # This might not be the most subtle solution...
        sc_game push copyfast
        set bestmove [lindex $prevmoves 0]
        sc_move back 1
        sc_move_add $bestmove $n
        set bestmove [sc_game info previousMoveNT]
        sc_game pop
        
        if { $bestmove == $gamemove } {
            set bestMovePlayed 1
        }
        
        # Did we miss a mate in one?
        #
        set bestMoveIsMate [expr { [string index $bestmove end] == "#" }]
    }
    
    
    # As said, another reason not to include the engine line
    #
    set skipEngineLine [expr {$skipEngineLine + $bestMovePlayed}]

    # As to the engine evaluations
    # This is score the opponent will have if he plays his best move next
    #
    set score $analysis(score$n)
    
    # This is the score we could have had if we had played our best move
    #
    set prevscore $analysis(prevscore$n)
    
    # Let's help the engine a bit...
    # It makes no sense to criticise the players for moving insights at
    # engine end. So we upgrade the old score to the new score if the lines
    # start with the same move.
    #
    if { $bestMovePlayed } {
        set prevscore $score
    }
    
    # Note that the engine's judgement is in absolute terms, a negative score
    # being favorable to black, a positive score favorable to white
    # Looking primarily for blunders, we are interested in the score decay,
    # which, for white, is (previous-current)
    #
    set deltamove [expr {$prevscore - $score}]
    # and whether the game was already lost for us
    #
    set gameIsLost [expr {$prevscore < (0.0 - $::informant(+--))}]
    
    # Invert this logic for black
    #
    if { $tomove == "white" } {
        set deltamove [expr {0.0 - $deltamove}]
        set gameIsLost [expr {$prevscore > $::informant(+--)}] 
    }
    
    # Note btw that if the score decay is - unexpectedly - negative, we played
    # a better move than the engine's best line!
    
    # Set an "isBlunder" filter.
    # Let's mark moves with a decay greater than the threshold.
    #
    set isBlunder 0
    if { $deltamove > $blunderThreshold } {
        set isBlunder 2
    } elseif { $deltamove > 0 } {
        set isBlunder 1
    }
    
    set absdeltamove [expr { abs($deltamove) } ]
    
    set exerciseMarked 0
    
    # to parse scores if the engine's name contains - or + chars (see sc_game_scores)
    #
    set engine_name  [string map {"-" " " "+" " "} $analysis(name$n)]
    
    # Prepare score strings for the opponent
    #
    if { $analysis(scoremate$n) != 0 } {
        set text [format "%d:M%d" $analysis(depth$n) $analysis(scoremate$n)]
    } else {
        set text [format "%d:%+.2f" $analysis(depth$n) $score]
    }
    # And for the my (missed?) chance
    #
    if { $analysis(prevscoremate$n) != 0 } {
        set prevtext [format "%d:M%d" $analysis(prevdepth$n) $analysis(prevscoremate$n)]
    } else {
        set prevtext [format "%d:%+.2f" $analysis(prevdepth$n) $prevscore]
    }
    
    # Must we annotate our own moves? If no, we bail out unless
    # - we must add a closing line
    #
    if { ( $annotateMoves == "white"  &&  $tomove == "white" ||
           $annotateMoves == "black"  &&  $tomove == "black"   ) && ! $addClosingLine } {
        set analysis(prevscore$n)     $analysis(score$n)
        set analysis(prevmoves$n)     $analysis(moves$n)
        set analysis(prevscoremate$n) $analysis(scoremate$n)
        set analysis(prevdepth$n)     $analysis(depth$n)

        updateBoard -pgn
    }
    

    # See if we have the threshold filter activated.
    # If so, take only bad moves and missed mates until the position is lost anyway
    #
    # Or that we must annotate all moves
    #
    if {  (  $annotateBlunders == "blundersonly"
          && ($isBlunder > 1 || ($isBlunder > 0 && [expr abs($score)] >= 327.0))
          && ! $gameIsLost)
       || ($annotateBlunders == "allmoves") } {
        if { $isBlunder > 0 } {
            # Add move score nag, and possibly an exercise
            #
            if {       $absdeltamove > $::informant(??) } {
                set exerciseMarked [ markExercise $prevscore $score "??" ]
            } elseif { $absdeltamove > $::informant(?)  } {
                set exerciseMarked [ markExercise $prevscore $score "?" ]
            } elseif { $absdeltamove > $::informant(?!) } {
                sc_pos addNag "?!"
            }
        } elseif { $absdeltamove > $::informant(!?) } {
            sc_pos addNag "!?"
        }
            
        # Add score comment and engine name if needed
        #
        if { ! $::isShortAnnotation } {
            sc_pos setComment "[sc_pos getComment] $engine_name: $text"
        } elseif { $::addScoreToShortAnnotations || $scoreAllMoves } {
            sc_pos setComment "[sc_pos getComment] $text"
        }
            
        # Add position score nag
        #
        sc_pos addNag [scoreToNag $score]
            
        # Add the variation
        #
        if { $skipEngineLine == 0 } {
            sc_move back
            if { $annotateBlunders == "blundersonly" } {
                # Add a diagram tag, but avoid doubles
                #
                if { [string first "D" "[sc_pos getNags]"] == -1 } {
                    sc_pos addNag "D"
                }
            }
            if { $prevmoves != "" && ( $annotateMoves == "all" || $annotateMoves == "white"  &&  $tomove == "black" ||
                                       $annotateMoves == "black"  &&  $tomove == "white" )} {
                sc_var create
                # Add the starting move
                sc_move_add [lrange $prevmoves 0 0] $n
                # Add its score
                if { ! $bestMoveIsMate } {
                    if { ! $::isShortAnnotation || $::addScoreToShortAnnotations } {
                        sc_pos setComment "$prevtext"
                    }
                }
                # Add remaining moves
                sc_move_add [lrange $prevmoves 1 end] $n
                # Add position NAG, unless the line ends in mate
                if { $analysis(prevscoremate$n) == 0 } {
                    sc_pos addNag [scoreToNag $prevscore]
                }
                sc_var exit
            }
            sc_move forward
        }
    } else {
        if { $isBlunder == 0 && $absdeltamove > $::informant(!?) } {
            sc_pos addNag "!?"
        }
        if { $scoreAllMoves } { 
            # Add a score mark anyway
            #
            sc_pos setComment "[sc_pos getComment] $text"
        }
    }
        
    if { $addClosingLine } {
        sc_move back
        sc_var create
        sc_move addSan $gamemove
        if { $analysis(scoremate$n) == 0 } {
            if { ! $::isShortAnnotation || $::addScoreToShortAnnotations } {
                sc_pos setComment "$text"
            }
        }
        sc_move_add $moves 1
        if { $analysis(scoremate$n) == 0 } {
            sc_pos addNag [scoreToNag $score]
        }
        sc_var exit
        # Now up to the end of the game
        ::move::Forward
    }
    
    set analysis(prevscore$n)     $analysis(score$n)
    set analysis(prevmoves$n)     $analysis(moves$n)
    set analysis(prevscoremate$n) $analysis(scoremate$n)
    set analysis(prevdepth$n)     $analysis(depth$n)

    updateBoard -pgn
}

# Informant index strings
array set ana_informantList { 0 "+=" 1 "+/-" 2 "+-" 3 "+--" }
# Nags. Note the slight inconsistency for the "crushing" symbol (see game.cpp)
array set ana_nagList  { 0 "=" 1 "+=" 2 "+/-" 3 "+-" 4 "+--" 5 "=" 6 "=+" 7 "-/+" 8 "-+" 9 "--+" }
################################################################################
# scoreToNag
# Visibility:
#   Public.
# Inputs:
#   - score (double): Evaluation score in pawns. Positive favours White.
# Returns:
#   - string: Informant-style evaluation symbol (NAG-like), e.g. "=", "+=", etc.
# Side effects:
#   - Reads global `::informant(...)` thresholds and the local maps
#     `ana_informantList` / `ana_nagList`.
################################################################################
proc scoreToNag {score} {
    global ana_informantList ana_nagList
    # Find the score in the informant map
    set tmp [expr { abs( $score ) }]
    for { set i 0 } { $i < 4 } { incr i } {
        if { $tmp < $::informant($ana_informantList($i)) } {
            break
        }
    }
    # Jump into negative counterpart
    if { $score < 0.0 } {
        set i [expr {$i + 5}]
    }
    return $ana_nagList($i)
}
################################################################################
# appendAnnotator
# Visibility:
#   Public.
# Inputs:
#   - s (string): Annotator identifier to add (e.g. engine name, mode description).
# Returns:
#   - None.
# Side effects:
#   - Reads/modifies the current game's "Extra" PGN tags via `sc_game tags ...`.
#   - Creates an "Annotator" tag if absent; otherwise appends to it.
################################################################################
proc appendAnnotator { s } {
    # Get the current collection of extra tags
    set extra [sc_game tags get "Extra"]

    set annot 0
    set other ""
    set nExtra {}
    # Walk through the extra tags, just copying the crap we do not need
    # If we meet the existing annotator tag, add our name to the list
    foreach line $extra {
        if { $annot == 1 } {
            lappend nExtra "Annotator \"$line, $s\"\n"
            set annot 2
        } elseif { $other != "" } {
            lappend nExtra "$other \"$line\"\n"
            set other ""
        } elseif {[string match "Annotator" $line]} {
            set annot 1
        } else {
            set other $line
        }
    }
    
    # First annotator: Create a tag
    if { $annot == 0 } {
        lappend nExtra "Annotator \"$s\"\n"
    }
    # Put the extra tags back to the game
    sc_game tags set -extra $nExtra
}
################################################################################
# pushAnalysisData
# Visibility:
#   Public.
# Inputs:
#   - lastVar (int): Variation index to be restored on pop.
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - list: The updated `::stack` list (Tcl returns the result of `lappend`).
# Side effects:
#   - Pushes analysis state onto the global `::stack`.
#   - Reads values from `analysis(...)`.
################################################################################
proc pushAnalysisData { { lastVar } { n 1 } } {
    global analysis
    lappend ::stack [list \
        $analysis(prevscore$n) \
        $analysis(prevscoremate$n) \
        $analysis(prevdepth$n) \
        $analysis(score$n) \
        $analysis(scoremate$n) \
        $analysis(depth$n) \
        $analysis(prevmoves$n) \
        $analysis(moves$n) \
        $lastVar \
    ]
}

################################################################################
# popAnalysisData
# Visibility:
#   Public.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - int|string: The `lastVar` value from the restored stack frame; empty
#     string if the stack is empty (also resets analysis state).
# Side effects:
#   - Pops from global `::stack` and restores multiple `analysis(...)` fields.
################################################################################
proc popAnalysisData { { n 1 } } {
    global analysis
    # the start of analysis is in the middle of a variation
    if {[llength $::stack] == 0} {
        set analysis(prevscore$n) 0
        set analysis(prevscoremate$n) 0
        set analysis(prevdepth$n) 0
        set analysis(score$n) 0
        set analysis(scoremate$n) 0
        set analysis(depth$n) 0
        set analysis(prevmoves$n) ""
        set analysis(moves$n) ""
        set lastVar 0
        return
    }
    set tmp [lindex $::stack end]
    set analysis(prevscore$n) [lindex $tmp 0]
    set analysis(prevscoremate$n) [lindex $tmp 1]
    set analysis(prevdepth$n) [lindex $tmp 2]
    set analysis(score$n) [lindex $tmp 3]
    set analysis(scoremate$n) [lindex $tmp 4]
    set analysis(depth$n) [lindex $tmp 5]
    set analysis(prevmoves$n) [lindex $tmp 6]
    set analysis(moves$n) [lindex $tmp 7]
    set lastVar [lindex $tmp 8]
    set ::stack [lreplace $::stack end end]
    return $lastVar
}

################################################################################
# addAnalysisVariation
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Creates a single variation from the current engine PV.
#   - Adds a score/depth comment at the start of the variation.
#   - May move backwards/forwards if the current position is at variation end.
#   - Notifies the UI via `::notify::PosChanged -pgn`.
################################################################################
proc addAnalysisVariation {{n 1}} {
    global analysis
    
    if {! [winfo exists .analysisWin$n]} { return }
    
    # Cannot add a variation to an empty variation:
    if {[sc_pos isAt vstart]  &&  [sc_pos isAt vend]} { return }
    
    # if we are at the end of the game, we cannot add variation
    # so we add the analysis one move before and append the last game move at the beginning of the analysis
    set addAtEnd [sc_pos isAt vend]

    set moves $analysis(moves$n)
    set tmp_moves [lindex [lindex $analysis(multiPV$n) 0] 2]
    set text [format "\[%s\] %d:%s" $analysis(name$n) $analysis(depth$n) [scoreToMate $analysis(score$n) $tmp_moves $n]]
    
    if {$addAtEnd} {
        # get the last move of the game
        set lastMove [sc_game info previousMoveUCI]
        #back one move
        sc_move back
    }
    
    # Add the variation:
    sc_var create
    # Add the comment at the start of the variation:
    sc_pos setComment "[sc_pos getComment] $text"
    if {$addAtEnd} {
        # Add the last move of the game at the beginning of the analysis
        sc_move_add $lastMove $n
    }
    # Add as many moves as possible from the engine analysis:
    sc_move_add $moves $n
    sc_var exit
    
    if {$addAtEnd} {
        #forward to the last move
        sc_move forward
    }

    ::notify::PosChanged -pgn
}
################################################################################
# addAllVariations
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Creates one variation per PV line in `analysis(multiPV...)`.
#   - Adds a score/depth comment at the start of each variation.
#   - May move backwards/forwards if the current position is at variation end.
#   - Notifies the UI via `::notify::PosChanged -pgn`.
################################################################################
proc addAllVariations {{n 1}} {
    global analysis
    
    if {! [winfo exists .analysisWin$n]} { return }
    
    # Cannot add a variation to an empty variation:
    if {[sc_pos isAt vstart]  &&  [sc_pos isAt vend]} { return }
    
    # if we are at the end of the game, we cannot add variation
    # so we add the analysis one move before and append the last game move at the beginning of the analysis
    set addAtEnd [sc_pos isAt vend]

    foreach i $analysis(multiPVraw$n) j $analysis(multiPV$n) {
        set moves [lindex $i 2]
        
        set tmp_moves [ lindex $j 2 ]
        set text [format "\[%s\] %d:%s" $analysis(name$n) [lindex $i 0] [scoreToMate [lindex $i 1] $tmp_moves $n]]
        
        if {$addAtEnd} {
            # get the last move of the game
            set lastMove [sc_game info previousMoveUCI]
            sc_move back
        }
        
        # Add the variation:
        sc_var create
        # Add the comment at the start of the variation:
        sc_pos setComment "[sc_pos getComment] $text"
        if {$addAtEnd} {
            # Add the last move of the game at the beginning of the analysis
            sc_move_add $lastMove $n
        }
        # Add as many moves as possible from the engine analysis:
        sc_move_add $moves $n
        sc_var exit
        
        if {$addAtEnd} {
            #forward to the last move
            sc_move forward
        }
        
    }

    ::notify::PosChanged -pgn
}

################################################################################
# makeAnalysisMove
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
#   - comment (string, optional): Comment text to append to the newly added move.
# Returns:
#   - int (0|1): 1 if a move was added, 0 if no move was available.
# Side effects:
#   - Adds the engine's current best move to the game (SAN or UCI).
#   - May append to the current position comment.
################################################################################
proc makeAnalysisMove {{n 1} {comment ""}} {
    regexp {[^[:alpha:]]*(.*?)( .*|$)} $::analysis(moves$n) -> move
    if {![info exists move]} { return 0 }

    ::addMoveUCI $move

    if {$comment != ""} {
        set tmp [sc_pos getComment]
        if {$tmp != ""} { lappend tmp " - " }
        sc_pos setComment "$tmp$comment"
    }

    return 1
}

################################################################################
# destroyAnalysisWin
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Stops the engine process and closes its pipes/logs.
#   - Cancels scheduled timers and destroys/updates related UI state.
#   - Resets engine state via `resetEngine`.
################################################################################
proc destroyAnalysisWin {{n 1}} {
    
    global analysis annotateMode
    
    if {$::finishGameMode} { toggleFinishGame }
    
    if { $n == 1 && $annotateMode } {
        cancelAutoplay
    }

    # Cancel scheduled commands
    if {$analysis(after$n) != ""} {
        after cancel $analysis(after$n)
    }
    
    # Check the pipe is not already closed:
    if {$analysis(pipe$n) == ""} {
        set ::analysisWin$n 0
        return
    }
    
    # Some engines in analyze mode may not react as expected to "quit"
    # so ensure the engine exits analyze mode first:
    sendToEngine $n "stop"
    sendToEngine $n "quit"
    catch { flush $analysis(pipe$n) }
    
    # Uncomment the following line to turn on blocking mode before
    # closing the engine (but probably not a good idea!)
    #   fconfigure $analysis(pipe$n) -blocking 1
    
    # Close the engine, ignoring any errors since nothing can really
    # be done about them anyway -- maybe should alert the user with
    # a message box?
    catch {close $analysis(pipe$n)}
    
    if {$analysis(log$n) != ""} {
        catch {close $analysis(log$n)}
        set analysis(log$n) ""
    }
    resetEngine $n
    set ::analysisWin$n 0
}

################################################################################
# sendToEngine
# Visibility:
#   Public.
# Inputs:
#   - n (int): Analysis engine slot (typically 1 or 2).
#   - text (string): Command line to send to the engine.
# Returns:
#   - int: Result of `catch` (0 on success, non-zero on error).
# Side effects:
#   - Writes to the engine pipe and logs the communication.
################################################################################
proc sendToEngine {n text} {
    # puts " -------- Scid>> $text"
    logEngine $n "Scid  : $text"
    catch {puts $::analysis(pipe$n) $text}
}

################################################################################
# sendMoveToEngine
# Visibility:
#   Internal.
# Inputs:
#   - n (int): Analysis engine slot.
#   - move (string): Move in coordinate notation (e.g. "e2e4" / "e7e8Q").
# Returns:
#   - None.
# Side effects:
#   - Sends the move to the engine (UCI).
#   - Reads state from `analysis(...)` and the current position (`sc_pos fen`).
################################################################################
proc sendMoveToEngine {n move} {
    # Convert "e7e8Q" into "e7e8q" since UCI requires lowercase promotion pieces.
    set move [string tolower $move]
    sendToEngine $n "position fen [sc_pos fen] moves $move"
}

################################################################################
# logEngine
# Visibility:
#   Public.
# Inputs:
#   - n (int): Analysis engine slot.
#   - text (string): Text line to log.
# Returns:
#   - None.
# Side effects:
#   - May write to stdout and/or to the engine log file.
#   - Updates `analysis(logCount$n)` and may close the log on size limit.
################################################################################
proc logEngine {n text} {
    global analysis
    
    # Print the log message to stdout if applicable:
    if {$::analysis(log_stdout)} {
        puts stdout $text
    }
    
    if { [ info exists ::analysis(log$n)] && $::analysis(log$n) != ""} {
        puts $::analysis(log$n) $text
        catch { flush $::analysis(log$n) }
        
        # Close the log file if the limit is reached:
        incr analysis(logCount$n)
        if {$analysis(logCount$n) >= $analysis(logMax)} {
            puts $::analysis(log$n) \
                    "NOTE  : Log file size limit reached; closing log file."
            catch {close $analysis(log$n)}
            set analysis(log$n) ""
        }
    }
}

################################################################################
# logEngineNote
# Visibility:
#   Public.
# Inputs:
#   - n (int): Analysis engine slot.
#   - text (string): Note content (without the "NOTE  :" prefix).
# Returns:
#   - None.
# Side effects:
#   - Delegates to `logEngine`.
################################################################################
proc logEngineNote {n text} {
    logEngine $n "NOTE  : $text"
}

################################################################################
# makeAnalysisWin
# Visibility:
#   Public.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
#   - index (int, optional): Engine index in `engines(list)`; -1 prompts the user.
#   - autostart (bool, optional): Whether to start analysis immediately (default 1).
# Returns:
#   - None.
# Side effects:
#   - Creates/destroys analysis window widgets.
#   - Starts/stops engine processes and initialises analysis state.
################################################################################
proc makeAnalysisWin { {n 1} {index -1} {autostart 1}} {
    global analysisWin$n font_Analysis analysisCommand analysis

    set w ".analysisWin$n"
    if {[winfo exists $w]} {
        focus .
        destroy $w
        return
    }

    resetEngine $n

    if { $index < 0 } {
        # engine selection dialog
        set index [::enginelist::choose]
        if { $index == "" ||  $index < 0 } { return }
        catch {
            ::enginelist::setTime $index
        }
    } else {
        # F2, F3
        set index [expr {$n - 1}]
    }

    set n_engines [llength $::engines(list)]
    if { $index >= $n_engines} {
        if { $n_engines > 0 } {
            tk_messageBox -message "Invalid Engine Number: [expr $index +1]"
            makeAnalysisWin $n -1
        }
        return
    }

    set engineData [lindex $::engines(list) $index]
    set analysisName [lindex $engineData 0]
    set analysisCommand [ toAbsPath [lindex $engineData 1] ]
    set analysisArgs [lindex $engineData 2]
    set analysisDir [ toAbsPath [lindex $engineData 3] ]
    set analysis(protocol$n) [lindex $engineData 7]
    
    # If the analysis directory is not current dir, cd to it:
    set oldpwd ""
    if {$analysisDir != "."} {
        set oldpwd [pwd]
        catch {cd $analysisDir}
    }

    # Try to execute the analysis program:
    set open_err [catch {set analysis(pipe$n) [open "| [list $analysisCommand] $analysisArgs" "r+"]}]

    # Return to original dir if necessary:
    if {$oldpwd != ""} { catch {cd $oldpwd} }

    if {$open_err} {
        tk_messageBox -title "Scid: error starting analysis" \
                -icon warning -type ok \
                -message "Unable to start the program:\n$analysisCommand"
        resetEngine $n
        return
    }
    
    # Open log file if applicable:
    set analysis(log$n) ""
    if {$analysis(logMax) > 0} {
        if {! [catch {open [file join $::scidLogDir "engine$n.log"] w} log]} {
            set analysis(log$n) $log
            logEngine $n "Scid-Engine communication log file"
            logEngine $n "Engine: $analysisName"
            logEngine $n "Command: $analysisCommand"
            logEngine $n "Date: [clock format [clock seconds]]"
            logEngine $n ""
            logEngine $n "This file was automatically generated by Scid."
            logEngine $n "It is rewritten every time an engine is started in Scid."
            logEngine $n ""
        }
    }
    
    set analysis(name$n) $analysisName
    
    # Configure pipe for line buffering and non-blocking mode:
    fconfigure $analysis(pipe$n) -buffering line -blocking 0
    
    #
    # Set up the  analysis window:
    #
    ::createToplevel $w
    set analysisWin$n 1
    if {$n == 1} {
        ::setTitle $w "Analysis: $analysisName"
    } else {
        ::setTitle $w "Analysis $n: $analysisName"
    }
    bind $w <F1> { helpWindow Analysis }
    
    ::board::new $w.bd 25
    $w.bd configure -relief solid -borderwidth 1
    ::applyThemeColor_background $w
    set analysis(showBoard$n) 0
    set analysis(showEngineInfo$n) 0
    
    ttk::frame $w.b1
    pack $w.b1 -side bottom -fill x
    ttk::button $w.b1.automove -image tb_training  -command [list toggleAutomove $n]
    ::utils::tooltip::Set $w.b1.automove $::tr(Training)
    
    ttk::button $w.b1.lockengine -image tb_lockengine -command [list toggleLockEngine $n]
    ::utils::tooltip::Set $w.b1.lockengine $::tr(LockEngine)
    .analysisWin$n.b1.lockengine configure -state disabled
    
    ttk::button $w.b1.line -image tb_addvar -command [list addAnalysisVariation $n]
    ::utils::tooltip::Set $w.b1.line $::tr(AddVariation)
    
    ttk::button $w.b1.alllines -image tb_addallvars -command [list addAllVariations $n]
    ::utils::tooltip::Set $w.b1.alllines $::tr(AddAllVariations)
    
    ttk::button $w.b1.move -image tb_addmove -command [list makeAnalysisMove $n]
    ::utils::tooltip::Set $w.b1.move $::tr(AddMove)

    ttk::spinbox $w.b1.multipv -from 1 -to 8 -increment 1 -textvariable analysis(multiPVCount$n) -state disabled -width 2 \
            -command [list apply {{n val} {
                after idle [list changePVSize $n $val]
            } ::} $n]
    ::utils::tooltip::Set $w.b1.multipv $::tr(Lines)
    
    # add a button to start/stop engine analysis
    ttk::button $w.b1.bStartStop -image tb_eng_on -command [list toggleEngineAnalysis $n]
    ::utils::tooltip::Set $w.b1.bStartStop "$::tr(StartEngine) (F[expr 3 + $n])"

    if {$n == 1} {
        set ::finishGameMode 0
        ttk::button $w.b1.bFinishGame -image tb_finish_off -command [list toggleFinishGame $n]
        ::utils::tooltip::Set $w.b1.bFinishGame $::tr(FinishGame)
    }
    ttk::button $w.b1.showboard -image tb_coords -command [list toggleAnalysisBoard $n]
    ::utils::tooltip::Set $w.b1.showboard $::tr(ShowAnalysisBoard)
    
    ttk::button $w.b1.showinfo -image tb_engineinfo -command [list toggleEngineInfo $n]
    ::utils::tooltip::Set $w.b1.showinfo $::tr(ShowInfo)
    
    if {$n == 1} {
        ttk::button $w.b1.annotate -command [list configAnnotation] \
            -image [list tb_annotate pressed tb_annotate_on]
        ::utils::tooltip::Set $w.b1.annotate $::tr(Annotate...)
    }
    ttk::button $w.b1.priority -image tb_cpu_hi -command [list setAnalysisPriority $w $n]
    ::utils::tooltip::Set $w.b1.priority $::tr(LowPriority)
    
    ttk::button $w.b1.help -image tb_help -command { helpWindow Analysis }
    ::utils::tooltip::Set $w.b1.help $::tr(Help)
    
    pack $w.b1.bStartStop $w.b1.lockengine $w.b1.move $w.b1.line $w.b1.alllines -side left
    if {$n ==1} {
        pack $w.b1.multipv $w.b1.annotate $w.b1.automove $w.b1.bFinishGame -side left
    } else  {
        pack $w.b1.multipv $w.b1.automove -side left
    }
    pack $w.b1.help $w.b1.priority $w.b1.showboard -side right
    pack $w.b1.showinfo -side right
    text $w.text
    applyThemeStyle Treeview $w.text
    $w.text configure -width 60 -height 1 -font font_Bold -wrap word -setgrid 1 ;# -spacing3 2
    autoscrollText y $w.hist $w.hist.text Treeview
    $w.hist.text configure -wrap word -state normal -width 60 -height 8 -font font_Fixed -setgrid 1
    $w.hist.text tag configure indent -lmargin2 [font measure font_Fixed "xxxxxxxxxxxx"]
    pack $w.text -side top -fill both
    pack $w.hist -side top -expand 1 -fill both
    
    bind $w.hist.text <ButtonPress-$::MB3> "toggleMovesDisplay $n"
    $w.text tag configure blue -foreground DodgerBlue3
    $w.text tag configure bold -font font_Bold
    $w.text tag configure small -font font_Small
    $w.hist.text tag configure blue -foreground DodgerBlue3 -lmargin2 [font measure font_Fixed "xxxxxxxxxxxx"]
    $w.hist.text tag configure gray -foreground gray
    if {$autostart != 0} {
    $w.text insert end "Please wait a few seconds for engine initialisation (with some engines, you will not see any analysis \
            until the board changes. So if you see this message, try changing the board \
            by moving backward or forward or making a new move.)" small
    }
    $w.text configure -state disabled
    bind $w <Destroy> "if {\[string equal $w %W\]} { destroyAnalysisWin $n }"
    bind $w <Escape> "focus .; destroy $w"
    bind $w <Key-a> "$w.b1.bStartStop invoke"
    wm minsize $w 25 0
    ::createToplevelFinalize $w

    set analysis(onUciOk$n) "onUciOk $n $w.b1.multipv $autostart [list [ lindex $engineData 8 ]]"
    fileevent $analysis(pipe$n) readable "::uci::processAnalysisInput $n"
    after 1000 "checkAnalysisStarted $n"

    catch {
        ::enginelist::sort
        ::enginelist::write
    }
    
}

################################################################################
# onUciOk
# Visibility:
#   Public.
# Inputs:
#   - n (int, optional): Analysis engine slot.
#   - multiPv_spin (widget, optional): Tk spinbox for MultiPV.
#   - autostart (bool, optional): Whether to start analysis once the engine is ready.
#   - uci_options (list, optional): Initial UCI options to apply (as provided by config).
# Returns:
#   - None.
# Side effects:
#   - Configures the MultiPV spinbox range, initialises `::uciOptions$n`,
#     and sends UCI options to the engine.
#   - May schedule a `startEngineAnalysis` via `::uci::whenReady`.
################################################################################
proc onUciOk {{n} {multiPv_spin} {autostart} {uci_options}} {
    foreach opt $::analysis(uciOptions$n) {
        if { [lindex $opt 0] == "MultiPV" } {
            set min [lindex $opt 1]
            set max [lindex $opt 2]
            $multiPv_spin configure -from $min -to $max -state normal
            break
        }
    }
    foreach {option} $uci_options {
        array set ::uciOptions$n $option
    }
    ::uci::sendUCIoptions $n
    if {$autostart} {
        ::uci::whenReady $n [list startEngineAnalysis $n]
    }
}



################################################################################
# toggleMovesDisplay
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Toggles whether PV moves are displayed in the history widget and refreshes
#     the analysis text.
################################################################################
proc toggleMovesDisplay { {n 1} } {
    set ::analysis(movesDisplay$n) [expr 1 - $::analysis(movesDisplay$n)]
    set h .analysisWin$n.hist.text
    $h configure -state normal
    $h delete 1.0 end
    $h configure -state disabled
    updateAnalysisText $n
}

################################################################################
# changePVSize
# Visibility:
#   Public.
# Inputs:
#   - n (int): Analysis engine slot.
# Returns:
#   - None.
# Side effects:
#   - Adjusts stored MultiPV lines in `analysis(multiPV...)` / `analysis(multiPVraw...)`.
#   - Updates the history widget and sends the engine an updated MultiPV setting.
################################################################################
proc changePVSize { n } {
    global analysis
    if { $analysis(multiPVCount$n) < [llength $analysis(multiPV$n)] } {
        set analysis(multiPV$n) {}
        set analysis(multiPVraw$n) {}
    }
    set h .analysisWin$n.hist.text
    if {[winfo exists $h] && $analysis(multiPVCount$n) == 1} {
        $h configure -state normal
        $h delete 0.0 end
        $h configure -state disabled
        set analysis(lastHistory$n) {}
    }

    array set ::uciOptions$n [list "MultiPv" "$analysis(multiPVCount$n)"]
    ::uci::sendUCIoptions $n
    if {$analysis(analyzeMode$n)} {
        ::uci::whenReady $n [list updateAnalysis $n]
    }
}
################################################################################
# setAnalysisPriority
# Visibility:
#   Internal.
# Inputs:
#   - w (widget): Analysis window to update (expects `$w.b1.priority`).
#   - n (int): Analysis engine slot.
# Returns:
#   - None.
# Side effects:
#   - Attempts to adjust engine process priority via `sc_info priority`.
#   - Updates the priority button state and image.
################################################################################
proc setAnalysisPriority {w n} {
    global analysis
    
    # Get the process ID of the analysis engine:
    if {$analysis(pipe$n) == ""} { return }
    set pidlist [pid $analysis(pipe$n)]
    if {[llength $pidlist] < 1} { return }
    set pid [lindex $pidlist 0]
    
    # Set the priority class (idle or normal):
    set priority "normal"
    if {[lindex [$w.b1.priority configure -image] end] eq "tb_cpu_hi"} { set priority "idle" }
    catch {sc_info priority $pid $priority}
    
    # Re-read the priority class for confirmation:
    if {[catch {sc_info priority $pid} newpriority]} { return }
    if {$newpriority > 0} {
        $w.b1.priority configure -image tb_cpu
        $w.b1.priority state pressed
    } else {
        $w.b1.priority configure -image tb_cpu_hi
        $w.b1.priority state !pressed
    }
 }
################################################################################
# checkAnalysisStarted
# Visibility:
#   Public.
# Inputs:
#   - n (int): Analysis engine slot.
# Returns:
#   - None.
# Side effects:
#   - Sends initial protocol commands if the engine has not produced output.
#   - Writes `analysis(seen$n)` and logs a note via `logEngineNote`.
################################################################################
proc checkAnalysisStarted {n} {
    global analysis
    if {$analysis(seen$n)} { return }

    logEngineNote $n {Quiet engine (still no output); sending it initial commands.}
    sendToEngine $n "uci"
    set analysis(seen$n) 1
}
################################################################################
# checkEngineIsAlive
# Visibility:
#   Public.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - int (0|1): 0 if the engine pipe reached EOF / closed, otherwise 1.
# Side effects:
#   - May close the engine pipe, log notes, show a message box, and destroy
#     the analysis window.
################################################################################
proc checkEngineIsAlive { {n 1} } {
    global analysis

    if {$analysis(pipe$n) == ""} { return 0 }
    
    if {[eof $analysis(pipe$n)]} {
        fileevent $analysis(pipe$n) readable {}
        set exit_status 0
        if {[catch {close $analysis(pipe$n)} standard_error] != 0} {
            global errorCode
            if {"CHILDSTATUS" == [lindex $errorCode 0]} {
                set exit_status [lindex $errorCode 2]
            }
        }
        set analysis(pipe$n) ""
        if { $exit_status != 0 } {
            logEngineNote $n {Engine terminated with exit code $exit_status: "\"$standard_error\""}
            tk_messageBox -type ok -icon info -parent . -title "Scid" \
                          -message "The analysis engine terminated with exit code $exit_status: \"$standard_error\""
        } else {
            logEngineNote $n {Engine terminated without exit code: "\"$standard_error\""}
            tk_messageBox -type ok -icon info -parent . -title "Scid" \
                          -message "The analysis engine terminated without exit code: \"$standard_error\""
        }
        catch {destroy .analysisWin$n}
        return 0
    }
    return 1
}
set finishGameMode 0

################################################################################
# toggleFinishGame
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Toggles "finish game" mode, starts/stops engine(s), and updates UI state.
#   - Creates and shows the configuration dialog for UCI engines.
################################################################################
proc toggleFinishGame { { n 1 } } {
	global analysis
	set b ".analysisWin$n.b1.bFinishGame"
	if { $::autoplayMode } { return }

	# UCI engines
	# Default values
	if {! [info exists ::finishGameEng1] } { set ::finishGameEng1 1 }
	if {! [info exists ::finishGameEng2] } { set ::finishGameEng2 1 }
	if {! [info exists ::finishGameCmd1] } { set ::finishGameCmd1 "movetime" }
	if {! [info exists ::finishGameCmdVal1] } { set ::finishGameCmdVal1 5 }
	if {! [info exists ::finishGameCmd2] } { set ::finishGameCmd2 "movetime" }
	if {! [info exists ::finishGameCmdVal2] } { set ::finishGameCmdVal2 5 }
	if {! [info exists ::finishGameAnnotate] } { set ::finishGameAnnotate 1 }
	if {! [info exists ::finishGameAnnotateShort] } { set ::finishGameAnnotateShort 1 }
	# On exit save values in options.dat
	::options.store ::finishGameEng1
	::options.store ::finishGameEng2
	::options.store ::finishGameCmd1
	::options.store ::finishGameCmdVal1
	::options.store ::finishGameCmd2
	::options.store ::finishGameCmdVal2
	::options.store ::finishGameAnnotate
	::options.store ::finishGameAnnotateShort

	if {$::finishGameMode} {
		set ::finishGameMode 0
		sendToEngine 1 "stop"
		set analysis(waitForReadyOk1) 0
		set analysis(waitForBestMove1) 0
		sendToEngine 2 "stop"
		set analysis(waitForReadyOk2) 0
		set analysis(waitForBestMove2) 0
		$b configure -image tb_finish_off
		grab release .analysisWin$n
		.analysisWin$n.b1.bStartStop configure -state normal
		.analysisWin$n.b1.move configure -state normal
		.analysisWin$n.b1.line configure -state normal
		.analysisWin$n.b1.alllines configure -state normal
		.analysisWin$n.b1.annotate configure -state normal
		.analysisWin$n.b1.automove configure -state normal
		return
	}

	set w .configFinishGame
	win::createDialog $w
	wm resizable $w 0 0
	::setTitle $w "Scid: $::tr(FinishGame)"

	ttk::labelframe $w.wh_f -text "$::tr(White)" -padding 5
	grid $w.wh_f -column 0 -row 0 -columnspan 2 -sticky we -pady 8
	foreach psize $::boardSizes {
		if {$psize >= 40} { break }
	}
	ttk::label $w.wh_f.p -image wk$psize
	grid $w.wh_f.p -column 0 -row 0 -rowspan 3
	ttk::radiobutton $w.wh_f.e1 -text $analysis(name1) -variable ::finishGameEng1 -value 1
	if {[winfo exists .analysisWin2]} {
		ttk::radiobutton $w.wh_f.e2 -text $analysis(name2) -variable ::finishGameEng1 -value 2
	} else {
		set ::finishGameEng1 1
		ttk::radiobutton $w.wh_f.e2 -text $::tr(StartEngine) -variable ::finishGameEng1 -value 2 -state disabled
	}
	grid $w.wh_f.e1 -column 1 -row 0 -columnspan 3 -sticky w
	grid $w.wh_f.e2 -column 1 -row 1 -columnspan 3 -sticky w
	ttk::spinbox $w.wh_f.cv -width 3 -textvariable ::finishGameCmdVal1 -from 1 -to 999 -justify right
	ttk::radiobutton $w.wh_f.c1 -text $::tr(seconds) -variable ::finishGameCmd1 -value "movetime"
	ttk::radiobutton $w.wh_f.c2 -text $::tr(FixedDepth) -variable ::finishGameCmd1 -value "depth"
	grid $w.wh_f.cv -column 1 -row 2 -sticky w
	grid $w.wh_f.c1 -column 2 -row 2 -sticky w -padx 6
	grid $w.wh_f.c2 -column 3 -row 2 -sticky w

	ttk::labelframe $w.bk_f -text "$::tr(Black)" -padding 5
	grid $w.bk_f -column 0 -row 1 -columnspan 2 -sticky we -pady 8
	ttk::label $w.bk_f.p -image bk$psize
	grid $w.bk_f.p -column 0 -row 0 -rowspan 3
	ttk::radiobutton $w.bk_f.e1 -text $analysis(name1) -variable ::finishGameEng2 -value 1
	if {[winfo exists .analysisWin2]} {
		ttk::radiobutton $w.bk_f.e2 -text $analysis(name2) -variable ::finishGameEng2 -value 2
	} else {
		set ::finishGameEng2 1
		ttk::radiobutton $w.bk_f.e2 -text $::tr(StartEngine) -variable ::finishGameEng2 -value 2 -state disabled
	}
	grid $w.bk_f.e1 -column 1 -row 0 -columnspan 3 -sticky w
	grid $w.bk_f.e2 -column 1 -row 1 -columnspan 3 -sticky w
	ttk::spinbox $w.bk_f.cv -width 3 -textvariable ::finishGameCmdVal2 -from 1 -to 999 -justify right
	ttk::radiobutton $w.bk_f.c1 -text $::tr(seconds) -variable ::finishGameCmd2 -value "movetime"
	ttk::radiobutton $w.bk_f.c2 -text $::tr(FixedDepth) -variable ::finishGameCmd2 -value "depth"
	grid $w.bk_f.cv -column 1 -row 2 -sticky w
	grid $w.bk_f.c1 -column 2 -row 2 -sticky w -padx 6
	grid $w.bk_f.c2 -column 3 -row 2 -sticky w

	ttk::checkbutton $w.annotate -text $::tr(Annotate) -variable ::finishGameAnnotate
	grid $w.annotate -column 0 -row 2 -sticky w -padx 5 -pady 8
	ttk::checkbutton $w.annotateShort -text $::tr(ShortAnnotations) -variable ::finishGameAnnotateShort
	grid $w.annotateShort -column 1 -row 2 -sticky w -padx 5 -pady 8

	ttk::frame $w.fbuttons
	ttk::button $w.fbuttons.cancel -text $::tr(Cancel) -command { destroy .configFinishGame }
	ttk::button $w.fbuttons.ok -text "OK" -command {
		if {$::finishGameEng1 == $::finishGameEng2} {
			set ::finishGameMode 1
		} else {
			set ::finishGameMode 2
		}
		set tmp [sc_pos getComment]
		sc_pos setComment "$tmp $::tr(FinishGame) $::tr(White): $analysis(name$::finishGameEng1) $::tr(Black): $analysis(name$::finishGameEng2)"
		destroy .configFinishGame
	}
	packbuttons right $w.fbuttons.cancel $w.fbuttons.ok
	grid $w.fbuttons -row 3 -column 1 -columnspan 2 -sticky we
	focus $w.fbuttons.ok
	bind $w <Escape> { .configFinishGame.cancel invoke }
	bind $w <Return> { .configFinishGame.ok invoke }
	bind $w <Destroy> { focus .analysisWin1 }
	::tk::PlaceWindow $w widget .analysisWin1
	grab $w
	bind $w <ButtonPress> {
		set w .configFinishGame
		if {%x < 0 || %x > [winfo width $w] || %y < 0 || %y > [winfo height $w] } { ::tk::PlaceWindow $w pointer }
	}
	tkwait window $w
	if {!$::finishGameMode} { return }

	set gocmd(1) "go $::finishGameCmd1 $::finishGameCmdVal1"
	set gocmd(2) "go $::finishGameCmd2 $::finishGameCmdVal2"
	if {$::finishGameCmd1 == "movetime" } { append gocmd(1) "000" }
	if {$::finishGameCmd2 == "movetime" } { append gocmd(2) "000" }
	if {[sc_pos side] == "white"} {
		set current_cmd 1
		set current_engine $::finishGameEng1
	} else {
		set current_cmd 2
		set current_engine $::finishGameEng2
	}

	stopEngineAnalysis 1
	stopEngineAnalysis 2
	$b configure -image tb_finish_on
	.analysisWin$n.b1.bStartStop configure -state disabled
	.analysisWin$n.b1.move configure -state disabled
	.analysisWin$n.b1.line configure -state disabled
	.analysisWin$n.b1.alllines configure -state disabled
	.analysisWin$n.b1.annotate configure -state disabled
	.analysisWin$n.b1.automove configure -state disabled
	grab .analysisWin$n

	while { [string index [sc_game info previousMove] end] != "#"} {
		set analysis(waitForReadyOk$current_engine) 1
		sendToEngine $current_engine "isready"
		vwait analysis(waitForReadyOk$current_engine)
		if {!$::finishGameMode} { break }
		sendToEngine $current_engine "position fen [sc_pos fen]"
		sendToEngine $current_engine $gocmd($current_cmd)
		set analysis(fen$current_engine) [sc_pos fen]
		set analysis(maxmovenumber$current_engine) 0
		set analysis(waitForBestMove$current_engine) 1
		vwait analysis(waitForBestMove$current_engine)
		if {!$::finishGameMode} { break }

		if { ! [sc_pos isAt vend] } { sc_var create }
		if {$::finishGameAnnotate} {
			set moves [ lindex [ lindex $analysis(multiPV$current_engine) 0 ] 2 ]
			if {$::finishGameAnnotateShort} {
				set text [format "%d:%+.2f" \
					$analysis(depth$current_engine) \
					$analysis(score$current_engine) ]
				makeAnalysisMove $current_engine $text
			} else {
				set text [format "%d:%+.2f" \
					$analysis(depth$current_engine) \
					$analysis(score$current_engine) ]
				makeAnalysisMove $current_engine $text
				sc_var create
				set moves $analysis(moves$current_engine)
				sc_move_add $moves $current_engine
				sc_var exit
				sc_move forward
			}
			storeEmtComment 0 0 [expr {int($analysis(time$current_engine))}]
		} else {
			makeAnalysisMove $current_engine
		}

		incr current_cmd
		if {$current_cmd > 2} { set current_cmd 1 }
		if {$::finishGameMode == 2} {
			incr current_engine
			if {$current_engine > 2 } { set current_engine 1 }
		}
	}
	if {$::finishGameMode} { toggleFinishGame }
}
################################################################################
# autoplayFinishGame
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Invokes the engine move action periodically until the game ends.
#   - Stops finish-game mode when mate is reached.
################################################################################
proc autoplayFinishGame { {n 1} } {
    if {!$::finishGameMode || ![winfo exists .analysisWin$n]} {return}
    .analysisWin$n.b1.move invoke
    if { [string index [sc_game info previousMove] end] == "#"} {
        toggleFinishGame $n
        return
    }
    after $::autoplayDelay autoplayFinishGame
}

################################################################################
# startEngineAnalysis
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
#   - force (bool, optional): Force start even in situations where it is usually
#     blocked (default 0).
# Returns:
#   - None.
# Side effects:
#   - Starts analyse mode, updates UI button state, and enables lock controls.
################################################################################
proc startEngineAnalysis { {n 1} {force 0} } {
    global analysis
    
    if { !$analysis(analyzeMode$n) } {
        set b ".analysisWin$n.b1.bStartStop"
        
        startAnalyzeMode $n $force
        $b configure -image tb_eng_off
        ::utils::tooltip::Set $b "$::tr(StopEngine)(a)"
        # enable lock button
        .analysisWin$n.b1.lockengine configure -state normal
    }
}

################################################################################
# stopEngineAnalysis
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Stops analyse mode, updates UI button state, and disables lock controls.
################################################################################
proc stopEngineAnalysis { {n 1} } {
    global analysis
    
    if { $analysis(analyzeMode$n) } {
        set b ".analysisWin$n.b1.bStartStop"

        stopAnalyzeMode $n
        $b configure -image tb_eng_on
        ::utils::tooltip::Set $b "$::tr(StartEngine)"
        # reset lock mode and disable lock button
        set analysis(lockEngine$n) 1
        toggleLockEngine $n
        .analysisWin$n.b1.lockengine configure -state disabled
    }
}

################################################################################
# toggleEngineAnalysis
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
#   - force (bool, optional): Force toggle even while annotating/finishing (default 0).
# Returns:
#   - None.
# Side effects:
#   - Starts or stops engine analysis depending on current state.
################################################################################
proc toggleEngineAnalysis { { n 1 } { force 0 } } {
    global analysis
    
    if { $n == 1} {
        if { ($::annotateMode || $::finishGameMode) && ! $force } {
            return
        }
    }
    
    if {$analysis(analyzeMode$n)} {
        stopEngineAnalysis $n
    } else  {
        startEngineAnalysis $n $force
    }
}
################################################################################
# startAnalyzeMode
# Visibility:
#   Public.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
#   - force (bool, optional): Start even if already in analyse mode (default 0).
# Returns:
#   - None.
# Side effects:
#   - Updates `analysis(analyzeMode$n)` and sends protocol commands to the engine.
#   - Triggers `updateAnalysis` to refresh analysis state.
################################################################################
proc startAnalyzeMode {{n 1} {force 0}} {
    global analysis

    # Check that the engine has not already had analyze mode started:
    if {$analysis(analyzeMode$n) && ! $force } { return }
    set analysis(analyzeMode$n) 1
    updateAnalysis $n
}
################################################################################
# stopAnalyzeMode
# Visibility:
#   Public.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Sends stop/exit to the engine and clears `analysis(fen$n)`.
#   - Updates `analysis(analyzeMode$n)`.
################################################################################
proc stopAnalyzeMode { {n 1} } {
    global analysis
    if {! $analysis(analyzeMode$n)} { return }
    set analysis(analyzeMode$n) 0
    ::uci::sendStop $n
    set analysis(fen$n) {}
}
################################################################################
# toggleLockEngine
# Visibility:
#   Internal.
# Inputs:
#   - n (int): Analysis engine slot.
# Returns:
#   - None.
# Side effects:
#   - Toggles lock mode for the engine and updates UI widget states.
#   - Captures the current move number/side when locking.
#   - Triggers `updateAnalysis`.
################################################################################
proc toggleLockEngine {n} {
    global analysis
    if { $analysis(lockEngine$n) } {
	set analysis(lockEngine$n) 0
    } else {
	set analysis(lockEngine$n) 1
    }
    if { $analysis(lockEngine$n) } {
        set state disabled
        set analysis(lockN$n) [sc_pos moveNumber]
        set analysis(lockSide$n) [sc_pos side]
	.analysisWin$n.b1.lockengine state pressed
    } else {
        set state normal
	.analysisWin$n.b1.lockengine state !pressed
    }
    set w ".analysisWin$n"
    $w.b1.move configure -state $state
    $w.b1.line configure -state $state
    $w.b1.multipv configure -state $state
    $w.b1.alllines configure -state $state
    $w.b1.automove configure -state $state
    if { $n == 1 } {
        $w.b1.annotate configure -state $state
        $w.b1.bFinishGame configure -state $state
    }
    updateAnalysis $n
}
################################################################################
# updateAnalysisText
# Visibility:
#   Public.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Updates analysis window widgets and the evaluation bar.
#   - Reads many fields from `analysis(...)` and may format MultiPV output.
################################################################################
proc updateAnalysisText {{n 1}} {
    global analysis
    
    set nps 0
    if {$analysis(currmovenumber$n) > $analysis(maxmovenumber$n) } {
        set analysis(maxmovenumber$n) $analysis(currmovenumber$n)
    }
    if {$analysis(time$n) > 0.0} {
        set nps [expr {round($analysis(nodes$n) / $analysis(time$n))} ]
    }
    set score $analysis(score$n)
    # Show score only from one engine. Engine1 has priority
    if { $n == 1 || ( $n == 2 && (! [winfo exists .analysisWin1 ] || ! $analysis(analyzeMode1) )) } {
        ::board::updateEvalBar .main.board $::analysis(score$n)
    }
    set t .analysisWin$n.text
    set h .analysisWin$n.hist.text
    
    $t configure -state normal
    $t delete 0.0 end
    
    if { [expr abs($score)] >= 327.0 } {
        if { [catch { set tmp [format "M%d " $analysis(scoremate$n)]} ] } {
            set tmp [format "%+.1f " $score]
        }
    } else {
        set tmp [format "%+.1f " $score]
    }
    $t insert end $tmp
    
    $t insert end "[tr Depth]: "
    if {$analysis(showEngineInfo$n) && $analysis(seldepth$n) != 0} {
        $t insert end [ format "%2u/%u " $analysis(depth$n) $analysis(seldepth$n)] small
    } else {
        $t insert end [ format "%2u " $analysis(depth$n) ] small
    }
    $t insert end "[tr Nodes]: "
    $t insert end [ format "%6uK (%u kn/s) " $analysis(nodes$n) $nps ] small
    $t insert end "[tr Time]: "
    $t insert end [ format "%6.2f s" $analysis(time$n) ] small
    if {$analysis(showEngineInfo$n)} {
        $t insert end "\n" small
        $t insert end "[tr Current]: "
        $t insert end [ format "%s (%s/%s) " [::trans $analysis(currmove$n)] $analysis(currmovenumber$n) $analysis(maxmovenumber$n)] small
        $t insert end "TB Hits: "
        $t insert end [ format "%u " $analysis(tbhits$n)] small
        $t insert end "Nps: "
        $t insert end [ format "%u n/s " $analysis(nps$n)] small
        $t insert end "Hash Full: "
        set hashfull [expr {round($analysis(hashfull$n) / 10)}]
        $t insert end [ format "%u%% " $hashfull ] small
        $t insert end "CPU Load: "
        set cpuload [expr {round($analysis(cpuload$n) / 10)}]
        $t insert end [ format "%u%% " $cpuload ] small
        
        #$t insert end [ format "\nCurrent: %s (%s) - Hashfull: %u - nps: %u - TBhits: %u - CPUload: %u" $analysis(currmove$n) $analysis(currmovenumber$n) $analysis(hashfull$n) $analysis(nps$n) $analysis(tbhits$n) $analysis(cpuload$n) ]
    }
    
    
	    if {$analysis(automove$n)} {
	        if {$analysis(automoveThinking$n)} {
	            set moves "   Thinking..... "
	        } else {
	            set moves "   Your move..... "
	        }
	        $t insert end $moves blue
	        $t configure -state disabled
	        updateAnalysisBoard $n ""
	        return
	    }
    
    if {! $::analysis(movesDisplay$n)}  {
        $h configure -state normal
        $h delete 0.0 end
        $h insert end "     $::tr(ClickHereToSeeMoves)\n" blue
        updateAnalysisBoard $n ""
        $h configure -state disabled
        return
    }
    
	    set moves [lindex [lindex $analysis(multiPV$n) 0] 2]
    
    $h configure -state normal
    set cleared 0
    if { $analysis(depth$n) < $analysis(prev_depth$n)  || $analysis(prev_depth$n) == 0 } {
        $h delete 1.0 end
        set cleared 1
    }
    
    ################################################################################
	    if {$cleared} { set analysis(multiPV$n) {} ; set analysis(multiPVraw$n) {} }
	    if {$analysis(multiPVCount$n) == 1} {
	        set newhst [format "%2d %s %s" $analysis(depth$n) [scoreToMate $score $moves $n] [addMoveNumbers $n [::trans $moves]]]
	        if {$newhst != $analysis(lastHistory$n) && $moves != ""} {
	            $h insert end [format "%s (%.2f)\n" $newhst $analysis(time$n)] indent
	            $h see end-1c
	            set analysis(lastHistory$n) $newhst
	        }
	    } else {
	        $h delete 1.0 end
	        # First line
	        set pv [lindex $analysis(multiPV$n) 0]
	        if { $pv != "" } {
	            catch { set newStr [format "%2d %s " [lindex $pv 0] [scoreToMate $score [lindex $pv 2] $n] ] }
	        
	            $h insert end "1 " gray
	            append newStr "[addMoveNumbers $n [::trans [lindex $pv 2]]] [format (%.2f)\n [lindex $pv 4]]"
	            $h insert end $newStr blue
	        
	            set lineNumber 1
	            foreach pv $analysis(multiPV$n) {
	                if {$lineNumber == 1} { incr lineNumber ; continue }
	                $h insert end "$lineNumber " gray
	                set score [scoreToMate [lindex $pv 1] [lindex $pv 2] $n]
	                $h insert end [format "%2d %s %s (%.2f)\n" [lindex $pv 0] $score [addMoveNumbers $n [::trans [lindex $pv 2]]] [lindex $pv 4]] indent
	                incr lineNumber
	            }
	        }
	    }
    
	    $h configure -state disabled
	    set analysis(prev_depth$n) $analysis(depth$n)
	    # $t tag add score 2.0 2.13
	    $t configure -state disabled
    
    updateAnalysisBoard $n $analysis(moves$n)
}
################################################################################
# scoreToMate
# Visibility:
#   Public.
# Inputs:
#   - score (double): Evaluation score in pawns (used when not mate).
#   - pv (list|string): PV moves; mate detection uses a trailing `#` or `++`.
#   - n (int): Analysis engine slot (for lock state).
# Returns:
#   - string: "M<sign><plies>" when mate is detected, otherwise a formatted score.
# Side effects:
#   - Reads `analysis(lockEngine$n)` and queries `sc_pos side` for sign logic.
################################################################################
proc scoreToMate { score pv n } {
    
    if {$::analysis(lockEngine$n)} {
        return [format "%+5.2f" $score]
    }
    
    if { [string index $pv end] == "#" || [string index $pv end] == "+" && [string index $pv end-1] == "+"} {
        set plies [llength $pv]
        
        set mate [expr $plies / 2 + 1 ]
        
        set sign ""
        if {[expr $plies % 2] == 0 && [sc_pos side] == "white" || [expr $plies % 2] == 1 && [sc_pos side] == "black"} {
            set sign "-"
        }
        if {[sc_pos side] == "white" } {
            if { $sign == "" } {
                set mate [expr $plies / 2 + 1 ]
            } else  {
                set mate [expr $plies / 2 ]
            }
        } else  {
            if { $sign == "" } {
                set mate [expr $plies / 2 ]
            } else  {
                set mate [expr $plies / 2 + 1 ]
            }
        }
        
        set ret "M$sign$mate"
    } else  {
        set ret [format "%+5.2f" $score]
    }
    
    return $ret
}
################################################################################
# addMoveNumbers
# Visibility:
#   Public.
# Inputs:
#   - e (int): Analysis engine slot (used for lock state).
#   - pv (list): List of SAN moves (already translated if desired).
# Returns:
#   - string: PV with move numbers inserted, respecting `::pgn::moveNumberSpaces`.
# Side effects:
#   - Reads `analysis(lockEngine$e)`; if locked, uses `analysis(lockN$e)` and
#     `analysis(lockSide$e)`, otherwise queries `sc_pos`.
################################################################################
proc addMoveNumbers { e pv } {
    global analysis

    if { $analysis(lockEngine$e) } {
      set n $analysis(lockN$e)
      set turn $analysis(lockSide$e)
    } else {
      set n [sc_pos moveNumber]
      set turn [sc_pos side]
    }

    if {$::pgn::moveNumberSpaces} {
      set spc { }
    } else {
      set spc {}
    }

    set ret ""
    set start 0
    if {$turn == "black"} {
        set ret "$n.$spc... [lindex $pv 0] "
        incr start
        incr n
    }
    for {set i $start} {$i < [llength $pv]} {incr i} {
        set m [lindex $pv $i]
        if { [expr $i % 2] == 0 && $start == 0 || [expr $i % 2] == 1 && $start == 1 } {
            append ret "$n.$spc$m "
        } else  {
            append ret "$m "
            incr n
        }
    }
    return $ret
}
################################################################################
# toggleAnalysisBoard
# Visibility:
#   Internal.
# Inputs:
#   - n (int): Analysis engine slot.
# Returns:
#   - None.
# Side effects:
#   - Shows/hides the analysis board widget and updates window geometry.
#   - Toggles the evaluation bar.
################################################################################
proc toggleAnalysisBoard {n} {
    global analysis
    if { $analysis(showBoard$n) } {
        set analysis(showBoard$n) 0
        pack forget .analysisWin$n.bd
        setWinSize .analysisWin$n
        .analysisWin$n.b1.showboard state !pressed
    } else {
        bind .analysisWin$n <Configure> ""
        set analysis(showBoard$n) 1
        pack .analysisWin$n.bd -side right -before .analysisWin$n.b1 -padx 4 -pady 4 -anchor n
        update
        .analysisWin$n.hist.text configure -setgrid 0
        .analysisWin$n.text configure -setgrid 0
        set x [winfo reqwidth .analysisWin$n]
        set y [winfo reqheight .analysisWin$n]
        wm geometry .analysisWin$n ${x}x${y}
        .analysisWin$n.hist.text configure -setgrid 1
        .analysisWin$n.text configure -setgrid 1
        .analysisWin$n.b1.showboard state pressed
    }
    ::board::toggleEvalBar .analysisWin$n.bd
}
################################################################################
# toggleEngineInfo
# Visibility:
#   Internal.
# Inputs:
#   - n (int): Analysis engine slot.
# Returns:
#   - None.
# Side effects:
#   - Shows/hides additional engine info in the analysis window.
#   - Triggers `updateAnalysisText`.
################################################################################
proc toggleEngineInfo {n} {
    global analysis
    if { $analysis(showEngineInfo$n) } {
	set analysis(showEngineInfo$n) 0
        .analysisWin$n.text configure -height 1
	.analysisWin$n.b1.showinfo state !pressed
    } else {
	set analysis(showEngineInfo$n) 1
        .analysisWin$n.text configure -height 2
	.analysisWin$n.b1.showinfo state pressed
    }
    updateAnalysisText $n
}
################################################################################
# updateAnalysisBoard
# Visibility:
#   Internal.
# Inputs:
#   - n (int): Analysis engine slot.
#   - moves (string|list): Moves to apply from the current position.
# Returns:
#   - None.
# Side effects:
#   - Updates the analysis-board widget to show the PV continuation.
#   - Uses a temporary game copy (`sc_game push/pop`) and applies moves.
################################################################################
proc updateAnalysisBoard {n moves} {
    global analysis
    # PG : this should not be commented
    if {! $analysis(showBoard$n)} { return }
    
    set bd .analysisWin$n.bd
    # Push a temporary copy of the current game:
    sc_game push copyfast
    
    # Make the engine moves and update the board:
    sc_move_add $moves $n
    ::board::update $bd [sc_pos board]
    if { $::analysis(score$n) ne "" } {
        ::board::updateEvalBar $bd $::analysis(score$n)
    }
    
    # Pop the temporary game:
    sc_game pop
}

################################################################################
# updateAnalysis
# Visibility:
#   Public.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Sends the current position/move list to the engine and (re)starts analysis.
#   - Sends the current position to the engine via UCI and (re)starts analysis.
#   - Updates multiple `analysis(...)` fields (e.g. `fen`, `movelist`, `nodes`).
################################################################################
proc updateAnalysis {{n 1}} {
    global analysis
    if {$analysis(pipe$n) == ""} { return }
    # Just return if no output has been seen from the analysis program yet:
    if {! $analysis(seen$n)} { return }
    # No need to update if no analysis is running
    if { ! $analysis(analyzeMode$n) } { return }
    # No need to send current board if engine is locked
    if { $analysis(lockEngine$n) } { return }

    set analysis(depth$n) 0
    set analysis(multiPV$n) {}
    set analysis(multiPVraw$n) {}
    set analysis(fen$n) [sc_pos fen]
    set analysis(maxmovenumber$n) 0
    set analysis(movelist$n) [sc_game UCI_currentPos]
    set analysis(nonStdStart$n) [sc_game startBoard]
    ::uci::sendPositionGo $n "infinite"
}

################################################################################
# setAutomoveTime
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - int (0|1): 1 if the user confirmed, 0 if cancelled.
# Side effects:
#   - Opens a Tk dialog to configure `analysis(automoveTime$n)` (milliseconds).
################################################################################

set temptime 0
trace add variable temptime write {::utils::validate::Regexp {^[0-9]*\.?[0-9]*$}}

proc setAutomoveTime {{n 1}} {
    global analysis temptime dialogResult
    set ::tempn $n
    set temptime [expr {$analysis(automoveTime$n) / 1000.0} ]
    set w .apdialog
    win::createDialog $w
    #wm transient $w .analysisWin
    ::setTitle $w "Scid: Engine thinking time"
    wm resizable $w 0 0
    ttk::frame $w.f
    pack $w.f -expand 1
    ttk::label $w.f.label -text "Set the engine thinking time per move in seconds:"
    pack $w.f.label -side top -pady 5 -padx 5
    ttk::spinbox $w.f.entry -width 5 -textvariable temptime -from 1 -to 999 \
        -validate key -justify right
    pack $w.f.entry -side top -pady 5
    bind $w.f.entry <Escape> { .apdialog.buttons.cancel invoke }
    bind $w.f.entry <Return> { .apdialog.buttons.ok invoke }
    
    addHorizontalRule $w
    
    set dialogResult ""
    set b [ttk::frame $w.buttons]
    pack $b -side top -fill x
    ttk::button $b.cancel -text $::tr(Cancel) -command {
        focus .
        catch {grab release .apdialog}
        destroy .apdialog
        focus .
        set dialogResult Cancel
    }
    ttk::button $b.ok -text "OK" -command {
        catch {grab release .apdialog}
        if {$temptime < 0.1} { set temptime 0.1 }
        set analysis(automoveTime$tempn) [expr {int($temptime * 1000)} ]
        focus .
        catch {grab release .apdialog}
        destroy .apdialog
        focus .
        set dialogResult OK
    }
    pack $b.cancel $b.ok -side right -padx 5 -pady 5
    focus $w.f.entry
    update
    catch {grab .apdialog}
    tkwait window .apdialog
    if {$dialogResult != "OK"} {
        return 0
    }
    return 1
}

################################################################################
# toggleAutomove
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Enables/disables automove mode and updates the UI toggle state.
#   - May prompt for a move time via `setAutomoveTime`.
#   - Schedules `automove` ticks via `after`.
################################################################################
proc toggleAutomove {{n 1}} {
    global analysis
    .analysisWin1.b1.automove state !pressed
    if { $analysis(automove$n) } {
	set analysis(automove$n) 0
        cancelAutomove $n
    } else {
        set analysis(automove$n) 0
        if {! [setAutomoveTime $n]} {
            return
        }
        set analysis(automove$n) 1
        .analysisWin1.b1.automove state pressed
        automove $n
    }
}

################################################################################
# cancelAutomove
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Cancels pending automove timers and disables automove mode.
################################################################################
proc cancelAutomove {{n 1}} {
    global analysis
    set analysis(automove$n) 0
    after cancel "automove $n"
    after cancel "automove_go $n"
}

################################################################################
# automove
# Visibility:
#   Public.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Schedules a move after `analysis(automoveTime$n)` and updates state flags.
################################################################################
proc automove {{n 1}} {
    global analysis autoplayDelay
    if {! $analysis(automove$n)} { return }
    after cancel "automove $n"
    set analysis(automoveThinking$n) 1
    after $analysis(automoveTime$n) "automove_go $n"
}

################################################################################
# automove_go
# Visibility:
#   Internal.
# Inputs:
#   - n (int, optional): Analysis engine slot (default 1).
# Returns:
#   - None.
# Side effects:
#   - Attempts to add the current best move and updates the board/training mode.
#   - Reschedules `automove` if no move is available yet.
################################################################################
proc automove_go {{n 1}} {
    global analysis
    if {$analysis(automove$n)} {
        if {[makeAnalysisMove $n]} {
            set analysis(autoMoveThinking$n) 0
            updateBoard -pgn
            after cancel "automove $n"
            ::tree::doTraining $n
        } else {
            after 1000 "automove $n"
        }
    }
}
################################################################################
# sc_move_add
# Visibility:
#   Public.
# Inputs:
#   - moves (string|list): Moves to add in UCI coordinate notation.
#   - n (int): Analysis engine slot.
# Returns:
#   - int: Whatever `::uci::sc_move_add` returns.
# Side effects:
#   - Adds moves to the current game via `::uci::sc_move_add`.
################################################################################
proc sc_move_add { moves n } {
    return [::uci::sc_move_add $moves]
}
################################################################################
# toAbsPath
# Visibility:
#   Public.
# Inputs:
#   - path (string): Path that may begin with `.`.
# Returns:
#   - string: Path with a leading `.` replaced by the executable directory.
# Side effects:
#   - None.
################################################################################
proc toAbsPath { path } {
    set new $path
    if {[string index $new 0] == "." } {
        set scidInstallDir [file dirname [info nameofexecutable] ]
        set new [ string replace $new 0 0  $scidInstallDir ]
    }
    return $new
}

###
### End of file: analysis.tcl
###
###
