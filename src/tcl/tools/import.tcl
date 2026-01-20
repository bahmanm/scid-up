###
### import.tcl: part of Scid.
### Copyright (C) 2000  Shane Hudson.
###

### Import game window

################################################################################
# importPgnGame
#   Opens the "Import PGN" dialog which allows the user to paste/edit PGN text
#   and import it into the current game.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Returns immediately if `.importWin` already exists.
#   - Creates and configures the `.importWin` toplevel and its widgets/menus.
#   - Reads and writes widget state (text contents, selection, focus).
#   - Calls `::game::Clear` and `sc_game import` when the user clicks Import.
#   - Calls `::notify::GameChanged` on successful import.
################################################################################
proc importPgnGame {} {
  if {[winfo exists .importWin]} { return }
  set w .importWin
  win::createDialog $w
  wm title $w "[tr ScidUp]: $::tr(ImportPGN)"
  wm minsize $w 50 5
  ttk::frame $w.b
  pack $w.b -side bottom -fill x
  set pane [::utils::pane::Create $w.pane edit err 580 300 0.8]
  pack $pane -side top -expand true -fill both
  set edit $w.pane.edit
  autoscrollText both $edit.f $edit.text Treeview
  $edit.text configure -height 12 -width 80 -wrap none -setgrid 1 -state normal
  # Override tab-binding for this widget:
  bind $edit.text <Key-Tab> [list apply {{script} {
    uplevel #0 $script
    return -code break
  } ::} [bind all <Key-Tab>]]
  grid $edit.f -row 0 -column 0 -sticky nesw
  grid rowconfig $edit 0 -weight 1 -minsize 0
  grid columnconfig $edit 0 -weight 1 -minsize 0
  
  # Right-mouse button cut/copy/paste menu:
  menu $edit.text.rmenu -tearoff 0
  $edit.text.rmenu add command -label "Cut" -command [list tk_textCut $edit.text]
  $edit.text.rmenu add command -label "Copy" -command [list tk_textCopy $edit.text]
  $edit.text.rmenu add command -label "Paste" -command [list tk_textPaste $edit.text]
  $edit.text.rmenu add command -label "Select all" -command [list $edit.text tag add sel 1.0 end]
  bind $edit.text <ButtonPress-$::MB3> [list tk_popup $edit.text.rmenu %X %Y]
  
  autoscrollText y $pane.err.f $pane.err.text Treeview
  $pane.err.text configure -height 4 -width 75 -wrap word -setgrid 1 -state normal
  $pane.err.text insert end $::tr(ImportHelp1)
  $pane.err.text insert end "\n"
  $pane.err.text insert end $::tr(ImportHelp2)
  $pane.err.text configure -state disabled
  pack $pane.err.f -side left -expand true -fill both

  ttk::button $w.b.paste -text "$::tr(PasteCurrentGame) (Alt-P)" -command {
    .importWin.pane.edit.text delete 1.0 end
    setLanguageTemp E
    .importWin.pane.edit.text insert end [sc_game pgn -width 70]
    setLanguageTemp $::language
    .importWin.pane.err.text configure -state normal
    .importWin.pane.err.text delete 1.0 end
    .importWin.pane.err.text configure -state disabled
  }
  ttk::button $w.b.clear -text "$::tr(Clear) (Alt-C)" -command {
    .importWin.pane.edit.text delete 1.0 end
    .importWin.pane.err.text configure -state normal
    .importWin.pane.err.text delete 1.0 end
    .importWin.pane.err.text configure -state disabled
  }
  ttk::button $w.b.ok -text "$::tr(Import) (Alt-I)" -command {
    if {[::game::Clear] eq "cancel"} { return }
    set err [catch {sc_game import \
          [.importWin.pane.edit.text get 1.0 end]} result]
    .importWin.pane.err.text configure -state normal
    .importWin.pane.err.text delete 1.0 end
    .importWin.pane.err.text insert end $result
    .importWin.pane.err.text configure -state disabled
    if {! $err} {
      ::notify::GameChanged
    }
  }
  ttk::button $w.b.cancel -textvar ::tr(Close) -command {
    destroy .importWin; focus .
  }
  pack $w.b.paste $w.b.clear -side left -padx 5 -pady "15 5"
  packdlgbuttons $w.b.cancel $w.b.ok
  # Paste the current selected text automatically:
  # if {[catch {$w.pane.edit.text insert end [selection get]}]} {
  # ?
  # }
  # Select all of the pasted text:
  $w.pane.edit.text tag add sel 1.0 end
  
  bind $w <F1> { helpWindow Import }
  bind $w <Alt-i> { .importWin.b.ok invoke }
  bind $w <Alt-p> { .importWin.b.paste invoke }
  bind $w <Alt-c> { .importWin.b.clear invoke }
  bind $w <Escape> { .importWin.b.cancel invoke }
  # bind $w.pane.edit.text <Any-KeyRelease> { .importWin.b.ok invoke }
  focus $w.pane.edit.text
}


################################################################################
# importClipboardGame
#   Opens the import dialog and attempts to paste PGN text from the clipboard.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Opens the import dialog via `importPgnGame`.
#   - Attempts to paste from the clipboard/selection into the import text widget.
################################################################################
proc importClipboardGame {} {
  importPgnGame
  catch {event generate .importWin.pane.edit.text <<Paste>>}
  # Paste the current selected text automatically if no data was pasted from clipboard:
  if { [ .importWin.pane.edit.text get 1.0 end ] == "\n" } {
    catch { .importWin.pane.edit.text insert end [selection get] }
  }
}

################################################################################
# importPgnLine
#   Opens the import dialog and pre-populates it with a supplied PGN line.
# Visibility:
#   Public.
# Inputs:
#   - line (string): PGN text to insert into the import text widget.
# Returns:
#   - None.
# Side effects:
#   - Opens the import dialog via `importPgnGame`.
#   - Replaces the import text widget content with `line` and selects it.
#   - Focuses the import text widget.
################################################################################
proc importPgnLine {line} {
  importPgnGame
  set w .importWin.pane.edit.text
  $w delete 1.0 end
  $w insert end $line
  $w tag add sel 1.0 end
  focus $w
}

################################################################################
# importMoveList
#   Imports a SAN move list (in the current language) into the current game.
# Visibility:
#   Public.
# Inputs:
#   - line (string): SAN moves (or a move list fragment) to add.
# Returns:
#   - None.
# Side effects:
#   - Calls `sc_move start` and `sc_move addSan` (mutates the current game).
#   - Calls `updateBoard -pgn`.
################################################################################
proc importMoveList {line} {
  sc_move start
  sc_move addSan $line
  updateBoard -pgn
}
################################################################################
# importMoveListTrans
#   Imports a SAN move list, first translating it to English via `untrans`.
# Visibility:
#   Public.
# Inputs:
#   - line (string): SAN moves (possibly translated) to add.
# Returns:
#   - None.
# Side effects:
#   - Reads `sc_game firstMoves` to determine whether the current game is empty.
#   - Shows a confirmation dialog if the current game already has moves.
#   - Calls `untrans`, `sc_move start`, `sc_move addSan`, and `updateBoard -pgn`
#     when the user confirms import.
################################################################################
proc importMoveListTrans {line} {
  set doImport 0
    if {[llength [sc_game firstMoves 1]] == 0} {
      set doImport 1
    } elseif {[tk_messageBox -message [::tr "OverwriteExistingMoves"] -type yesno -icon question ] == yes} {
      set doImport 1
    }
  if {$doImport} {
    set line [untrans $line]
    sc_move start
    sc_move addSan $line
    updateBoard -pgn
  }
}


### Import file of Pgn games:
################################################################################
# importPgnFile
#   Imports one or more PGN files into a database, showing a progress window.
# Visibility:
#   Public.
# Inputs:
#   - base (int|string): Database handle/index to import into. This argument is
#     optional in the procedure signature, but callers typically provide it.
#   - fnames (list|string): Either a list of file paths to import, or an empty
#     string to prompt the user to choose files.
# Returns:
#   - None.
# Side effects:
#   - Opens a file selection dialog when `fnames` is empty (`tk_getOpenFile`).
#   - Updates `::initialDir(pgn)` after file selection.
#   - Creates and updates the `.ipgnWin` import progress window.
#   - Calls `sc_base import` for each file (mutates the database).
#   - Calls `after idle "::notify::DatabaseModified $base"` when finished.
#   - May auto-close the progress window when invoked programmatically and there
#     are no warnings/errors.
################################################################################
proc importPgnFile {{base} {fnames ""}} {
  if {$fnames == ""} {
      set ftypes { { "Portable Game Notation files" {".pgn" ".PGN"} } }
    lappend ftypes { "Text files" {".txt" ".TXT"} }
    lappend ftypes { "All files" {"*"} }

    set fnames [tk_getOpenFile -multiple 1 -initialdir $::initialDir(pgn) -filetypes $ftypes -title "$::tr(ImportingIn) [file tail [sc_base filename $base] ]" ]
    if {$fnames == ""} { return }
    set ::initialDir(pgn) [file dirname [lindex $fnames 0]]
    set autoclose 0
  } else {
    set autoclose 1
  }
  
  set w .ipgnWin
  if {[winfo exists $w]} { destroy $w }
  win::createDialog $w
  wm title $w "[tr ScidUp]: $::tr(ImportingFiles) [file tail [sc_base filename $base] ]"

  ttk::frame $w.buttons
  canvas $w.progress -width 400 -height 20 -bg white -relief solid -border 1 -highlightthickness 0
  $w.progress create rectangle 0 0 0 0 -fill DodgerBlue3 -outline DodgerBlue3 -tags bar
  $w.progress create text 395 10 -anchor e -font font_Regular -tags time \
    -fill black -text "0:00 / 0:00"

  ttk::button $w.buttons.stop -textvar ::tr(Stop) -command { progressBarCancel}
  ttk::button $w.buttons.close -textvar ::tr(Close) -state disabled -command [list apply {{w} { focus .; destroy $w }} $w]
  grid $w.progress $w.buttons.stop $w.buttons.close -in $w.buttons
  grid rowconfigure $w.buttons 0 -weight 1
  grid columnconfigure $w.buttons 0 -weight 1
    
  autoscrollText both $w.t $w.text TLabel
  $w.text configure -wrap none
  grid $w.t -pady {0 10} -sticky news
  grid $w.buttons -sticky news
  grid rowconfigure $w 0 -weight 1
  grid columnconfigure $w 0 -weight 1

  grab $w.buttons.stop

  busyCursor .
  foreach fname $fnames {
    $w.text insert end "$::tr(ImportingFrom) [file tail $fname]...\n"
    $w.text configure -state disabled
    progressBarSet $w.progress 401 21
    set err [catch {sc_base import $base $fname} result]
    $w.text configure -state normal
    if {$err == 1} {
      set autoclose 0
      $w.text insert end "[ERROR::getErrorMsg]\n$result\n\n"
    } else {
      set nImported [lindex $result 0]
      set warnings [lindex $result 1]
      set str "Imported $nImported "
      if {$nImported == 1} { append str "game" } else { append str "games" }
      if {$warnings == ""} {
        append str " with no PGN errors or warnings."
      } else {
        set autoclose 0
        append str ".\nPGN errors/warnings:\n$warnings"
      }
      $w.text insert end "$str\n\n"
      if {$err == 3} {
        $w.text insert end ".\nINTERRUPTED\n"
        set autoclose 0
        break
      }
    }
  }
  unbusyCursor .

  $w.text configure -state disabled
  $w.buttons.close configure -state normal
  $w.buttons.stop configure -state disabled
  grab release $w.buttons.stop

  after idle "::notify::DatabaseModified $base"
  if { $autoclose } { destroy $w }
}

###
### End of file: import.tcl
###
