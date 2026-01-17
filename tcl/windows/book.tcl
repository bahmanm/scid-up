###
### book.tcl: part of Scid.
### Copyright (C) 2007  Pascal Georges
###
######################################################################
### Book window

namespace eval book {
  set isOpen 0
  set isReadonly 0
  set bookList ""
  set bookPath ""
  set currentBook "" ; # book in form abc.bin
  set currentTuningBook ""
  set bookMoves ""
  set cancelBookExport 0
  set exportCount 0
  set exportMax 3000
  set hashList ""
  set bookSlot 0
  set bookTuningSlot 2
  set oppMovesVisible 0


  ################################################################################
  # ::book::scBookOpen
  #   Opens a book in the specified slot. For the standard book slots
  #   (`$::book::bookSlot` and `$::book::bookTuningSlot`), it closes any
  #   previously tracked open book in that slot.
  # Visibility:
  #   Public.
  # Inputs:
  #   - name: Book filename (e.g. "gm2600.bin"), relative to `$::scidBooksDir`.
  #   - slot: Book slot number (e.g. `$::book::bookSlot`).
  # Returns:
  #   - None.
  # Side effects:
  #   - For `$::book::bookSlot` / `$::book::bookTuningSlot`, may call
  #     `sc_book close` if a previous book is tracked as open.
  #   - Calls `sc_book load` to load the book into the given slot.
  #   - Updates `::book::currentBook` / `::book::currentTuningBook` for known
  #     slots.
  #   - Updates `::book::isReadonly` based on the return value of `sc_book load`.
  ################################################################################
  proc scBookOpen { name slot } {
    if {$slot == $::book::bookSlot} {
      if {$::book::currentBook != ""} {
        sc_book close $::book::bookSlot
      }
      set ::book::currentBook $name
    }
    if {$slot == $::book::bookTuningSlot} {
      if {$::book::currentTuningBook != ""} {
        sc_book close $::book::bookTuningSlot
      }
      set ::book::currentTuningBook $name
    }

    set bn [ file join $::scidBooksDir $name ]
    set ::book::isReadonly [sc_book load $bn $slot]
  }

  ################################################################################
  # ::book::getMove
  #   Selects a move from a book position using the book's cumulative
  #   probabilities.
  # Visibility:
  #   Public.
  # Inputs:
  #   - book: Book filename (e.g. "gm2600.bin"), relative to `$::scidBooksDir`.
  #   - fen: FEN string for the position (currently unused by this
  #     implementation).
  #   - slot: Book slot number to load and query.
  # Returns:
  #   - The selected move (SAN), or "" if the book has no moves for the
  #     position.
  # Side effects:
  #   - Calls `::book::scBookOpen`, which loads the book into the given slot.
  #   - Calls `sc_book moves` for the given slot.
  #   - Calls `sc_book close` only when at least one move exists (current
  #     behaviour).
  ################################################################################
  proc getMove { book fen slot} {
    set tprob 0
    ::book::scBookOpen $book $slot
    lassign [sc_book moves $slot] bookmoves
    if {[llength $bookmoves] == 0} {
      return ""
    }
    set r [expr {(int (rand() * 100))} ]
    for {set i 0} {$i<[llength $bookmoves]} {incr i 2} {
      set m [lindex $bookmoves $i]
      set prob [string range [lindex $bookmoves [expr {$i + 1}] ] 0 end-1 ]
      incr tprob $prob
      if { $tprob >= $r } {
        break
      }
    }
    sc_book close $slot
    return $m
  }

  ################################################################################
  # ::book::togglePositionsDisplay
  # Visibility:
  #   Public.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Toggles `::book::oppMovesVisible`.
  #   - Packs or unpacks `.bookWin.f.fscroll1`.
  ################################################################################
  proc togglePositionsDisplay {} {
    global ::book::oppMovesVisible
    if { $::book::oppMovesVisible == 0} {
      set ::book::oppMovesVisible 1
      pack .bookWin.f.fscroll1 -expand yes -fill both
    } else {
      set ::book::oppMovesVisible 0
      pack forget .bookWin.f.fscroll1
    }
  }

  ################################################################################
  # ::book::open
  #   Opens the book browser window and initialises it to the selected (or last)
  #   book.
  # Visibility:
  #   Public.
  # Inputs:
  #   - name: Optional book filename (e.g. "gm2600.bin"). When empty, uses
  #     `::book::lastBook` if set.
  # Returns:
  #   - None.
  # Side effects:
  #   - Creates `.bookWin` and its child widgets.
  #   - Loads available books from `$::scidBooksDir`.
  #   - Updates `::book::isOpen` and other `::book::*` state.
  #   - Binds UI events (book selection, window destroy).
  #   - Shows a `tk_messageBox` and closes the window if no books are found.
  ################################################################################
  proc open { {name ""} } {
    global ::book::bookList ::book::bookPath ::book::currentBook ::book::isOpen ::book::lastBook

    set w .bookWin

    if {[winfo exists $w]} { return }

    set ::book::isOpen 1

    ::createToplevel $w
    ::setTitle $w $::tr(Book)
    wm resizable $w 0 1

    ttk::frame $w.f

    # load book names
    if { $name == "" && $lastBook != "" } {
      set name $lastBook
    }
    set bookPath $::scidBooksDir
    set bookList [  lsort -dictionary [ glob -nocomplain -directory $bookPath *.bin ] ]

    # No book found
    if { [llength $bookList] == 0 } {
      tk_messageBox -title [tr ScidUp] -type ok -icon error -message "No books found. Check books directory"
      set ::book::isOpen 0
      set ::book::currentBook ""
      ::win::closeWindow $w
      return
    }

    set i 0
    set idx 0
    set tmp {}
    foreach file  $bookList {
      set f [ file tail $file ]
      lappend tmp $f
      if {$name == $f} {
        set idx $i
      }
      incr i
    }
    ttk::combobox $w.f.combo -width 12 -values $tmp

    catch { $w.f.combo current $idx }
    pack $w.f.combo

    # text displaying book moves
    autoscrollText y $w.f.fscroll $w.f.text Treeview
    $w.f.text configure -wrap word -state disabled -width 12

    ttk::button $w.f.b -text $::tr(OtherBookMoves)  -command { ::book::togglePositionsDisplay }
    ::utils::tooltip::Set $w.f.b $::tr(OtherBookMovesTooltip)

    autoscrollText y $w.f.fscroll1 $w.f.text1 Treeview
    $w.f.text1 configure -wrap word -state disabled -width 12

    pack $w.f.fscroll -expand yes -fill both
    pack $w.f.b -fill x
    if { $::book::oppMovesVisible == 1 } {
        pack $w.f.fscroll1 -expand yes -fill both
    }
    pack $w.f -expand 1 -fill both

    bind $w.f.combo <<ComboboxSelected>> ::book::bookSelect
    bind $w <Destroy> [list ::book::closeMainBook]
    # we make a redundant check here, another one is done a few line above
    if { [catch {bookSelect} ] } {
      tk_messageBox -title [tr ScidUp] -type ok -icon error -message "No books found. Check books directory"
      set ::book::isOpen 0
      set ::book::currentBook ""
      ::win::closeWindow .bookWin
    }
  }
  ################################################################################
  # ::book::closeMainBook
  #   Closes the currently open main book.
  # Visibility:
  #   Private.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Calls `sc_book close` for `$::book::bookSlot` when a book is open.
  #   - Updates `::book::isOpen` and `::book::currentBook`.
  #   - Moves focus to `.`.
  ################################################################################
  proc closeMainBook {} {
    if { $::book::currentBook == "" } { return }
    focus .
    sc_book close $::book::bookSlot
    set ::book::isOpen 0
    set ::book::currentBook ""
  }
  ################################################################################
  # ::book::refresh
  #   Refreshes the displayed book moves for the current position.
  # Visibility:
  #   Public.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Requires `.bookWin` to exist; otherwise the proc will error.
  #   - Reads book moves via `sc_book moves` and `sc_book positions`.
  #   - Updates `::book::bookMoves`.
  #   - Rewrites `.bookWin.f.text` and `.bookWin.f.text1` (tags and bindings).
  ################################################################################
  proc refresh {} {
    global ::book::bookMoves

    foreach t [.bookWin.f.text tag names] {
      if { [string match "bookMove*" $t] } {
        .bookWin.f.text tag delete $t
      }
    }
    foreach t [.bookWin.f.text1 tag names] {
      if { [string match "bookMove*" $t] } {
        .bookWin.f.text1 tag delete $t
      }
    }

    set engine_names [list "Unknown-Engine" "Stockfish 12" "Komodo Dragon" "Houdini 6" \
                           "Komodo 14" "Lc0" "CCRL elo 3200+ engines" "Strong Engine" \
                           "TCEC Engine" "CCC Engine" "Stockfish 13"]

    lassign [sc_book moves $::book::bookSlot] bookMoves engine_eval
    set sortedBookMoves {}
    foreach {move count} $bookMoves {score} $engine_eval {
      lappend sortedBookMoves [linsert $score 0 $move $count]
    }
    set sortedBookMoves [lsort -integer -index 2 -decreasing $sortedBookMoves]

    .bookWin.f.text configure -state normal
    .bookWin.f.text delete 1.0 end
    set line 0
    foreach bookMove $sortedBookMoves {
      lassign $bookMove move count score depth name
      incr line
      .bookWin.f.text insert end "[::trans $move]\t$count"
      .bookWin.f.text tag add bookMove$line $line.0 $line.end
      .bookWin.f.text tag bind bookMove$line <ButtonPress-1> [list ::book::makeBookMove $move]

      if {$depth > 0} {
        set score [format "%+.2f" [expr {$score / 100.0}]]
        .bookWin.f.text insert end "\t$score/$depth [lindex $engine_names $name]"
      }
      .bookWin.f.text insert end "\n"
    }
    set bookMovesCount [llength $bookMoves]
    .bookWin.f.text configure -state disabled -height [expr {$bookMovesCount / 2}]


    set oppBookMoves [sc_book positions $::book::bookSlot]
    .bookWin.f.text1 configure -state normal
    .bookWin.f.text1 delete 1.0 end
    for {set i 0} {$i<[llength $oppBookMoves]} {incr i 1} {
      set line [expr {$i +1}]
      set m ""
      append m [::trans [lindex $oppBookMoves $i]]  "\n"
      .bookWin.f.text1 insert end $m
      .bookWin.f.text1 tag add bookMove$line $line.0 $line.end
      .bookWin.f.text1 tag bind bookMove$line <ButtonPress-1> [list ::book::makeBookMove [lindex $oppBookMoves $i]]
    }
    .bookWin.f.text1 configure -state disabled -height [llength $oppBookMoves]
    if { $::book::oppMovesVisible == 0 } {
      pack forget .bookWin.f.scroll1
    }
  }
  ################################################################################
  # ::book::makeBookMove
  #   Plays a move selected from the book.
  # Visibility:
  #   Private.
  # Inputs:
  #   - move: A SAN move string.
  # Returns:
  #   - None.
  # Side effects:
  #   - Calls `addSanMove`, which updates the current game/position.
  ################################################################################
  proc makeBookMove { move } {
    addSanMove $move
  }
  ################################################################################
  # ::book::bookSelect
  #   Applies the currently selected book from the book window.
  # Visibility:
  #   Private.
  # Inputs:
  #   - n: Unused (event callback parameter).
  #   - v: Unused (event callback parameter).
  # Returns:
  #   - None.
  # Side effects:
  #   - Updates `::book::lastBook`.
  #   - Loads the selected book into `$::book::bookSlot` via `::book::scBookOpen`.
  #   - Calls `::book::refresh`.
  ################################################################################
  proc bookSelect { { n "" }  { v  0} } {
    set ::book::lastBook [.bookWin.f.combo get]
    scBookOpen [.bookWin.f.combo get] $::book::bookSlot
    refresh
  }
  ################################################################################
  # ::book::tuning
  #   Opens the book tuning window for editing book move probabilities.
  # Visibility:
  #   Public.
  # Inputs:
  #   - name: Optional book filename to preselect.
  # Returns:
  #   - None.
  # Side effects:
  #   - Creates `.bookTuningWin` and its child widgets.
  #   - Loads available books from `$::scidBooksDir`.
  #   - Shows a `tk_messageBox` and closes the window if no books are found.
  #   - Binds UI events (book selection, window destroy, help).
  #   - Calls `::book::bookTuningSelect` to populate the UI.
  ################################################################################
  proc tuning { {name ""} } {
    global ::book::bookList ::book::bookPath ::book::currentBook ::book::isOpen

    set w .bookTuningWin

    if {[winfo exists $w]} {
      return
    }

    ::createToplevel $w
    ::setTitle $w $::tr(Book)
    # wm resizable $w 0 0

    bind $w <F1> { helpWindow BookTuningWindow }
    setWinLocation $w

    ttk::frame $w.fcombo
    ttk::frame $w.f
    applyThemeColor_background $w
    # load book names
    set bookPath $::scidBooksDir
    set bookList [  lsort -dictionary [ glob -nocomplain -directory $bookPath *.bin ] ]

    # No book found
    if { [llength $bookList] == 0 } {
      tk_messageBox -title [tr ScidUp] -type ok -icon error -message "No books found. Check books directory"
      set ::book::isOpen 0
      set ::book::currentBook ""
      ::win::closeWindow $w
      return
    }

    set i 0
    set idx 0
    set tmp {}
    foreach file  $bookList {
      set f [ file tail $file ]
      lappend tmp $f
      if {$name == $f} {
        set idx $i
      }
      incr i
    }

    ttk::combobox $w.fcombo.combo -width 12 -values $tmp
    catch { $w.fcombo.combo current $idx }
    pack $w.fcombo.combo -expand yes -fill x

    ttk::frame $w.fbutton


    ttk::menubutton $w.fbutton.mbAdd -text $::tr(AddMove) -menu $w.fbutton.mbAdd.otherMoves
    menu $w.fbutton.mbAdd.otherMoves


    ttk::button $w.fbutton.bExport -text $::tr(Export) -command ::book::export
    ttk::button $w.fbutton.bSave -text $::tr(Save) -command ::book::save

    pack $w.fbutton.mbAdd $w.fbutton.bExport $w.fbutton.bSave -side top -fill x -expand yes


    pack $w.fcombo $w.f $w.fbutton -side top

    bind $w.fcombo.combo <<ComboboxSelected>> ::book::bookTuningSelect

    bind $w <Destroy> [list apply {{w} {
        if {[string equal $w %W]} { ::book::closeTuningBook }
    } ::} $w]
    bind $w <F1> { helpWindow BookTuning }

    bookTuningSelect

  }
  ################################################################################
  # ::book::closeTuningBook
  #   Closes the currently open tuning book.
  # Visibility:
  #   Private.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Calls `sc_book close` for `$::book::bookTuningSlot` when a tuning book is
  #     open.
  #   - Clears `::book::currentTuningBook`.
  #   - Moves focus to `.`.
  ################################################################################
  proc closeTuningBook {} {
    if { $::book::currentTuningBook == "" } { return }
    focus .
    sc_book close $::book::bookTuningSlot
    set ::book::currentTuningBook ""
  }
  ################################################################################
  # ::book::bookTuningSelect
  #   Applies the selected tuning book and refreshes the tuning UI.
  # Visibility:
  #   Private.
  # Inputs:
  #   - n: Unused (event callback parameter).
  #   - v: Unused (event callback parameter).
  # Returns:
  #   - None.
  # Side effects:
  #   - Loads the selected book into `$::book::bookTuningSlot` via
  #     `::book::scBookOpen`.
  #   - Enables/disables the Save button depending on `::book::isReadonly`.
  #   - Calls `::book::refreshTuning`.
  ################################################################################
  proc bookTuningSelect { { n "" }  { v  0} } {
    set w .bookTuningWin
    scBookOpen [.bookTuningWin.fcombo.combo get] $::book::bookTuningSlot
    if { $::book::isReadonly > 0 } {
      $w.fbutton.bSave configure -state disabled
    } else {
      $w.fbutton.bSave configure -state normal
    }
    refreshTuning
  }
  ################################################################################
  # ::book::addBookMove
  #   Adds a move entry to the tuning UI for the currently selected tuning book.
  # Visibility:
  #   Private.
  # Inputs:
  #   - move: A SAN move string.
  # Returns:
  #   - None.
  # Side effects:
  #   - No-ops when `::book::isReadonly > 0`.
  #   - Creates widgets under `.bookTuningWin.f` and binds a click handler.
  #   - Removes the move from `.bookTuningWin.fbutton.mbAdd.otherMoves`.
  #   - Appends the move to `::book::bookTuningMoves`.
  ################################################################################
  proc addBookMove { move } {
    global ::book::bookTuningMoves

    if { $::book::isReadonly > 0 } { return }

    set w .bookTuningWin
    set children [winfo children $w.f]
    set childrenCount [llength $children]
    set count [expr {$childrenCount / 2}]
    ttk::label $w.f.m$count -text [::trans $move]
    bind $w.f.m$count <ButtonPress-1> [list ::book::makeBookMove $move]
    ttk::spinbox $w.f.sp$count -from 0 -to 100 -width 3
    $w.f.sp$count set 0
    grid $w.f.m$count -row $count -column 0 -sticky w
    grid $w.f.sp$count -row $count -column 1 -sticky w
    $w.fbutton.mbAdd.otherMoves delete [::trans $move]
    lappend ::book::bookTuningMoves $move
  }
  ################################################################################
  # ::book::refreshTuning
  #   Rebuilds the tuning UI to reflect the current tuning book moves.
  # Visibility:
  #   Public.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Requires `.bookTuningWin` to exist; otherwise the proc will error.
  #   - No-ops when `::book::isReadonly > 0`.
  #   - Resets and repopulates `::book::bookTuningMoves`.
  #   - Destroys and recreates child widgets under `.bookTuningWin.f`.
  #   - Repopulates `.bookTuningWin.fbutton.mbAdd.otherMoves` using `sc_pos moves`.
  ################################################################################
  proc refreshTuning {} {

    if { $::book::isReadonly > 0 } { return }

    #unfortunately we need this as the moves on the widgets are translated
    #and widgets have no clientdata in tcl/tk
    global ::book::bookTuningMoves
    set ::book::bookTuningMoves {}
    lassign [sc_book moves $::book::bookTuningSlot] moves

    set w .bookTuningWin
    # erase previous children
    set children [winfo children $w.f]
    foreach c $children {
      destroy $c
    }

    set row 0
    for {set i 0} {$i<[llength $moves]} {incr i 2} {
      lappend ::book::bookTuningMoves [lindex $moves $i]
      ttk::label $w.f.m$row -text [::trans [lindex $moves $i]]
      bind $w.f.m$row <ButtonPress-1> [list ::book::makeBookMove [lindex $moves $i]]
      ttk::spinbox $w.f.sp$row -from 0 -to 100 -width 3
      set pct [lindex $moves [expr {$i+1}] ]
      set value [string replace $pct end end ""]
      $w.f.sp$row set $value
      grid $w.f.m$row -row $row -column 0 -sticky w
      grid $w.f.sp$row -row $row -column 1 -sticky w
      incr row
    }
    # load legal moves
    $w.fbutton.mbAdd.otherMoves delete 0 end
    $w.fbutton.mbAdd.otherMoves add command -label $::tr(None)
    set moveList [ sc_pos moves ]
    foreach move $moveList {
      if { [ lsearch  $moves $move ] == -1 } {
        $w.fbutton.mbAdd.otherMoves add command -label [::trans $move] -command [list ::book::addBookMove $move]
      }
    }
  }
  ################################################################################
  # ::book::save
  #   Saves the current tuning move probabilities back to the book.
  # Visibility:
  #   Public.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - No-ops when `::book::isReadonly > 0`.
  #   - Writes a temporary file under `$::scidUserDir`.
  #   - Calls `sc_book movesupdate` for `$::book::bookTuningSlot`.
  #   - Deletes the temporary file.
  #   - Refreshes the main book window (if `.bookWin` exists).
  ################################################################################
  proc save {} {
    global ::book::bookTuningMoves
    if { $::book::isReadonly > 0 } { return }

    set prob {}
    set w .bookTuningWin
    set children [winfo children $w.f]
    set childrenCount [llength $children]
    set count [expr {$childrenCount / 2}]
    for {set row 0} {$row < $count} {incr row} {
      lappend prob [$w.f.sp$row get]
    }
    set tempfile [file join $::scidUserDir tempfile.[pid]]
    sc_book movesupdate $::book::bookTuningMoves $prob $::book::bookTuningSlot $tempfile
    file delete $tempfile
    if {  [ winfo exists .bookWin ] } {
      ::book::refresh
    }
  }
  ################################################################################
  # ::book::export
  #   Exports book lines into the current game tree as mainline moves and
  #   variations.
  # Visibility:
  #   Public.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Opens/closes a progress window during export.
  #   - Resets `::book::cancelBookExport` and `::book::exportCount` before
  #     traversal.
  #   - Calls `::book::book2pgn`, which mutates the current game tree and uses
  #     `::book::hashList` to avoid revisiting positions.
  #   - Clears `::book::hashList` after `::book::book2pgn` returns.
  #   - Shows a `tk_messageBox` with the export result.
  #   - Calls `updateBoard -pgn` after export.
  ################################################################################
  proc export {} {
    ::windows::gamelist::Refresh
    updateTitle
    progressWindow [tr ScidUp] "ExportingBook..." $::tr(Cancel) "::book::sc_progressBar"
    set ::book::cancelBookExport 0
    set ::book::exportCount 0
    ::book::book2pgn
    set ::book::hashList ""
    closeProgressWindow
    if { $::book::exportCount >= $::book::exportMax } {
      tk_messageBox -title [tr ScidUp] -type ok -icon info \
          -message "$::tr(Movesloaded)  $::book::exportCount\n$::tr(BookPartiallyLoaded)"
    } else  {
      tk_messageBox -title [tr ScidUp] -type ok -icon info -message "$::tr(Movesloaded)  $::book::exportCount"
    }
    updateBoard -pgn
  }

  ################################################################################
  # ::book::book2pgn
  #   Recursively traverses book positions and adds moves to the current game as
  #   a main line plus variations.
  # Visibility:
  #   Private.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Respects `::book::cancelBookExport` and `::book::exportMax`.
  #   - Uses and updates `::book::hashList` to avoid revisiting positions.
  #   - Increments `::book::exportCount`.
  #   - Calls `updateBoard -pgn` repeatedly during traversal.
  #   - Mutates the current game tree via `sc_move` and `sc_var`.
  #   - Updates the progress window periodically (every 50 positions).
  ################################################################################
  proc book2pgn { } {
    global ::book::hashList

    if {$::book::cancelBookExport} { return  }
    if { $::book::exportCount >= $::book::exportMax } {
      return
    }
    set hash [sc_pos hash]
    if {[lsearch -sorted -integer -exact $hashList $hash] != -1} {
      return
    } else  {
      lappend hashList $hash
      set hashList [lsort -integer -unique $hashList]
    }

    updateBoard -pgn

    lassign [sc_book moves $::book::bookTuningSlot] bookMoves
    incr ::book::exportCount
    if {[expr {$::book::exportCount % 50}] == 0} {
      updateProgressWindow $::book::exportCount $::book::exportMax
      update
    }
    if {[llength $bookMoves] == 0} { return }

    for {set i 0} {$i<[llength $bookMoves]} {incr i 2} {
      set move [lindex $bookMoves $i]
      if {$i == 0} {
        sc_move addSan $move
        book2pgn
        sc_move back
      } else  {
        sc_var create
        sc_move addSan $move
        book2pgn
        sc_var exit
      }
    }

  }
  ################################################################################
  # ::book::sc_progressBar
  #   Cancels an in-progress book export.
  # Visibility:
  #   Private.
  # Inputs:
  #   - None.
  # Returns:
  #   - None.
  # Side effects:
  #   - Sets `::book::cancelBookExport` to 1.
  ################################################################################
  proc sc_progressBar {} {
    set ::book::cancelBookExport 1
  }
}
###
### End of file: book.tcl
###
