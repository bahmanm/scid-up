########################################################################
# Copyright (C) 2020 Fulvio Benini
#
# This file is part of Scid (Shane's Chess Information Database).
# Scid is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.

### Manage the communication with chess engines

# Communication takes place through the exchange of messages.
# Every local or remote client can send a message and the reply will be
# broadcasted to all the clients.
# Events:
# connection local or remote    >> InfoConfig
# net client disconnect         >> InfoConfig
# engine crash/local disconnect >> InfoDisconnected
# Messages from clients:
# SetOptions >> InfoConfig
# NewGame    >> InfoReady
# StopGo     >> InfoReady
# Go         >> InfoGo
#            >> InfoPV replies will be sent repeatedly by the engine until a new
#               message is received or one of the Go's limits is reached.
#            >> InfoBestMove if a limit has been reached.
#
# message InfoConfig {
#   enum Protocol {
#     "uci";
#     "network";
#   }
#   Protocol protocol = 1;
#
#   repeated string net_clients = 2;
#
#   enum OptionType {
#     "text";
#     "file";
#     "path";
#     "spin";
#     "slider";
#     "check";
#     "combo";
#     "button";
#     "save";
#     "reset";
#   }
#   message Option {
#     string name = 1;
#     string value = 2;
#     OptionType type = 3 [default = text];
#     string default = 4;
#     int32 min = 5;
#     int32 max = 6;
#     repeated string var = 7;
#     bool internal = 8 [default = false];
#   }
#   repeated Option options = 3;
# }
#
# message InfoDisconnected {
#   string error_msg = 1;
# }
#
# message InfoReady {
# }
#
# message InfoGo {
#   string position = 1;
#   repeated Limit limits = 2;
# }
#
# message InfoPV {
#   int32 multipv = 1;
#   int32 depth = 2;
#   int32 seldepth = 3;
#   int32 nodes = 4;
#   int32 nps = 5;
#   int32 hashfull = 6;
#   int32 tbhits = 7;
#   int32 time = 8;
#   int32 score = 9;
#   enum ScoreType {
#     "cp"
#     "mate"
#     "lowerbound"
#     "upperbound"
#   }
#   Score score_type = 10;
#   message ScoreWDL {
#     "win";
#     "draw";
#     "lose";
#   }
#   ScoreWDL score_wdl = 11;
#   string pv = 12;
# }
#
# message InfoBestMove {
#   string best_move = 1;
# }
#
# Sent to the engine to change the value of one or more options.
# message SetOptions {
#   message Option {
#     string name = 1;
#     string value = 2;
#   }
#   repeated Option options = 1;
# }
#
# Sent to the engine to signal a new game or analysis and to specify
# the desired thinking output.
# message NewGame {
#   enum Option {
#     "analysis";
#     "chess960";
#     "ponder";
#     "post_pv";
#     "post_wdl";
#   }
#   repeated Option options = 1;
# }
#
# Sent to the engine to ask it to interrupt a previous Go message.
# message StopGo {
# }
#
# Sent to the engine to ask it to start thinking.
# message Go {
#   string position = 1;
#
#   enum LimitType {
#     "wtime"
#     "btime"
#     "winc"
#     "binc"
#     "movestogo"
#     "movetime"
#     "depth"
#     "nodes"
#     "mate"
#   }
#   message Limit {
#     LimitType limit = 1;
#     uint32 value = 2;
#   }
#   repeated Limit limits = 2;
# }

namespace eval engine {}

################################################################################
# ::engine::setLogCmd
#   Configures hooks for logging engine I/O.
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - recv (command|string, optional): Callback to receive raw lines read from
#     the engine; pass "" to disable.
#   - send (command|string, optional): Callback to receive raw lines sent to the
#     engine; pass "" to disable.
# Returns:
#   - None.
# Side effects:
#   - Writes `::engconn(logRecv_$id)` and `::engconn(logSend_$id)`.
################################################################################
proc ::engine::setLogCmd {id {recv ""} {send ""}} {
    set ::engconn(logRecv_$id) $recv
    set ::engconn(logSend_$id) $send
}

################################################################################
# ::engine::connect
#   Starts a local engine process or connects to a remote engine.
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - callback (command): Handler invoked with reply messages.
#   - exe_or_host (string): Executable path (local) or host:port (network).
#   - args (string|list): Command-line arguments for the local engine.
#   - protocols (list<string>, optional): Supported protocols; first element is
#     used as the active protocol. Supported: "uci", "network".
# Returns:
#   - None.
# Side effects:
#   - Closes any existing connection for `id`.
#   - Creates a channel (process pipe or socket), sets non-blocking line mode,
#     and installs a readable event handler.
#   - Initiates the protocol handshake.
# Notes:
#   - Requires `::engine::setLogCmd` to have been called for `id`.
#   - Throws on connection or handshake setup errors.
################################################################################
proc ::engine::connect {id callback exe_or_host args {protocols {uci}}} {
    if {![info exists ::engconn(logSend_$id)]} {
        error "Set the log commands with ::engine::setLogCmd"
    }
    ::engine::close $id
    if {$protocols eq "network"} {
        set channel [socket {*}[split $exe_or_host :]]
    } else {
        set channel [open "| [list $exe_or_host] $args" "r+"]
    }
    ::engine::init_ $id $channel $callback
    chan configure $channel -buffering line -blocking 0
    ::engine::handshake_ $id $protocols
    chan event $channel readable "::engine::onMessages_ $id $channel"
}

################################################################################
# ::engine::netserver
#   Starts or stops a network server for remote clients.
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - port (string|int, optional): "" to stop listening; 0 to select an
#     automatic port; otherwise an explicit port number.
# Returns:
#   - (string|int): The listening port; empty string if not listening.
# Side effects:
#   - Stops any existing server and closes all connected network clients.
#   - Opens/closes a server socket and updates `::engconn(serverchannel_$id)`.
#   - Accepts new connections via `::engine::connectd_`.
# Notes:
#   - Throws on socket errors.
################################################################################
proc ::engine::netserver {id {port ""}} {
    ::engine::closeServer_ $id
    if {$port == ""} {
        return ""
    }
    set ::engconn(serverchannel_$id) \
        [socket -server [list ::engine::connectd_ $id] $port]

    set sockname [chan configure $::engconn(serverchannel_$id) -sockname]
    return [lindex $sockname 2]
}

################################################################################
# ::engine::close
#   Closes an engine connection and releases associated resources.
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
# Returns:
#   - None.
# Side effects:
#   - Cancels channel readable events.
#   - For local engines, may send StopGo/quit.
#   - Closes the channel and any network server/clients.
#   - Unsets most `::engconn(...)` state for `id` (but preserves
#     `logRecv_$id` / `logSend_$id` by design).
################################################################################
proc ::engine::close {id} {
    if {[info exists ::engconn(channel_$id)]} {
        chan event $::engconn(channel_$id) readable {}
        if {$::engconn(protocol_$id) ne "network"} {
            if {$::engconn(waitReply_$id) eq "Go"} {
                {*}$::engconn(StopGo$id)
            }
            ::engine::rawsend $id "quit"
        }
        ::engine::destroy_ $id
    }
}

################################################################################
# ::engine::pid
#   Returns the process ID of a local engine.
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
# Returns:
#   - (int|string): PID, as returned by Tcl `pid`.
# Side effects:
#   - None.
# Notes:
#   - Throws if the engine is not open.
################################################################################
proc ::engine::pid {id} {
    if {![info exists ::engconn(channel_$id)]} {
        error "The engine is not open"
    }
    return [::pid $::engconn(channel_$id)]
}

################################################################################
# ::engine::send
#   Sends a message to the engine (or queues it until the engine is ready).
# Visibility:
#   Public.
# Inputs:
#   - id (int): Engine slot.
#   - msg (string): Message type (e.g. SetOptions, NewGame, StopGo, Go).
#   - msgData (any, optional): Message payload.
# Returns:
#   - None.
# Side effects:
#   - For network protocol, sends immediately via `::engine::rawsend`.
#   - For local protocol:
#       - Cancels queued Go messages when necessary.
#       - Sends StopGo immediately when required.
#       - Enqueues messages in `::engconn(sendQueue_$id)`.
################################################################################
proc ::engine::send {id msg {msgData ""}} {
    if {![info exists ::engconn(channel_$id)]} {
        error "The engine is not open"
    }

    if {$::engconn(protocol_$id) eq "network"} {
        ::engine::rawsend $id [list $msg $msgData]
        return
    }
    if {$::engconn(waitReply_$id) eq "Go"} {
        set ::engconn(waitReply_$id) "StopGo"
        {*}$::engconn(StopGo$id)
    }
    if {[set idx [lsearch -index 0 $::engconn(sendQueue_$id) "Go"]] != -1} {
        set ::engconn(sendQueue_$id) [lreplace $::engconn(sendQueue_$id) $idx $idx]
    }
    if {$msg eq "StopGo"} {
        set ::engconn(sendQueue_$id) [linsert $::engconn(sendQueue_$id) 0 [list $msg $msgData]]
    } else {
        lappend ::engconn(sendQueue_$id) [list $msg $msgData]
    }
    if {$::engconn(waitReply_$id) == ""} {
        ::engine::done_ $id
    }
}

################################################################################
# ::engine::init_
#   Initialises per-engine connection state.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - channel (channel): Channel connected to the engine.
#   - callback (command): Callback invoked with replies.
# Returns:
#   - None.
# Side effects:
#   - Initialises `::engconn(...)` fields for `id`.
################################################################################
proc ::engine::init_ {id channel callback} {
    set ::engconn(protocol_$id) {}
    set ::engconn(callback_$id) $callback
    set ::engconn(channel_$id) $channel
    set ::engconn(serverchannel_$id) {}
    set ::engconn(netclients_$id) {}
    set ::engconn(waitReply_$id) {}
    set ::engconn(sendQueue_$id) {}

    set ::engconn(options_$id) {}
}

################################################################################
# ::engine::destroy_
#   Tears down engine connection state and optionally emits a local reply.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - localReply (any, optional): Reply message to broadcast after teardown.
# Returns:
#   - None.
# Side effects:
#   - Cancels pending `after` callbacks.
#   - Closes channels and unsets most `::engconn(...)` state for `id` (but
#     preserves `logRecv_$id` / `logSend_$id` by design).
#   - If `localReply` is provided, sends it via `::engine::reply`.
################################################################################
proc ::engine::destroy_ {id {localReply ""}} {
    after cancel "::engine::done_ $id"
    if {[info exists ::engconn(nextHandshake_$id)]} {
        after cancel $::engconn(nextHandshake_$id)
    }

    chan close $::engconn(channel_$id)
    ::engine::closeServer_ $id

    unset ::engconn(protocol_$id)
    unset ::engconn(channel_$id)
    unset ::engconn(serverchannel_$id)
    unset ::engconn(waitReply_$id) ; # the message to be answered
    unset ::engconn(sendQueue_$id) ; # the queue of messages waiting to be sent

    # When the engine's output is parsed its options and PV infos are stored in this vars:
    unset ::engconn(options_$id)
    unset -nocomplain ::engconn(InfoPV_$id)
    unset -nocomplain ::engconn(InfoBestMove_$id)

    unset -nocomplain ::engconn(nextHandshake_$id)

    # Functions that convert messages to UCI.
    unset -nocomplain ::engconn(SetOptions$id)
    unset -nocomplain ::engconn(NewGame$id)
    unset -nocomplain ::engconn(Go$id)
    unset -nocomplain ::engconn(StopGo$id)
    unset -nocomplain ::engconn(parseline$id)

    if {$localReply != ""} {
        set ::engconn(netclients_$id) {}
        ::engine::reply $id $localReply
    }
    unset ::engconn(netclients_$id)
    unset ::engconn(callback_$id)
}

################################################################################
# ::engine::closeServer_
#   Closes the network server and all connected network clients.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
# Returns:
#   - None.
# Side effects:
#   - Closes `::engconn(serverchannel_$id)` and each client channel.
#   - Clears `::engconn(netclients_$id)`.
################################################################################
proc ::engine::closeServer_ {id} {
    if {$::engconn(serverchannel_$id) != ""} {
        chan close $::engconn(serverchannel_$id)
    }
    set ::engconn(serverchannel_$id) ""
    foreach netchannel $::engconn(netclients_$id) {
        chan close [lindex $netchannel 0]
    }
    set ::engconn(netclients_$id) {}
}

################################################################################
# ::engine::handshake_
#   Selects a protocol implementation and performs initial handshake.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - protocols (list<string>): Protocol list; first element becomes active.
# Returns:
#   - None.
# Side effects:
#   - Sets message conversion hooks in `::engconn(...)`.
#   - For UCI, sends `uci` and sets `waitReply`.
# Notes:
#   - Throws on unknown protocol.
################################################################################
proc ::engine::handshake_ {id protocols} {
    set ::engconn(protocol_$id) [lindex $protocols 0]
    switch $::engconn(protocol_$id) {
      "uci" {
        set ::engconn(SetOptions$id) [list ::uci::sendOptions $id]
        set ::engconn(NewGame$id) [list ::uci::sendNewGame $id]
        set ::engconn(Go$id) [list ::uci::sendGo $id]
        set ::engconn(StopGo$id) [list ::engine::rawsend $id "stop"]
        set ::engconn(parseline$id) "::uci::parseline"

        set ::engconn(waitReply_$id) "hello"
        ::engine::rawsend $id "uci"
      }
      "network" {
      }
      default {
        error "Unknown engine protocol"
      }
    }
    unset -nocomplain ::engconn(nextHandshake_$id)
}

################################################################################
# ::engine::connectd_
#   Accepts a network client connection.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - channel (channel): Accepted socket channel.
#   - clientaddr (string): Client IP.
#   - clientport (int): Client port.
# Returns:
#   - None.
# Side effects:
#   - Registers the client in `::engconn(netclients_$id)`.
#   - Configures the channel and installs a readable handler.
#   - Broadcasts an InfoConfig update.
################################################################################
proc ::engine::connectd_ {id channel clientaddr clientport} {
    lappend ::engconn(netclients_$id) [list $channel $clientaddr $clientport]
    chan configure $channel -buffering line -blocking 0
    chan event $channel readable "::engine::forwardNetMsg_ $id $channel"
    ::engine::replyInfoConfig $id
}

################################################################################
# ::engine::forwardNetMsg_
#   Forwards messages received from a network client.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - channel (channel): Client channel.
# Returns:
#   - None.
# Side effects:
#   - On disconnect, removes the client and broadcasts InfoConfig.
#   - Otherwise, forwards each received message to `::engine::send`.
################################################################################
proc ::engine::forwardNetMsg_ {id channel} {
    chan event $channel readable {}

    # A disconnected channel creates a readable event with no input
    if {[chan eof $channel]} {
        chan close $channel
        set idx [lsearch -exact -index 0 $::engconn(netclients_$id) $channel]
        set ::engconn(netclients_$id) [lreplace $::engconn(netclients_$id) $idx $idx]
        ::engine::replyInfoConfig $id
        return
    }
    while {[set msg [chan gets $channel]] != ""} {
        ::engine::send $id {*}$msg
    }
    chan event $channel readable "::engine::forwardNetMsg_ $id $channel"
}

################################################################################
# ::engine::onMessages_
#   Processes readable events from the engine channel.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - channel (channel): Engine channel.
# Returns:
#   - None.
# Side effects:
#   - Reads lines from the channel and logs them (if configured).
#   - Parses input and emits InfoPV / InfoBestMove / InfoReady replies.
#   - On EOF, tears down the connection and emits InfoDisconnected.
################################################################################
proc ::engine::onMessages_ {id channel} {
    chan event $channel readable {}

    # A disconnected channel creates a readable event with no input
    if {[chan eof $channel]} {
        ::engine::destroy_ $id [list InfoDisconnected ""]
        return
    }
    while {[set line [chan gets $channel]] != ""} {
        if {$::engconn(logRecv_$id) != ""} {
            {*}$::engconn(logRecv_$id) $line
        }
        if {$::engconn(protocol_$id) eq "network"} {
            ::engine::reply $id $line
        } elseif {[$::engconn(parseline$id) $id $line]} {
            if {[info exists ::engconn(InfoBestMove_$id)]} {
                if {$::engconn(waitReply_$id) ne "StopGo"} {
                    ::engine::reply $id [list InfoBestMove $::engconn(InfoBestMove_$id)]
                }
                unset ::engconn(InfoBestMove_$id)
            }
            ::engine::done_ $id
        }
        if {[info exists ::engconn(InfoPV_$id)]} {
            if {$::engconn(waitReply_$id) ne "StopGo"} {
                ::engine::reply $id [list InfoPV $::engconn(InfoPV_$id)]
            }
            unset ::engconn(InfoPV_$id)
        }
    }
    chan event $channel readable "::engine::onMessages_ $id $channel"
}

################################################################################
# ::engine::done_
#   Advances the send queue once the engine has finished replying.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
# Returns:
#   - None.
# Side effects:
#   - Clears `waitReply` and drains `sendQueue`.
#   - Squashes sequential SetOptions.
#   - Sends InfoConfig/InfoReady/InfoGo replies as appropriate.
################################################################################
proc ::engine::done_ {id} {
    after cancel "::engine::done_ $id"
    switch $::engconn(waitReply_$id) {
        "hello" {
            if {[info exists ::engconn(nextHandshake_$id)]} {
                after cancel $::engconn(nextHandshake_$id)
                unset ::engconn(nextHandshake_$id)
            }
            ::engine::replyInfoConfig $id
         }
        "SetOptions" { ::engine::replyInfoConfig $id }
        "NewGame" { ::engine::reply $id [list InfoReady ""] }
    }
    set ::engconn(waitReply_$id) ""

    while { [llength $::engconn(sendQueue_$id)] } {
        lassign [lindex $::engconn(sendQueue_$id) 0] msg msgData
        set idx 1
        if {$msg eq "SetOptions"} {
            # Squash sequential SetOptions messages
            while {[lindex $::engconn(sendQueue_$id) $idx 0] eq "SetOptions"} {
                lappend msgData {*}[lindex $::engconn(sendQueue_$id) $idx 1]
                incr idx
            }
        }
        set ::engconn(sendQueue_$id) [lrange $::engconn(sendQueue_$id) $idx end]

        if {$msg eq "StopGo"} {
            # The "StopGo" message was already sent in ::engine::send
            ::engine::reply $id [list InfoReady ""]
            continue
        }
        set ::engconn(waitReply_$id) $msg
        if {$msgData eq ""} {
            {*}$::engconn($msg$id)
        } else {
            {*}$::engconn($msg$id) $msgData
        }
        if {$msg eq "Go"} {
            # Immediately send an InfoGo reply
            ::engine::reply $id [list InfoGo $msgData]
        }
        break
    }
}

################################################################################
# ::engine::reply
#   Broadcasts a reply to the local callback and all connected network clients.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - msg (any): Reply message.
# Returns:
#   - None.
# Side effects:
#   - Invokes the configured callback.
#   - Writes to each connected network client channel.
################################################################################
proc ::engine::reply {id msg} {
    {*}$::engconn(callback_$id) $msg
    foreach netchannel $::engconn(netclients_$id) {
        chan puts [lindex $netchannel 0] $msg
    }
}

################################################################################
# ::engine::replyInfoConfig
#   Broadcasts an InfoConfig message reflecting the current engine state.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
# Returns:
#   - None.
# Side effects:
#   - Calls `::engine::reply`.
################################################################################
proc ::engine::replyInfoConfig {id} {
    ::engine::reply $id [list InfoConfig \
        [list $::engconn(protocol_$id) $::engconn(netclients_$id) $::engconn(options_$id)]]
}

################################################################################
# ::engine::updateOption
#   Updates the stored value for an engine option and returns its option type.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - name (string): Option name.
#   - value (string): New value.
# Returns:
#   - (string): Option type (e.g. "spin", "check", "button"), or "" if the
#     option is not known.
# Side effects:
#   - Updates `::engconn(options_$id)`.
################################################################################
proc ::engine::updateOption {id name value} {
    set idx [lsearch -exact -index 0 $::engconn(options_$id) $name]
    if {$idx != -1} {
        set elem [lindex $::engconn(options_$id) $idx]
        set elem [lreplace $elem 1 1 $value]
        set ::engconn(options_$id) [lreplace $::engconn(options_$id) $idx $idx $elem]
        return [lindex $elem 2]
    }
    return ""
}

################################################################################
# ::engine::rawsend
#   Writes a raw line to the engine channel (and logs it if configured).
# Visibility:
#   Private.
# Inputs:
#   - n (int): Engine slot.
#   - msg (string|list): Message line to send.
# Returns:
#   - None.
# Side effects:
#   - Writes to `::engconn(channel_$n)`.
#   - Invokes `::engconn(logSend_$n)` when configured.
################################################################################
proc ::engine::rawsend {n msg} {
    chan puts $::engconn(channel_$n) $msg
    if {$::engconn(logSend_$n) != ""} {
        {*}$::engconn(logSend_$n) $msg
    }
}

namespace eval uci {}

################################################################################
# ::uci::sendOptions
#   Sends one or more UCI option updates and synchronises with `isready`.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - msgData (list<list<string>>): List of `{name value}` pairs.
# Returns:
#   - None.
# Side effects:
#   - Calls `::engine::rawsend`.
#   - Updates stored option values via `::engine::updateOption`.
################################################################################
proc ::uci::sendOptions {id msgData}  {
    foreach option $msgData {
        lassign $option name value
        set type [::engine::updateOption $id $name $value]
        if {$type eq "button"} {
            ::engine::rawsend $id "setoption name $name"
        } else {
            ::engine::rawsend $id "setoption name $name value $value"
        }
    }
    ::engine::rawsend $id "isready"
}

################################################################################
# ::uci::sendNewGame
#   Sends UCI new-game configuration (AnalyseMode, Chess960, WDL, Ponder) and
#   then issues `ucinewgame` + `isready`.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - msgData (list<string>): NewGame option flags.
# Returns:
#   - None.
# Side effects:
#   - Conditionally calls `::engine::rawsend` to set options only when the engine
#     advertises the corresponding UCI options in `::engconn(options_$id)`.
#   - Calls `::engine::rawsend` for `ucinewgame` and `isready`.
################################################################################
proc ::uci::sendNewGame {id msgData} {
    if {[lsearch -index 0 $::engconn(options_$id) "UCI_AnalyseMode"] != -1} {
        set analyze [expr {"analysis" in $msgData ? "true" :"false"}]
        ::engine::rawsend $id "setoption name UCI_AnalyseMode value $analyze"
    }
    if {[lsearch -index 0 $::engconn(options_$id) "UCI_Chess960"] != -1} {
        set chess960 [expr {"chess960" in $msgData ? "true" :"false"}]
        ::engine::rawsend $id "setoption name UCI_Chess960 value $chess960"
    }
    if {[lsearch -index 0 $::engconn(options_$id) "UCI_ShowWDL"] != -1} {
        set wdl [expr {"post_wdl" in $msgData ? "true" :"false"}]
        ::engine::rawsend $id "setoption name UCI_ShowWDL value $wdl"
    }
    if {[lsearch -index 0 $::engconn(options_$id) "Ponder"] != -1} {
        set ponder [expr {"ponder" in $msgData ? "true" :"false"}]
        ::engine::rawsend $id "setoption name Ponder value $ponder"
    }
    ::engine::rawsend $id "ucinewgame"
    ::engine::rawsend $id "isready"
}


################################################################################
# ::uci::sendGo
#   Sends a UCI `position` command followed by a `go` command.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - msgData (list): `{position limits}` where `position` is a UCI position
#     command string and `limits` is a list of go-limit tokens.
# Returns:
#   - None.
# Side effects:
#   - Calls `::engine::rawsend`.
################################################################################
proc ::uci::sendGo {id msgData} {
    lassign $msgData position limits
    if {$limits == ""} {
        set limits "infinite"
    } else {
        set limits [join $limits]
    }
    ::engine::rawsend $id $position
    ::engine::rawsend $id "go $limits"
}




################################################################################
# ::uci::parseline
#   Parses a single UCI output line and updates the engine state.
# Visibility:
#   Private.
# Inputs:
#   - id (int): Engine slot.
#   - line (string): Raw UCI output line.
# Returns:
#   - (int): 1 when a “reply boundary” is reached (e.g. readyok/uciok/bestmove);
#     otherwise 0.
# Side effects:
#   - Populates `::engconn(options_$id)` from `option`/`id name` lines.
#   - Populates `::engconn(InfoPV_$id)` and `::engconn(InfoBestMove_$id)`.
################################################################################
proc ::uci::parseline {id line} {
    if {[string match "info *" $line]} {
        set beginPV [string first " pv " $line]
        if {$beginPV < 0} {
            return 0
        }
        set endPV end
        set pv [string range $line [expr {$beginPV + 4}] end]
        set tokens [list multipv depth seldepth nodes nps hashfull tbhits time score \
                         currmove currmovenumber currline cpuload string refutation]
        foreach token $tokens {
            set nextToken [string first $token $pv]
            if {$nextToken >= 0} {
                set endPV [expr {$beginPV + 3 + $nextToken}]
                set pv [string trim [string range $line [expr {$beginPV + 4}] $endPV]]
                break
            }
        }
        set tokens [list multipv depth seldepth nodes nps hashfull tbhits time score]
        set ::engconn(InfoPV_$id) [list 1 {} {} {} {} {} {} {} {} {} {} $pv]
        set idx -1
        foreach elem [split [string replace $line $beginPV $endPV]] {
            if {[string is integer -strict $elem]} {
                if {$idx >= 0 && $idx <= 8} {
                    lset ::engconn(InfoPV_$id) $idx $elem
                } elseif {$idx == 10} {
                    lset ::engconn(InfoPV_$id) $idx end+1 $elem
                }
            } else {
                if {$idx >= 8 && $elem in {cp mate lowerbound upperbound wdl}} {
                    if {$elem eq "wdl"} {
                        set idx 10
                    } else {
                        lset ::engconn(InfoPV_$id) 9 $elem
                    }
                } else {
                    set idx [lsearch -exact $tokens $elem]
                }
            }
        }
        return 0
    }

    if {[string match "bestmove *" $line]} {
        lassign [split $line] -> ::engconn(InfoBestMove_$id) ponder ponder_move
        #TODO:
        # lassign [lsearch -inline -index 0 $::engconn(options_$id) "Ponder"] -> do_ponder
        # if {$do_ponder eq "true" && $ponder eq "ponder"}
        #   set ::engconn(waitReply_$id) "Go?"
        #   ::engine::rawsend $id position ...
        #   ::engine::rawsend $id go ponder ...
        return 1
    }

    if {$line eq "readyok" || $line eq "uciok"} {
        return 1
    }

    if {[string match "option *" $line]} {
        set tokens {name type default min max var}
        set name {}
        set type {}
        set default {}
        set min {}
        set max {}
        set var {}

        set unknown {}
        set currToken "unknown"
        foreach word [split $line] {
            if {[set idx [lsearch -exact $tokens $word]] != -1} {
                if {$word ne "var"} {
                    # remove the tokens that should appear only once
                    set tokens [lreplace $tokens $idx $idx]
                }
                set currToken $word
            } else {
                lappend $currToken $word
            }
        }
        set internal [expr {$name in {Ponder UCI_AnalyseMode UCI_Chess960 UCI_ShowWDL}}]
        if {$type eq "string"} {
            if {[string match -nocase "*file*" $name]} {
                set type "file"
            } elseif {[string match -nocase "*path*" $name]} {
                set type "path"
            }
        }
        lappend ::engconn(options_$id) [list [join $name] [join $default] \
            [join $type] [join $default] [join $min] [join $max] $var $internal]
        return 0
    }

    if {[string match "id name *" $line]} {
        set name [string range $line 8 end]
        lappend ::engconn(options_$id) [list myname $name string $name {} {} {} 1]
        return 0
    }

    #unknown
    return 0
}
