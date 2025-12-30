###
### uci.tcl: part of Scid.
### Copyright (C) 2007  Pascal Georges
###
######################################################################
### add UCI engine support

namespace eval uci {
    # will contain the UCI engine options saved
    variable newOptions {}
    
    # set pipe ""
    set uciOptions {}
    set optList {}
    set oldOptions ""
    array set check ""

    # The list of token that comes with info
    set infoToken { depth seldepth time nodes pv multipv score cp mate lowerbound upperbound \
                currmove currmovenumber hashfull nps tbhits sbhits cpuload string refutation currline }
    set optionToken {name type default min max var }
    set optionImportant { MultiPV Hash OwnBook BookFile UCI_LimitStrength UCI_Elo }
    set optionToKeep { UCI_LimitStrength UCI_Elo UCI_ShredderbasesPath }
    array set uciInfo {}
################################################################################
# ::uci::resetUciInfo
#   Initialises per-slot UCI info fields.
# Visibility:
#   Private.
# Inputs:
#   - n: Optional engine slot number. Defaults to 1.
# Returns:
#   - None.
# Side effects:
#   - Initialises `::uci::uciInfo(*)` fields for slot `n`.
################################################################################
    proc resetUciInfo { { n 1 }} {
        global ::uci::uciInfo
        set uciInfo(depth$n) 0
        set uciInfo(seldepth$n) 0
        set uciInfo(time$n) 0
        set uciInfo(nodes$n) 0
        set uciInfo(pv$n) ""
        set uciInfo(multipv$n) ""
        # set uciInfo(pvlist$n) {}
        # set uciInfo(score$n) ""
        set uciInfo(tmp_score$n) ""
        set uciInfo(scoremate$n) 0
        set uciInfo(currmove$n) ""
        set uciInfo(currmovenumber$n) 0
        set uciInfo(hashfull$n) 0
        set uciInfo(nps$n) 0
        set uciInfo(tbhits$n) 0
        set uciInfo(sbhits$n) 0
        set uciInfo(cpuload$n) 0
        set uciInfo(string$n) ""
        set uciInfo(refutation$n) ""
        set uciInfo(currline$n) ""
        # set uciInfo(bestmove$n) ""
    }
################################################################################
# ::uci::processAnalysisInput
#   Handles the initial readable event and schedules parsing of engine output.
# Visibility:
#   Private.
# Inputs:
#   - n: Optional engine slot number. Defaults to 1.
#   - analyze: Optional flag indicating analysis mode.
#       - 0: playing/engine mode (`::uci::uciInfo(pipe$n)`).
#       - 1: analysis mode (`analysis(pipe$n)`).
#     Defaults to 1.
# Returns:
#   - None.
# Side effects:
#   - Verifies the engine is alive; may return early.
#   - On first output line, marks the engine as seen and sends initial `uci`.
#   - Schedules `::uci::processInput_` via `after idle` and disables the current
#     `fileevent` handler to avoid re-entrancy.
################################################################################
    proc  processAnalysisInput { { n 1 } { analyze 1 } } {
        global analysis ::uci::uciInfo
        
        if {$analyze} {
            set pipe $analysis(pipe$n)
            if { ! [ ::checkEngineIsAlive $n ] } { return }
        } else  {
            set analysis(fen$n) ""
            set pipe $uciInfo(pipe$n)
            if { ! [ ::uci::checkEngineIsAlive $n ] } { return }
        }
        
        if {$analyze} {
            if {! $analysis(seen$n)} {
                set analysis(seen$n) 1
                logEngineNote $n {First line from engine seen; sending it initial commands now.}
                # in order to get options, engine should end reply with "uciok"
                ::sendToEngine $n "uci"
            }
        } else  {
            if {! $uciInfo(seen$n)} {
                set uciInfo(seen$n) 1
                logEngineNote $n {First line from engine seen; sending it initial commands now.}
                ::uci::sendToEngine $n "uci"
            }
        }

        after idle "after 1 ::uci::processInput_ $n $analyze"
        fileevent $pipe readable {}
    }

################################################################################
# ::uci::processInput_
#   Parses one line of UCI output and updates engine/analysis state.
# Visibility:
#   Private.
# Inputs:
#   - n: Engine slot number.
#   - analyze: Flag indicating analysis mode.
#       - 0: playing/engine mode (`::uci::uciInfo(pipe$n)`).
#       - 1: analysis mode (`analysis(pipe$n)`).
# Returns:
#   - None.
# Side effects:
#   - Reads one line from the engine pipe and re-schedules itself via `after idle`.
#   - Updates `::uci::uciInfo(*)` and, for analysis mode, `analysis(*)`.
#   - On `bestmove`, updates `::uci::uciInfo(bestmove$n)`/`ponder$n` and triggers
#     `::uci::onReady_ $n`.
#   - On `info`, parses depth/time/nodes/score/pv (incl. multiPV) and updates:
#       - For analysis mode and multiPV 1: updates the "best line" fields such as
#         `analysis(score$n)`, `analysis(moves$n)`, `analysis(depth$n)`, etc.
#       - For any multiPV index within `analysis(multiPVCount$n)`: updates the PV
#         lists `analysis(multiPV$n)` and `analysis(multiPVraw$n)`.
#   - On `option name ...` lines in analysis mode: appends `{name min max}` tuples
#     to `analysis(uciOptions$n)`.
#   - On `uciok`/`readyok`, updates ready flags and may execute queued callbacks.
#   - Calls `updateAnalysisText $n` in analysis mode.
################################################################################
    proc processInput_ { {n} {analyze} } {
        global analysis ::uci::uciInfo ::uci::infoToken ::uci::optionToken
        
        if {$analyze} {
            set pipe $analysis(pipe$n)
            if { ! [ ::checkEngineIsAlive $n ] } { return }
        } else  {
            set analysis(fen$n) ""
            set pipe $uciInfo(pipe$n)
            if { ! [ ::uci::checkEngineIsAlive $n ] } { return }
        }

        # Get one line from the engine:
        set line [gets $pipe]
        if {$line == ""} {
            fileevent $pipe readable "::uci::processAnalysisInput $n $analyze"
            return
        }

        after idle "after 1 ::uci::processInput_ $n $analyze"
        
        # puts ">> $line"
        
        # To speed up parsing of engine's output. Should be removed if currmove info is used
        # if {[string first "info currmove" $line ] == 0} { return }
        
        logEngine $n "Engine: $line"

        if {[string match "bestmove*" $line]} {
            set data [split $line]
            set uciInfo(bestmove$n) [lindex $data 1]
            # get ponder move
            if {[lindex $data 2] == "ponder"} {
                set uciInfo(ponder$n) [lindex $data 3]
            } else {
                set uciInfo(ponder$n) ""
            }
            after cancel "::uci::onReady_ $n"
            ::uci::onReady_ $n
            return
        }
        
        if {[string match "id *name *" $line]} {
            set name [ regsub {id[ ]?name[ ]?} $line "" ]
            if {$analyze} {
                set analysis(name$n) $name
            } else  {
                set uciInfo(name$n) $name
            }
            
            if {$n == 1} {
                catch {wm title .analysisWin$n "Scid: Analysis: $name"}
            } else {
                catch {wm title .analysisWin$n "Scid: Analysis $n: $name"}
            }
        }
        
        set toBeFormatted 0
        # parse an info line
        if {[string first "info" $line ] == 0} {
            if {$analysis(waitForReadyOk$n)} { return }
            resetUciInfo $n
            set data [split $line]
            set length [llength $data]
            for {set i 0} {$i < $length } {incr i} {
                set t [lindex $data $i]
                if { $t == "info" } { continue }
                if { $t == "depth" } { incr i ; set uciInfo(depth$n) [ lindex $data $i ] ; continue }
                if { $t == "seldepth" } { incr i ; set uciInfo(seldepth$n) [ lindex $data $i ] ; set analysis(seldepth$n) $uciInfo(seldepth$n) ; continue }
                if { $t == "time" } { incr i ; set uciInfo(time$n) [ lindex $data $i ] ; continue }
                if { $t == "nodes" } { incr i ; set uciInfo(nodes$n) [ lindex $data $i ] ; continue }
                if { $t == "pv" } {
                    incr i
                    set uciInfo(pv$n) [ lindex $data $i ]
                    incr i
                    while { [ lsearch -exact $infoToken [ lindex $data $i ] ] == -1 && $i < $length } {
                        append uciInfo(pv$n) " " [ lindex $data $i ]
                        incr i
                    }
                    set toBeFormatted 1
                    incr i -1
                    continue
                }
                if { $t == "multipv" } { incr i ; set uciInfo(multipv$n) [ lindex $data $i ] ; continue }
                if { $t == "score" } {
                    incr i
                    set next [ lindex $data $i ]
                    # Needed for Prodeo, which is not UCI compliant
                    if { $next != "cp" && $next != "mate" } {
                        return
                    }
                    if { $next == "cp" } {
                        incr i
                        set uciInfo(tmp_score$n) [ lindex $data $i ]
                    }
                    if { $next == "mate" } {
                        incr i
                        set next [ lindex $data $i ]
                        set uciInfo(scoremate$n) $next
                        if { $next < 0} {
                            set uciInfo(tmp_score$n) [expr {-32767 - 2 * $next}]
                        } else  {
                            set uciInfo(tmp_score$n) [expr {32767 - 2 * $next}]
                        }
                    }
                    # convert the score to white's perspective (not engine's one)
                    if { $analysis(fen$n) == "" } {
                        set side [string index [sc_pos side] 0]
                    } else {
                        set side [lindex [split $analysis(fen$n)] 1]
                    }
                    if { $side == "b"} {
                        set uciInfo(tmp_score$n) [ expr 0.0 - $uciInfo(tmp_score$n) ]
                        if { $uciInfo(scoremate$n) } {
                            set uciInfo(scoremate$n) [ expr 0 - $uciInfo(scoremate$n) ]
                            if { $uciInfo(tmp_score$n) < 0 } {
                                set uciInfo(tmp_score$n) [ expr {$uciInfo(tmp_score$n) - 1.0} ]
                            }
                        }
                    } elseif { $uciInfo(scoremate$n) && $uciInfo(tmp_score$n) > 0 } {
                        set uciInfo(tmp_score$n) [ expr {$uciInfo(tmp_score$n) + 1.0} ]
                    }
                    set uciInfo(tmp_score$n) [expr {double($uciInfo(tmp_score$n)) / 100.0} ]
                    
                    # don't consider lowerbound & upperbound score info
                    continue
                }
                if { $t == "currmove" } { incr i ; set uciInfo(currmove$n) [ lindex $data $i ] ; set analysis(currmove$n) [formatPv $uciInfo(currmove$n) $analysis(fen$n)] ; continue}
                if { $t == "currmovenumber" } { incr i ; set uciInfo(currmovenumber$n) [ lindex $data $i ] ; set analysis(currmovenumber$n) $uciInfo(currmovenumber$n) ; continue}
                if { $t == "hashfull" } { incr i ; set uciInfo(hashfull$n) [ lindex $data $i ] ; set analysis(hashfull$n) $uciInfo(hashfull$n) ; continue}
                if { $t == "nps" } { incr i ; set uciInfo(nps$n) [ lindex $data $i ] ; set analysis(nps$n) $uciInfo(nps$n) ; continue}
                if { $t == "tbhits" } { incr i ; set uciInfo(tbhits$n) [ lindex $data $i ] ; set analysis(tbhits$n) $uciInfo(tbhits$n) ; continue}
                if { $t == "sbhits" } { incr i ; set uciInfo(sbhits$n) [ lindex $data $i ] ; set analysis(sbhits$n) $uciInfo(sbhits$n) ; continue}
                if { $t == "cpuload" } { incr i ; set uciInfo(cpuload$n) [ lindex $data $i ] ; set analysis(cpuload$n) $uciInfo(cpuload$n) ; continue}
                if { $t == "string" } {
                    incr i
                    while { $i < $length } {
                        append uciInfo(string$n) [ lindex $data $i ] " "
                        incr i
                    }
                    break
                }
                # TODO parse following tokens if necessary  : refutation currline
                if { $t == "refutation" } { continue }
                if { $t == "currline" } { continue }
            };# end for data loop
            
            # return if no interesting info
            if { $uciInfo(tmp_score$n) == "" || $uciInfo(pv$n) == "" } {
                if {$analyze} {
                    updateAnalysisText $n
                }
                return
            }
            
            # handle the case an UCI engine does not send multiPV
            if { $uciInfo(multipv$n) == "" } { set uciInfo(multipv$n) 1 }
            
            if { $uciInfo(multipv$n) == 1 } {
                set uciInfo(score$n) $uciInfo(tmp_score$n)
            }
            
            if { $uciInfo(multipv$n) == 1 && $analyze} {
                # this is the best line
                set analysis(prev_depth$n) $analysis(depth$n)
                set analysis(depth$n) $uciInfo(depth$n)
                set analysis(score$n) $uciInfo(score$n)
                set analysis(scoremate$n) $uciInfo(scoremate$n)
                set analysis(moves$n) $uciInfo(pv$n)
                set analysis(time$n) [expr {double($uciInfo(time$n)) / 1000.0} ]
                set analysis(nodes$n) [calculateNodes $uciInfo(nodes$n) ]
            }
            
            set pvRaw $uciInfo(pv$n)
            
            # convert to something more readable
            if ($toBeFormatted) {
                set uciInfo(pv$n) [formatPv $uciInfo(pv$n) $analysis(fen$n)]
                set toBeFormatted 0
            }
            
            set idx [ expr $uciInfo(multipv$n) -1 ]
            
            # was if $analyze etc..
            if { $idx < $analysis(multiPVCount$n) } {
                set tmpTime [expr {double($uciInfo(time$n)) / 1000.0}]
                if {$idx < [llength $analysis(multiPV$n)]} {
                    lset analysis(multiPV$n) $idx "$uciInfo(depth$n) $uciInfo(tmp_score$n) [list $uciInfo(pv$n)] $uciInfo(scoremate$n) $tmpTime"
                    lset analysis(multiPVraw$n) $idx "$uciInfo(depth$n) $uciInfo(tmp_score$n) [list $pvRaw] $uciInfo(scoremate$n) $tmpTime"
                } else  {
                    lappend analysis(multiPV$n) "$uciInfo(depth$n) $uciInfo(tmp_score$n) [list $uciInfo(pv$n)] $uciInfo(scoremate$n) $tmpTime"
                    lappend analysis(multiPVraw$n) "$uciInfo(depth$n) $uciInfo(tmp_score$n) [list $pvRaw] $uciInfo(scoremate$n) $tmpTime"
                }
            }
            
        } ;# end of info line
        
        # the UCI engine answers to <uci> command
        if { $line == "uciok"} {
            resetUciInfo $n
            if {$analyze} {
                set analysis(uciok$n) 1
            } else  {
                set uciInfo(uciok$n) 1
            }
            if {$analysis(onUciOk$n) != ""} { {*}$analysis(onUciOk$n) }
        }
        
        # the UCI engine answers to <isready> command
        if { $line == "readyok"} {
            after cancel "::uci::onReady_ $n"
            ::uci::onReady_ $n
            return
        }
        
        # get options and save only part of data
        if { [string first "option name" $line] == 0 && $analyze } {
            set min "" ; set max ""
            set data [split $line]
            set length [llength $data]
            for {set i 0} {$i < $length} {incr i} {
                set t [lindex $data $i]
                if {$t == "name"} {
                    incr i
                    set name [ lindex $data $i ]
                    incr i
                    while { [ lsearch -exact $optionToken [ lindex $data $i ] ] == -1 && $i < $length } {
                        append name " " [ lindex $data $i ]
                        incr i
                    }
                    incr i -1
                    continue
                }
                if {$t == "min"} { incr i ; set min [ lindex $data $i ] ; continue }
                if {$t == "max"} {incr i ; set max [ lindex $data $i ] ; continue }
            }
            lappend analysis(uciOptions$n) [ list $name $min $max ]
        }
        if {$analyze} {
            updateAnalysisText $n
        }
    }
################################################################################
# ::uci::readUCI
#   Reads UCI option output from a temporary engine process used for configuration.
# Visibility:
#   Private.
# Inputs:
#   - n: Engine slot number.
# Returns:
#   - None.
# Side effects:
#   - Reads from `::uci::uciInfo(pipe$n)`.
#   - Appends raw `option name ...` lines to `::uci::uciOptions`.
#   - On `uciok`, closes the engine (`::uci::closeUCIengine`) and opens the
#     configuration dialog (`::uci::uciConfigWin`).
################################################################################
    proc readUCI { n } {
        global ::uci::uciOptions
        
        set line [string trim [gets $::uci::uciInfo(pipe$n)] ]
        # end of options
        if {$line == "uciok"} {
            # we got all options, stop engine
            closeUCIengine $n 1
            uciConfigWin
        }
        # get options
        if { [string first "option name" $line] == 0 } {
            lappend uciOptions $line
        }
    }
################################################################################
# ::uci::uciConfig
#   Starts an engine briefly to query its UCI options and then launches the
#   configuration UI.
# Visibility:
#   Public.
# Inputs:
#   - n: Engine slot number.
#   - cmd: Engine executable.
#   - arg: Engine arguments.
#   - dir: Working directory to run the engine from.
#   - options: Previously saved UCI options for this engine.
# Returns:
#   - None.
# Side effects:
#   - Starts a temporary engine process and assigns `::uci::uciInfo(pipe$n)`.
#   - Sends `uci` to the engine and listens for `option name ...` lines.
#   - Stores collected option lines in `::uci::uciOptions`.
#   - Schedules a timeout close (`after 5000 ::uci::closeUCIengine $n 0`) to
#     detect non-UCI engines.
#   - Shows a `tk_messageBox` on start/running errors.
################################################################################
    proc uciConfig { n cmd arg dir options } {
        global ::uci::uciOptions ::uci::oldOptions
        
        if {[info exists ::uci::uciInfo(pipe$n)]} {
            if {$::uci::uciInfo(pipe$n) != ""} {
                tk_messageBox -title "Scid" -icon warning -type ok -message "An engine is already running"
                return
            }
        }
        set oldOptions $options
        
        # If the analysis directory is not current dir, cd to it:
        set oldpwd ""
        if {$dir != "."} {
            set oldpwd [pwd]
            catch {cd $dir}
        }
        # Try to execute the analysis program:
        if {[catch {set pipe [open "| [list $cmd] $arg" "r+"]} result]} {
            if {$oldpwd != ""} { catch {cd $oldpwd} }
            tk_messageBox -title "Scid: error starting UCI engine" \
                    -icon warning -type ok -message "Unable to start the program:\n$cmd"
            return
        }
        
        set ::uci::uciInfo(pipe$n) $pipe
        
        # Configure pipe for line buffering and non-blocking mode:
        fconfigure $pipe -buffering full -blocking 0
        fileevent $pipe readable "::uci::readUCI $n"
        
        # Return to original dir if necessary:
        if {$oldpwd != ""} { catch {cd $oldpwd} }
        
        set uciOptions {}
        
        puts $pipe "uci"
        flush $pipe
        
        # Give a few seconds for the engine to output its options, then automatically close it.
        after 5000  "::uci::closeUCIengine $n 0"
    }
    
################################################################################
# ::uci::uciConfigWin
#   Builds the UI window for editing UCI options reported by an engine.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Creates `.uciConfigWin` and its child widgets.
#   - Defines (or redefines) `::uci::tokeep` helper procedure.
#   - Parses `::uci::uciOptions` into `::uci::optList`.
#   - Initialises UI state from `::uci::oldOptions`.
#   - Updates `::uci::check(*)` variables for checkbuttons.
#   - Installs bindings and attempts to grab the window.
################################################################################
    proc uciConfigWin {} {
        global ::uci::uciOptions ::uci::optList ::uci::optionToken ::uci::oldOptions ::uci::optionImportant
        
        set w .uciConfigWin
        if { [winfo exists $w]} { return }
        win::createDialog $w
        wm title $w $::tr(ConfigureUCIengine)

        autoscrollframe -bars both $w canvas $w.c -highlightthickness 0 -background [ttk::style lookup Button.label -background]
        bind $w.c <Configure>  {
            set l [winfo reqwidth %W.f]
            set h [winfo reqheight %W.f]
            %W configure -scrollregion [list 0 0 $l $h] -width $l -height $h
        }
        grid [ttk::frame $w.c.f]
        $w.c create window 0 0 -window $w.c.f -anchor nw
        set w $w.c.f

        ################################################################################
        # ::uci::tokeep
        #   Determines whether a UCI option should be kept even if it matches the
        #   default skip rules (e.g. `UCI_*` or `Ponder`).
        # Visibility:
        #   Private.
        # Inputs:
        #   - opt: Raw option line token list.
        # Returns:
        #   - 1 if the option should be kept; otherwise 0.
        # Side effects:
        #   - None.
        ################################################################################
        proc tokeep {opt} {
            foreach tokeep $::uci::optionToKeep {
                if { [lsearch $opt $tokeep] != -1 } {
                    return 1
                }
            }
            return 0
        }
        
        set optList ""
        array set elt {}
        foreach opt $uciOptions {
            set elt(name) "" ; set elt(type) "" ; set elt(default) "" ; set elt(min) "" ; set elt(max) "" ; set elt(var) ""
            set data [split $opt]
            # skip options starting with UCI_ and Ponder
            # some engines like shredder use UCI_* options that should not be ignored
            
            if { ![tokeep $opt] && ( [ lsearch -glob $data "UCI_*" ] != -1 || [ lsearch $data "Ponder" ] != -1 ) } {
                continue
            }
            
            set length [llength $data]
            # parse one option
            for {set i 0} {$i < $length} {incr i} {
                set t [lindex $data $i]
                if {$t == "option"} { continue }
                if {$t == "name"} {
                    incr i
                    set elt(name) [ lindex $data $i ]
                    incr i
                    while { [ lsearch -exact $optionToken [ lindex $data $i ] ] == -1 && $i < $length } {
                        append elt(name) " " [ lindex $data $i ]
                        incr i
                    }
                    incr i -1
                    continue
                }
                if {$t == "type"} { incr i ; set elt(type) [ lindex $data $i ] ; continue }
                if {$t == "default"} { ;# Glaurung uses a default value that is > one word
                    incr i
                    set elt(default) [ lindex $data $i ]
                    incr i
                    while { [ lsearch -exact $optionToken [ lindex $data $i ] ] == -1 && $i < $length } {
                        append elt(default) " " [ lindex $data $i ]
                        incr i
                    }
                    incr i -1
                    continue
                }
                if {$t == "min"} { incr i ; set elt(min) [ lindex $data $i ] ; continue }
                if {$t == "max"} { incr i ; set elt(max) [ lindex $data $i ] ; continue }
                if {$t == "var"} {
                    incr i
                    set tmp [ lindex $data $i ]
                    incr i
                    while { ([ lsearch -exact $optionToken [ lindex $data $i ] ] == -1 && $i < $length ) \
                                || [ lindex $data $i ] == "var" } {
                        if {[ lindex $data $i ] != "var" } {
                            append tmp " " [ lindex $data $i ]
                        } else  {
                            lappend elt(var) [list $tmp]
                            incr i
                            set tmp [ lindex $data $i ]
                        }
                        incr i
                    }
                    lappend elt(var) [list $tmp]
                    
                    incr i -1
                    continue
                }
            }
            lappend optList [array get elt]
        }
        
        # sort list of options so that important ones come first
        set tmp $optList
        set optList {}
        foreach l $tmp {
            array set elt $l
            if { [ lsearch $optionImportant $elt(name) ] != -1 } {
                lappend optList $l
            }
        }
        foreach l $tmp {
            array set elt $l
            if { [ lsearch $optionImportant $elt(name) ] == -1 } {
                lappend optList $l
            }
        }
        
        set optnbr 0
        ttk::frame $w.fopt
        ttk::frame $w.fbuttons
        
        set row 0
        set col 0
        set isImportantParam 1
        foreach l $optList {
            array set elt $l
            set name $elt(name)
            if { [ lsearch $optionImportant $elt(name) ] == -1 && $isImportantParam } {
                set isImportantParam 0
                incr row
                set col 0
            }
            if {$elt(name) == "MultiPV"} { set name $::tr(MultiPV) }
            if {$elt(name) == "Hash"} { set name $::tr(Hash) }
            if {$elt(name) == "OwnBook"} { set name $::tr(OwnBook) }
            if {$elt(name) == "BookFile"} { set name $::tr(BookFile) }
            if {$elt(name) == "UCI_LimitStrength"} { set name $::tr(LimitELO) }
            
            if { $col > 3 } { set col 0 ; incr row}
            if {$elt(default) != ""} {
                set default "\n($elt(default))"
            } else  {
                set default ""
            }
            set value $elt(default)
            # find the name in oldOptions (the previously saved data)
            foreach old $oldOptions {
                if {[lindex $old 0] == $elt(name)} {
                    set value [lindex $old 1]
                    break
                }
            }
            if { $elt(type) == "check"} {
                ttk::checkbutton $w.fopt.opt$optnbr -text "$name$default" -onvalue true -offvalue false -variable ::uci::check($optnbr)
                set ::uci::check($optnbr) $value
                grid $w.fopt.opt$optnbr -row $row -column $col -sticky w
            }
            if { $elt(type) == "spin"} {
                ttk::label $w.fopt.label$optnbr -text "$name$default"
                if { $elt(name) == "UCI_Elo" } {
                    ttk::spinbox $w.fopt.opt$optnbr -from $elt(min) -to $elt(max) -width 5 -increment 50 -validate all -validatecommand { regexp {^[0-9]+$} %P }
                } else  {
                    ttk::spinbox $w.fopt.opt$optnbr -from $elt(min) -to $elt(max) -width 5 -validate all -validatecommand { regexp {^[0-9]+$} %P }
                }
                $w.fopt.opt$optnbr set $value
                grid $w.fopt.label$optnbr -row $row -column $col -sticky e
                incr col
                grid $w.fopt.opt$optnbr -row $row -column $col -sticky w
            }
            if { $elt(type) == "combo"} {
                ttk::label $w.fopt.label$optnbr -text "$name$default"
                set idx 0
                set i 0
                set tmp {}
                foreach e $elt(var) {
                    lappend tmp [join $e]
                    if {[join $e] == $value} { set idx $i }
                    incr i
                }
                ttk::combobox $w.fopt.opt$optnbr -values $tmp
                
                $w.fopt.opt$optnbr current $idx
                grid $w.fopt.label$optnbr -row $row -column $col -sticky e
                incr col
                grid $w.fopt.opt$optnbr -row $row -column $col -sticky w
            }
            if { $elt(type) == "button"} {
                ttk::button $w.fopt.opt$optnbr -text "$name$default"
                grid $w.fopt.opt$optnbr -row $row -column $col -sticky w
            }
            if { $elt(type) == "string"} {
                ttk::label $w.fopt.label$optnbr -text "$name$default"
                ttk::entry $w.fopt.opt$optnbr
                $w.fopt.opt$optnbr insert 0 $value
                grid $w.fopt.label$optnbr -row $row -column $col -sticky e
                incr col
                grid $w.fopt.opt$optnbr -row $row -column $col -sticky w
            }
            incr col
            incr optnbr
        }
        
        ttk::button $w.fbuttons.save -text $::tr(Save) -command {
            ::uci::saveConfig
            destroy .uciConfigWin
        }
        ttk::button $w.fbuttons.cancel -text $::tr(Cancel) -command "destroy .uciConfigWin"
        pack $w.fbuttons.save $w.fbuttons.cancel -side left -expand yes -fill x -padx 20 -pady 2
        pack $w.fopt -expand 1 -fill both
        addHorizontalRule $w
        pack $w.fbuttons -expand 1 -fill both
        bind $w <Return> "$w.fbuttons.save invoke"
        bind $w <Escape> "destroy .uciConfigWin"
        catch {grab .uciConfigWin}
    }
################################################################################
# ::uci::saveConfig
#   Extracts option values from the configuration UI.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Populates `::uci::newOptions` as a list of `{name value}` pairs.
#   - Reads widget state from `.uciConfigWin.c.f.fopt.opt*`.
################################################################################
    proc saveConfig {} {
        global ::uci::optList ::uci::newOptions
        set newOptions {}
        set w .uciConfigWin.c.f
        set optnbr 0
        
        foreach l $optList {
            array set elt $l
            set value ""
            if { $elt(type) == "check"} {
                set value $::uci::check($optnbr)
            }
            if { $elt(type) == "spin" || $elt(type) == "combo" || $elt(type) == "string" } {
                set value [$w.fopt.opt$optnbr get]
            }
            if { $elt(type) != "button" } {
                lappend newOptions [ list $elt(name)  $value ]
            }
            incr optnbr
        }
    }

################################################################################
# ::uci::sendUCIoptions
#   Sends queued UCI options to an analysis engine, ensuring the engine is ready.
# Visibility:
#   Public.
# Inputs:
#   - n: Engine slot number.
# Returns:
#   - None.
# Side effects:
#   - Calls `::uci::sendStop` and waits for readiness via `::uci::whenReady`.
#   - Eventually sends `setoption ...` commands via `::uci::sendOptions_`.
################################################################################
    proc sendUCIoptions {n} {
        ::uci::sendStop $n
        ::uci::whenReady $n [list ::uci::sendOptions_ $n] 5000
    }

################################################################################
# ::uci::sendPositionGo
#   Sends the current position and a `go` command to the engine.
# Visibility:
#   Public.
# Inputs:
#   - n: Engine slot number.
#   - go_time: Argument string appended to the UCI `go` command.
# Returns:
#   - None.
# Side effects:
#   - Calls `::uci::sendStop` and waits for readiness via `::uci::whenReady`.
#   - Eventually sends the position/go sequence via `::uci::sendPositionGo_`.
################################################################################
    proc sendPositionGo {n go_time} {
        ::uci::sendStop $n
        ::uci::whenReady $n [list ::uci::sendPositionGo_ $n $go_time] 5000
    }

################################################################################
# ::uci::sendStop
#   Requests that the engine stops analysis as soon as possible.
# Visibility:
#   Private.
# Inputs:
#   - n: Engine slot number.
# Returns:
#   - None.
# Side effects:
#   - If `analysis(thinking$n)` exists and `analysis(waitForBestMove$n)` is false,
#     sets `analysis(waitForBestMove$n)` and sends UCI `stop`.
#   - Clears `analysis(fen$n)`.
################################################################################
    proc sendStop {n} {
        if {[info exists ::analysis(thinking$n)] && ! $::analysis(waitForBestMove$n)} {
            set ::analysis(waitForBestMove$n) 1
            ::sendToEngine $n "stop"
        }
        set ::analysis(fen$n) {}
    }

################################################################################
# ::uci::sendIsReady
#   Sends `isready` unless we are already waiting for `readyok`.
# Visibility:
#   Private.
# Inputs:
#   - n: Engine slot number.
# Returns:
#   - None.
# Side effects:
#   - Sets `::analysis(waitForReadyOk$n)` and sends UCI `isready`.
################################################################################
    proc sendIsReady {n} {
        if { ! $::analysis(waitForReadyOk$n) } {
            set ::analysis(waitForReadyOk$n) 1
            ::sendToEngine $n "isready"
        }
    }

################################################################################
# ::uci::whenReady
#   Executes a command when the engine is ready (not awaiting `bestmove`/`readyok`).
# Visibility:
#   Private.
# Inputs:
#   - n: Engine slot number.
#   - cmd: Tcl command list to execute.
#   - max_wait: Optional maximum wait time in milliseconds before forcing a
#     readiness check. Defaults to -1 (no timeout).
# Returns:
#   - None.
# Side effects:
#   - Queues `cmd` into `::analysis(whenReady$n)` when the engine is busy.
#   - May schedule `::uci::onReady_ $n` after `max_wait`.
################################################################################
    proc whenReady {n cmd {max_wait -1}} {
        if { $::analysis(waitForBestMove$n) || $::analysis(waitForReadyOk$n) } {
            set idx [lsearch  -index 0 $::analysis(whenReady$n) [lindex $cmd 0]]
            if {$idx == -1} {
                lappend ::analysis(whenReady$n) $cmd
            } else {
                lreplace $::analysis(whenReady$n) $idx $idx $cmd
            }
            if {$max_wait > 0} {
                after cancel "::uci::onReady_ $n"
                after $max_wait "::uci::onReady_ $n"
            }
        } else {
            eval {*}$cmd
        }
    }

################################################################################
# ::uci::sendOptions_
#   Sends `setoption` commands for options queued in `::uciOptions$n`.
# Visibility:
#   Private.
# Inputs:
#   - n: Engine slot number.
# Returns:
#   - None.
# Side effects:
#   - Sends one `setoption name ... value ...` command per option.
#   - Updates `::analysis(multiPVCount$n)` when setting `MultiPV`.
#   - Unsets `::uciOptions$n` and calls `::uci::sendIsReady`.
################################################################################
    proc sendOptions_ {n} {
        if {[array exists ::uciOptions$n]} {
            foreach {name value} [array get ::uciOptions$n] {
                ::sendToEngine $n "setoption name $name value $value"
                if { $name == "MultiPV" } { set ::analysis(multiPVCount$n) $value }
            }
            array unset ::uciOptions$n

            ::uci::sendIsReady $n
        }
    }

################################################################################
# ::uci::sendPositionGo_
#   Sends the current movelist and a `go` command to start analysis.
# Visibility:
#   Private.
# Inputs:
#   - engine_n: Engine slot number.
#   - time: Argument string appended to the UCI `go` command.
# Returns:
#   - None.
# Side effects:
#   - Sets `::analysis(thinking$engine_n)`.
#   - Sends `analysis(movelist$engine_n)` and `go $time` via `::sendToEngine`.
################################################################################
    proc sendPositionGo_ {engine_n time} {
        set ::analysis(thinking$engine_n) 1
        ::sendToEngine $engine_n "$::analysis(movelist$engine_n)"
        ::sendToEngine $engine_n "go $time"
    }

################################################################################
# ::uci::onReady_
#   Marks the engine as ready and drains any queued `whenReady` commands.
# Visibility:
#   Private.
# Inputs:
#   - n: Engine slot number.
# Returns:
#   - None.
# Side effects:
#   - Clears `::analysis(waitForBestMove$n)` and `::analysis(waitForReadyOk$n)`.
#   - Unsets `::analysis(thinking$n)`.
#   - Executes queued commands from `::analysis(whenReady$n)` until the engine is
#     busy again.
################################################################################
    proc onReady_ {n} {
        unset -nocomplain ::analysis(thinking$n)
        set ::analysis(waitForBestMove$n) 0
        set ::analysis(waitForReadyOk$n) 0
        while { [llength $::analysis(whenReady$n)] } {
            set cmd [lindex $::analysis(whenReady$n) 0]
            set ::analysis(whenReady$n) [lrange $::analysis(whenReady$n) 1 end]
            eval {*}$cmd
            if { $::analysis(waitForReadyOk$n) || \
                 $::analysis(waitForBestMove$n) || \
                 [info exists ::analysis(thinking$n)] } {  break }
        }
    }

################################################################################
# ::uci::startEngine
#   Starts a UCI engine for playing (non-analysis mode).
# Visibility:
#   Public.
# Inputs:
#   - index: Index into `::engines(list)`.
#   - n: Engine slot number.
# Returns:
#   - 0 on success; 1 on failure to start the engine.
# Side effects:
#   - Opens the engine process and assigns `::uci::uciInfo(pipe$n)`.
#   - Configures `fileevent` to parse output via `::uci::processAnalysisInput $n 0`.
#   - Polls until `uciok` is observed or a timeout occurs.
#   - Updates `analysis(index$n)` and `analysis(pipe$n)`.
#   - Shows a `tk_messageBox` on start failure.
################################################################################
    proc startEngine {index n} {
        global ::uci::uciInfo
        resetUciInfo $n
        set uciInfo(pipe$n) ""
        set uciInfo(seen$n) 0
        set uciInfo(uciok$n) 0
        ::resetEngine $n
        set engineData [lindex $::engines(list) $index]
        set analysisName [lindex $engineData 0]
        set analysisCommand [ toAbsPath [lindex $engineData 1] ]
        set analysisArgs [lindex $engineData 2]
        set analysisDir [ toAbsPath [lindex $engineData 3] ]
        
        # If the analysis directory is not current dir, cd to it:
        set oldpwd ""
        if {$analysisDir != "."} {
            set oldpwd [pwd]
            catch {cd $analysisDir}
        }
        
        # Try to execute the analysis program:
        if {[catch {set uciInfo(pipe$n) [open "| [list $analysisCommand] $analysisArgs" "r+"]} result]} {
            if {$oldpwd != ""} { catch {cd $oldpwd} }
            tk_messageBox -title "Scid: error starting engine" -icon warning -type ok \
                    -message "Unable to start the program:\n$analysisCommand"
            return 1
        }
        
        set ::analysis(index$n) $index
        set ::analysis(pipe$n) $uciInfo(pipe$n)
        
        # Return to original dir if necessary:
        if {$oldpwd != ""} { catch {cd $oldpwd} }
        
        fconfigure $uciInfo(pipe$n) -buffering line -blocking 0
        fileevent $uciInfo(pipe$n) readable "::uci::processAnalysisInput $n 0"
        
        # wait a few seconds to be sure the engine had time to start
        set counter 0
        while {! $::uci::uciInfo(uciok$n) && $counter < 50 } {
            incr counter
            update
            after 100
        }
        return 0
    }
################################################################################
# ::uci::sendToEngine
#   Sends a command to a running UCI engine process.
# Visibility:
#   Public.
# Inputs:
#   - n: Engine slot number.
#   - text: UCI command text to send.
# Returns:
#   - None.
# Side effects:
#   - Logs the outgoing command via `logEngine` (not guarded).
#   - Writes to `::uci::uciInfo(pipe$n)` (best-effort; `puts` errors are caught).
################################################################################
    proc sendToEngine {n text} {
        logEngine $n "Scid  : $text"
        catch {puts $::uci::uciInfo(pipe$n) $text}
    }
################################################################################
# ::uci::checkEngineIsAlive
#   Checks whether the engine process for a given slot is still alive.
# Visibility:
#   Private.
# Inputs:
#   - n: Engine slot number.
# Returns:
#   - 1 if the engine is alive; otherwise 0.
# Side effects:
#   - On EOF, disables `fileevent`, closes the pipe, clears `::uci::uciInfo(pipe$n)`,
#     logs the termination, and shows a `tk_messageBox`.
################################################################################
    proc checkEngineIsAlive { n } {
        global ::uci::uciInfo
        if { $uciInfo(pipe$n) == "" } { return 0 }
        if {[eof $uciInfo(pipe$n)]} {
            fileevent $uciInfo(pipe$n) readable {}
            set exit_status 0
            if {[catch {close $uciInfo(pipe$n)} standard_error] != 0} {
                global errorCode
                if {"CHILDSTATUS" == [lindex $errorCode 0]} {
                    set exit_status [lindex $errorCode 2]
                }
            }
            set uciInfo(pipe$n) ""
            if { $exit_status != 0 } {
                logEngineNote $n {Engine terminated with exit code $exit_status: "\"$standard_error\""}
                tk_messageBox -type ok -icon info -parent . -title "Scid" \
                              -message "The analysis engine terminated with exit code $exit_status: \"$standard_error\""
            } else {
                logEngineNote $n {Engine terminated without exit code: "\"$standard_error\""}
                tk_messageBox -type ok -icon info -parent . -title "Scid" \
                              -message "The analysis engine terminated without exist code: \"$standard_error\""
            }
            return 0
        }
        return 1
    }
################################################################################
# ::uci::closeUCIengine
#   Closes a running engine process and resets its slot state.
# Visibility:
#   Public.
# Inputs:
#   - n: Engine slot number.
#   - uciok: Optional flag indicating whether the engine identified as UCI.
#     Defaults to 1.
# Returns:
#   - None.
# Side effects:
#   - Cancels any scheduled close timeout and disables `fileevent`.
#   - Sends `stop`/`quit` (and `exit`/`quit` as a fallback) and closes the pipe.
#   - Clears `::uci::uciInfo(pipe$n)`.
#   - If `uciok` is false, shows a warning `tk_messageBox`.
################################################################################
    proc closeUCIengine { n { uciok 1 } } {
        global windowsOS ::uci::uciInfo
        
        set pipe $uciInfo(pipe$n)
        # Check the pipe is not already closed:
        if {$pipe == ""} { return }
        
        after cancel "::uci::closeUCIengine $n 0"
        fileevent $pipe readable {}
        
        if {! $uciok } {
            tk_messageBox -title "Scid: error closing UCI engine" \
                    -icon warning -type ok -message "Not an UCI engine"
        }
        
        # Some engines in analyze mode may not react as expected to "quit"
        # so ensure the engine exits analyze mode first:
        catch { puts $pipe "stop" ; puts $pipe "quit" }
        # last resort : try to kill the engine (TODO if Windows : no luck, welcome zombies !)
        # No longer try to kill the engine as :
        # - it does not work on Windows
        # - Rybka MP uses processes instead of threads : killing the main process will leave the children processes running
        # - engines should normally exit
        # if { ! $windowsOS } { catch { exec -- kill -s INT [ pid $pipe ] }  }
        
        catch { flush $pipe }
        catch { close $pipe }
        set uciInfo(pipe$n) ""
    }
################################################################################
# ::uci::sc_move_add
#   Plays a list of UCI long-notation moves on the current position.
# Visibility:
#   Public.
# Inputs:
#   - moves: List of UCI moves (e.g. `e2e4`, `e7e8q`). Leading piece letters
#     (e.g. `Ne7e5`) are ignored.
# Returns:
#   - 0 on success; 1 if a move cannot be entered.
# Side effects:
#   - Calls `sc_move add` for each parsed move.
################################################################################
    proc sc_move_add { moves } {
        
        foreach m $moves {
            # get rid of leading piece
            set c [string index $m 0]
            if {$c == "K" || $c == "Q" || $c == "R" || $c == "B" || $c == "N"} {
                set m [string range $m 1 end]
            }
            set s1 [string range $m 0 1]
            set s1 [::board::sq $s1]
            set s2 [string range $m 2 3]
            set s2 [::board::sq $s2]
            if {[string length $m] > 4} {
                set promo [string range $m 4 end]
                switch -- $promo {
                    q { set p 2}
                    r { set p 3}
                    b { set p 4}
                    n { set p 5}
                    default { return 1 }
                }
                if { [catch { sc_move add $s1 $s2 $p } ] } { return 1 }
            } else  {
                if { [catch { sc_move add $s1 $s2 0 } ] } { return 1 }
            }
        }
        return 0
    }
################################################################################
# ::uci::formatPv
#   Formats a PV expressed in UCI long notation into a readable move list.
# Visibility:
#   Public.
# Inputs:
#   - moves: List of UCI moves.
#   - fen: Optional FEN to start from. Defaults to the current game position.
# Returns:
#   - A space-separated list of moves as reported by `sc_game info previousMoveNT`.
# Side effects:
#   - Pushes a temporary game (`sc_game push`) and pops it on completion.
#   - If `fen` is provided, uses `sc_game startBoard $fen`.
#   - Uses `::uci::sc_move_add` to apply moves.
################################################################################
    proc formatPv { moves { fen "" } } {
        # Push a temporary copy of the current game:
        if {$fen != ""} {
            sc_game push
            sc_game startBoard $fen
        } else  {
            sc_game push copyfast
        }
        set tmp ""
        foreach m $moves {
            if { [sc_move_add $m] == 1 } { break }
            set prev [sc_game info previousMoveNT]
            append tmp " $prev"
        }
        set tmp [string trim $tmp]
        
        # Pop the temporary game:
        sc_game pop

        return $tmp
    }
################################################################################
# ::uci::formatPvAfterMoves
#   Formats a PV after first applying one or more SAN moves.
# Visibility:
#   Public.
# Inputs:
#   - played_moves: SAN move(s) to apply before formatting the PV.
#   - moves: PV moves in UCI long notation.
# Returns:
#   - A space-separated list of moves as reported by `sc_game info previousMoveNT`.
# Side effects:
#   - Pushes a temporary game (`sc_game push copyfast`) and pops it on completion.
#   - Applies `played_moves` via `sc_move addSan`.
#   - Uses `::uci::sc_move_add` to apply the PV moves.
################################################################################
    proc formatPvAfterMoves { played_moves moves } {
        sc_game push copyfast
        sc_move addSan $played_moves
        
        set tmp ""
        foreach m $moves {
            if { [sc_move_add $m] == 1 } {
                break
            }
            set prev [sc_game info previousMoveNT]
            append tmp " $prev"
        }
        set tmp [string trim $tmp]
        
        # Pop the temporary game:
        sc_game pop

        return $tmp
    }
}
###
### End of file: uci.tcl
###
