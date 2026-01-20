### sound.tcl
### Functions for playing sound files to announce moves.
### Part of Scid. Copyright (C) Shane Hudson 2004.
### Copyright (C) 2013 Fulvio Benini
###
### Uses the free Tcl/Tk sound package "Snack", which comes with
### most Tcl distributions. See http://www.speech.kth.se/snack/

### When another application is using the audio device, sound playback may fail.
### Pending sounds are reset after 5 seconds, limiting the maximum playable sound length.

namespace eval ::utils::sound {}

set ::utils::sound::pipe ""
set ::utils::sound::hasSound 0
set ::utils::sound::isPlayingSound 0
set ::utils::sound::soundQueue {}
set ::utils::sound::soundFiles [list \
    King Queen Rook Bishop Knight CastleQ CastleK Back Mate Promote Check \
    a b c d e f g h x 1 2 3 4 5 6 7 8 move alert]

# soundMap
#
#   Maps characters in a move to sounds.
#   Before this map is used, "O-O-O" is converted to "q" and "O-O" to "k"
#   Also note that "U" (undo) is used for taking back a move.
#
array set ::utils::sound::soundMap {
  K King Q Queen R Rook B Bishop N Knight k CastleK q CastleQ
  x x U Back # Mate = Promote  + Check alert alert
  a a b b c c d d e e f f g g h h
  1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8
} 


################################################################################
# ::utils::sound::Setup
#   Initialises move-sound support for the current session.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Sets `::utils::sound::hasSound` and may set `::utils::sound::pipe`.
#   - Attempts to load Snack (`package require snack 2.0`) and, on Windows, may
#     start `scidsnd.exe` as a pipe fallback.
#   - When using the pipe fallback, configures `fileevent` to call
#     `::utils::sound::SoundFinished` when the helper indicates completion.
#   - When using Snack, creates `sound_*` objects and calls
#     `::utils::sound::ReadFolder`.
################################################################################
proc ::utils::sound::Setup {} {
  variable hasSound
  variable soundFiles
  variable soundFolder

  set hasSound 1
  if {[catch {package require snack 2.0}]} {
    if {$::windowsOS} {
      catch {
        set ::utils::sound::pipe [open "| scidsnd.exe" "r+"]
        fconfigure $::utils::sound::pipe -blocking 0 -buffering line
        fileevent $::utils::sound::pipe readable {
          gets $::utils::sound::pipe
          ::utils::sound::SoundFinished
        }
      }
    }
    if { $::utils::sound::pipe == "" } { set hasSound 0 }
  } else {
    # Set up sounds. Each sound will be empty until a WAV file for it is found.
    foreach soundFile $soundFiles {
      ::snack::sound sound_$soundFile
    }
    ::utils::sound::ReadFolder
  }
}


################################################################################
# ::utils::sound::ReadFolder
#   Scans the configured sound folder for recognised WAV filenames.
# Visibility:
#   Public.
# Inputs:
#   - newFolder (string, optional): When non-empty, clears `soundFolder` before
#     scanning.
# Returns:
#   - (int): Number of recognised sound files found.
# Side effects:
#   - Reads filesystem paths under `::utils::sound::soundFolder`.
#   - When using Snack (`::utils::sound::pipe` is empty), configures `sound_*`
#     objects with their `-file` path.
#   - May clear `::utils::sound::soundFolder` when `newFolder` is provided.
################################################################################
proc ::utils::sound::ReadFolder {{newFolder ""}} {
  variable soundFiles
  variable soundFolder
  
  if {$newFolder != ""} { set soundFolder "" }
  
  set count 0
  foreach soundFile $soundFiles {
    set f [file join $soundFolder $soundFile.wav]
    if {[file readable $f]} {
      if { $::utils::sound::pipe == "" } {
        sound_$soundFile configure -file $f
      }
      incr count
    }
  }
  return $count
}


################################################################################
# ::utils::sound::AnnounceMove
#   Enqueues sounds representing the given move notation.
# Visibility:
#   Public.
# Inputs:
#   - move (string): Move text (typically SAN) processed via `::untrans`.
# Returns:
#   - None.
# Side effects:
#   - Returns immediately when `::utils::sound::hasSound` is false.
#   - Calls `::utils::sound::CancelSounds` then enqueues one or more sounds via
#     `::utils::sound::PlaySound`.
################################################################################
proc ::utils::sound::AnnounceMove {move} {
  variable hasSound
  variable soundMap
  
  if {! $hasSound} { return }
  
  if {[string range $move 0 4] == "O-O-O"} { set move q }
  if {[string range $move 0 2] == "O-O"} { set move k }
  set move [::untrans $move]
  set parts [split $move ""]
  set soundList {}
  foreach part $parts {
    if {[info exists soundMap($part)]} {
      lappend soundList sound_$soundMap($part)
    }
  }
  if {[llength $soundList] > 0} {
    CancelSounds
    foreach s $soundList {
      PlaySound $s
    }
  }
}

################################################################################
# ::utils::sound::AnnounceNewMove
# Visibility:
#   Public.
# Inputs:
#   - move (string): Move text (typically SAN).
# Returns:
#   - None.
# Side effects:
#   - When `::utils::sound::announceNew` is true, calls
#     `::utils::sound::AnnounceMove`.
################################################################################
proc ::utils::sound::AnnounceNewMove {move} {
  if {$::utils::sound::announceNew} { AnnounceMove $move }
}

################################################################################
# ::utils::sound::AnnounceForward
# Visibility:
#   Public.
# Inputs:
#   - move (string): Move text (typically SAN).
# Returns:
#   - None.
# Side effects:
#   - When `::utils::sound::announceForward` is true, calls
#     `::utils::sound::AnnounceMove`.
################################################################################
proc ::utils::sound::AnnounceForward {move} {
  if {$::utils::sound::announceForward} { AnnounceMove $move }
}

################################################################################
# ::utils::sound::AnnounceBack
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - When `::utils::sound::announceBack` is true, calls
#     `::utils::sound::AnnounceMove` with `U` (undo).
################################################################################
proc ::utils::sound::AnnounceBack {} {
  if {$::utils::sound::announceBack} { AnnounceMove U }
}

################################################################################
# ::utils::sound::SoundFinished
#   Handles completion of the current sound and advances the queue.
# Visibility:
#   Internal.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Cancels any pending `after` call that would invoke
#     `::utils::sound::CancelSounds`.
#   - Sets `::utils::sound::isPlayingSound` to 0.
#   - Calls `::utils::sound::CheckSoundQueue`.
################################################################################
proc ::utils::sound::SoundFinished {} {
  after cancel ::utils::sound::CancelSounds
  set ::utils::sound::isPlayingSound 0
  CheckSoundQueue
}


################################################################################
# ::utils::sound::CancelSounds
#   Stops playback and clears any queued sounds.
# Visibility:
#   Internal.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Returns immediately when `::utils::sound::hasSound` is false.
#   - When using the pipe helper (`::utils::sound::pipe` non-empty), writes
#     `stop` to the pipe.
#   - When using Snack, calls `snack::audio stop`.
#   - Clears `::utils::sound::soundQueue` and sets
#     `::utils::sound::isPlayingSound` to 0.
################################################################################
proc ::utils::sound::CancelSounds {} {
  if {! $::utils::sound::hasSound} { return }

  if { $::utils::sound::pipe != "" } {
    puts $::utils::sound::pipe "stop"
  } else {
    snack::audio stop
  }
  set ::utils::sound::soundQueue {}
  set ::utils::sound::isPlayingSound 0
}

################################################################################
# ::utils::sound::PlaySound
# Visibility:
#   Internal.
# Inputs:
#   - sound (string): Snack sound object name (e.g. `sound_King`) or other sound
#     command understood by `::utils::sound::CheckSoundQueue`.
# Returns:
#   - None.
# Side effects:
#   - Returns immediately when `::utils::sound::hasSound` is false.
#   - Appends `sound` to `::utils::sound::soundQueue`.
#   - Schedules `::utils::sound::CheckSoundQueue` via `after idle`.
################################################################################
proc ::utils::sound::PlaySound {sound} {
  if {! $::utils::sound::hasSound} { return }
  lappend ::utils::sound::soundQueue $sound
  after idle ::utils::sound::CheckSoundQueue
}

################################################################################
# ::utils::sound::CheckSoundQueue
#   Starts playing the next available sound, if any.
# Visibility:
#   Internal.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Dequeues one entry from `::utils::sound::soundQueue`.
#   - Sets `::utils::sound::isPlayingSound` to 1 while a sound is in progress.
#   - When using the pipe helper (`::utils::sound::pipe` non-empty), writes the
#     next sound’s filename to the pipe.
#   - When using Snack, calls the dequeued sound command’s
#     `play -blocking 0 -command ::utils::sound::SoundFinished` (errors are
#     ignored) and schedules `::utils::sound::CancelSounds` after 5 seconds.
################################################################################
proc ::utils::sound::CheckSoundQueue {} {
  variable soundQueue
  variable isPlayingSound
  if {$isPlayingSound} { return }
  if {[llength $soundQueue] == 0} { return }
  
  set next [lindex $soundQueue 0]
  set soundQueue [lrange $soundQueue 1 end]
  set isPlayingSound 1
  if { $::utils::sound::pipe != "" } {
    set next [string range $next 6 end]
    set f [file join $::utils::sound::soundFolder $next.wav]
    puts $::utils::sound::pipe "[file nativename $f]"
  } else {
    catch { $next play -blocking 0 -command ::utils::sound::SoundFinished }
    after 5000 ::utils::sound::CancelSounds
  }
}


################################################################################
# ::utils::sound::OptionsDialog
#   Populates the sound configuration UI within the given container.
# Visibility:
#   Public.
# Inputs:
#   - w (string): Parent widget path to populate.
# Returns:
#   - None.
# Side effects:
#   - Creates and packs Tk widgets beneath `w`.
#   - Reads `::utils::sound::hasSound` and shows a status label when sound is
#     disabled.
################################################################################
proc ::utils::sound::OptionsDialog { w } {
     if { ! $::utils::sound::hasSound} {
        ttk::label $w.status -text [tr SoundsSoundDisabled]
        pack $w.status -side bottom
    }
    ttk::checkbutton $w.n -variable ::utils::sound::announceNew -text [tr SoundsAnnounceNew]
    ttk::checkbutton $w.f -variable ::utils::sound::announceForward -text [tr SoundsAnnounceForward]
    ttk::checkbutton $w.b -variable ::utils::sound::announceBack -text [tr SoundsAnnounceBack]
    pack $w.n $w.f $w.b -side top -anchor w -padx "0 5"
}

################################################################################
# ::utils::sound::GetDialogChooseFolder
#   Prompts for a folder and updates the associated entry widget.
# Visibility:
#   Public.
# Inputs:
#   - widget (string): Entry widget path to update when a folder is chosen.
# Returns:
#   - None.
# Side effects:
#   - Shows a `tk_chooseDirectory` dialog.
#   - When a new folder is chosen, calls
#     `::utils::sound::OptionsDialogChooseFolder` and updates `widget` text.
################################################################################
proc ::utils::sound::GetDialogChooseFolder { widget } {
    set newFolder [tk_chooseDirectory \
	                       -initialdir $::utils::sound::soundFolder \
	                       -title "[tr ScidUp]: $::tr(SoundsFolder)" -parent [winfo toplevel $widget] ]
    # If the user selected a different folder to look in, read it
    # and tell the user how many sound files were found there.
    if {$newFolder != "" && $newFolder != $::utils::sound::soundFolder } {
        if { [::utils::sound::OptionsDialogChooseFolder $newFolder] } {
            $widget delete 0 end
            $widget insert end $newFolder
        }
    }
}

################################################################################
# ::utils::sound::OptionsDialogChooseFolder
#   Sets the sound folder and reports how many sound files are available.
# Visibility:
#   Public.
# Inputs:
#   - newFolder (string): Folder path selected by the user.
# Returns:
#   - (int): Number of recognised sound files found in the folder.
# Side effects:
#   - Sets `::utils::sound::soundFolder`.
#   - Calls `::utils::sound::ReadFolder`.
#   - Shows a `tk_messageBox` informational message.
################################################################################
proc ::utils::sound::OptionsDialogChooseFolder { newFolder } {
    set ::utils::sound::soundFolder [file nativename $newFolder]
    set numSoundFiles [::utils::sound::ReadFolder]
    tk_messageBox -title "[tr ScidUp]: Sound Files" -type ok -icon info -parent .resDialog \
	        -message "Found $numSoundFiles of [llength $::utils::sound::soundFiles] sound files in $::utils::sound::soundFolder"
    return $numSoundFiles
}

################################################################################
# ::utils::sound::OptionsDialogOK
#   Applies the Sounds options dialog values and closes the dialog.
# Visibility:
#   Internal.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Releases any grab on `.soundOptions` and destroys the toplevel.
#   - Copies `*_temp` variables into `::utils::sound::soundFolder`,
#     `::utils::sound::announceNew`, `::utils::sound::announceForward`, and
#     `::utils::sound::announceBack`.
#   - When the sound folder changes and is non-empty, calls
#     `::utils::sound::ReadFolder` and shows an informational `tk_messageBox`.
################################################################################
proc ::utils::sound::OptionsDialogOK {} {
  variable soundFolder
  
  # Destroy the Sounds options dialog
  set w .soundOptions
  catch {grab release $w}
  destroy $w
  
  set isNewSoundFolder 0
  if {$soundFolder != $::utils::sound::soundFolder_temp} {
    set isNewSoundFolder 1
  }
  
  # Update the user-settable sound variables:
  foreach v {soundFolder announceNew announceForward announceBack} {
    set ::utils::sound::$v [set ::utils::sound::${v}_temp]
  }
  
  # If the user selected a different folder to look in, read it
  # and tell the user how many sound files were found there.
  
  if {$isNewSoundFolder  &&  $soundFolder != ""} {
    set numSoundFiles [::utils::sound::ReadFolder]
    tk_messageBox -title "[tr ScidUp]: Sound Files" -type ok -icon info \
	        -message "Found $numSoundFiles of [llength $::utils::sound::soundFiles] sound files in $::utils::sound::soundFolder"
  }
}

# Read the sound files at startup:
::utils::sound::Setup
