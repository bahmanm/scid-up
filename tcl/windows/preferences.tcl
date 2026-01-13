#
# Copyright (C) 2019 Uwe Klimmek, Fulvio Benini
#
# This file is part of Scid (Shane's Chess Information Database).
# Scid is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.

### Preference setup window

namespace eval ::preferences {}

################################################################################
# ::preferences::replaceConfig
#   Switches to the selected preferences pane within the preferences window.
# Visibility:
#   Private.
# Inputs:
#   - nr: Index of the selected configuration pane.
#   - w: Canvas widget path hosting the configuration panes.
# Returns:
#   - None.
# Side effects:
#   - Updates `::preferences::aktConfig`.
#   - Reconfigures the canvas layout via `grid forget` / `grid`.
#   - Resets the canvas scroll position via `$w xview` and `$w yview`.
################################################################################
proc ::preferences::replaceConfig { nr w } {
  if {[info exists ::preferences::aktConfig]} {
    grid forget $::preferences::aktConfig
  }
  set ::preferences::aktConfig $w.f.$nr
  grid $w.f.$nr -row 0 -column 1 -sticky news -pady "5 0" -padx "5 0"
  $w xview moveto 0
  $w yview moveto 0
}

################################################################################
# ::preferences::updateScrollBar
#   Updates the preferences canvas scroll region to match its embedded frame size.
# Visibility:
#   Private.
# Inputs:
#   - w: Canvas widget path hosting the embedded frame `$w.f`.
# Returns:
#   - None.
# Side effects:
#   - Queries widget geometry via `winfo reqwidth/reqheight`.
#   - Updates `$w` canvas `-scrollregion`, `-width`, and `-height`.
################################################################################
proc ::preferences::updateScrollBar { w } {
  set l [winfo reqwidth $w.f]
  set h [winfo reqheight $w.f]
  $w configure -scrollregion [list 0 0 $l $h] -width $l -height $h
}

################################################################################
# ::preferences::Open
#   Opens (or focuses) the Scid preferences window.
# Visibility:
#   Public.
# Inputs:
#   - toggle (optional): Unused.
# Returns:
#   - None.
# Side effects:
#   - Creates `.preferences` and builds its option list and config panes.
#   - Calls a set of preference pane initialisers (e.g. `chooseBoardColors`,
#     `::preferences::fonts`, `::preferences::internationalization`, etc.).
#   - Updates `::preferences::aktConfig` via selection.
################################################################################
proc ::preferences::Open { {toggle ""} } {
  set w .preferences
  if {! [::win::createWindow $w "$::menuLabel($::language,ConfigureScid)"]} {
    ::win::makeVisible $w
    return
  }

  ttk::frame $w.options
  ttk::treeview $w.options.list -columns {0} -show {} -selectmode browse
  autoscrollBars y $w.options $w.options.list
  bind $w.options.list <<TreeviewSelect>> [list apply {{w} {
    ::preferences::replaceConfig [%W selection] ${w}.c
  } ::} $w]

  ttk::frame $w.config
  canvas $w.c -highlightthickness 0
  ::applyThemeColor_background $w.c
  autoscrollBars both $w.config $w.c
  ttk::frame $w.c.f
  bind $w.c.f <Configure> [list ::preferences::updateScrollBar $w.c]
  $w.c create window 0 0 -window $w.c.f -anchor nw
  grid columnconfigure $w.c.f 1 -weight 1

  grid $w.options -row 0 -column 0 -sticky news
  grid $w.config -row 0 -column 1 -sticky news
  grid rowconfigure $w 0 -weight 1
  grid columnconfigure $w 1 -weight 1

  ### Add all preference dialogs to this list. Add for every dialog: textlabel proc
  set idx 0
  set configList {}
  lappend configList [tr OptionsBoard] chooseBoardColors
  lappend configList [tr OptionsFonts] ::preferences::fonts
  lappend configList [tr OptionsToolbar] ConfigToolbar
  lappend configList [tr OptionsInternationalization] ::preferences::internationalization
  lappend configList [tr OptionsRecent] ::recentFiles::configure
  lappend configList [tr OptionsSounds] ::utils::sound::OptionsDialog
  lappend configList [tr OptionsMoves] ::preferences::moves
  lappend configList [tr ConfigureInformant] configInformant
  set maxlen 0
  ### create the dialogs
  foreach {m init} $configList {
    $w.options.list insert {} end -id $idx -values [list $m]
    set mlen [font measure font_Regular $m]
    if { $maxlen < $mlen } { set maxlen $mlen }
    ttk::frame $w.c.f.$idx
    $init $w.c.f.$idx
    incr idx
  }
  $w.options.list column 0 -width [incr maxlen 12]
  $w.options.list configure -height $idx

  unset -nocomplain ::preferences::aktConfig
  $w.options.list selection set 0
  focus $w.options
}

################################################################################
# ::preferences::checkFileDir
#   Validates a file/directory entry and invokes the associated setter on change.
# Visibility:
#   Private.
# Inputs:
#   - widget: Entry widget path providing the candidate path via `$widget get`.
#   - command: Setter command to invoke when the value is valid and changed.
#   - type: File predicate subcommand for `file` (e.g. `isfile`, `isdirectory`).
#   - oldvalue: Name of a variable containing the existing value to compare
#     against (optional; may not exist).
# Returns:
#   - None.
# Side effects:
#   - Updates entry styling (`Error.TEntry` / `TEntry`) based on validity.
#   - Grabs the toplevel window containing the widget.
#   - Invokes `$command $filename` when the value is valid and changed.
################################################################################
proc ::preferences::checkFileDir { widget command type oldvalue} {
    global spellCheckFile

    set filename [$widget get]
    if {$filename ne "" && ![file $type $filename]} {
        $widget configure -style Error.TEntry
        return
    }
    $widget configure -style TEntry
    if {[info exists $oldvalue] && $filename eq [set $oldvalue]} {
        return
    }
    grab [winfo toplevel $widget]
    $command "$filename"
}

################################################################################
# ::preferences::resources
#   Opens the “ScidUp Resources” dialog for configuring resource file/directories.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Creates `.resDialog` as a modal dialog (uses `grab`).
#   - Builds entry fields and browse buttons for multiple resource locations.
#   - Schedules validation via `after` calling `::preferences::checkFileDir`.
################################################################################
proc ::preferences::resources { } {
    # Directories
    set w .resDialog
    if { [winfo exists $w] } return

    win::createDialog $w
    ::setTitle $w "[tr ScidUp] Resources"

    set idx 0
    foreach file {
        ::ThemePackageFile
        ::spellCheckFile
        ::ecoFile
        ::scidBooksDir
        ::scidBasesDir
        ::scidPhotoDir
        ::utils::sound::soundFolder
    } label {
        OptionsThemeDir
        OptionsSpell
        OptionsECO
        OptionsBooksDir
        OptionsTacticsBasesDir
        OptionsPhotosDir
        SoundsFolder
    } valtype {
        isfile
        isfile
        isfile
        isdirectory
        isdirectory
        isdirectory
        isdirectory
    } command {
        getThemePkgFile
        getSpellCheckFile
        getECOFile
        getBooksDir
        getTacticsBasesDir
        getPhotoDir
        ::utils::sound::GetDialogChooseFolder
    } checkvaluecommand {
        readThemePkgFile
        readSpellCheckFile
        readECOFile
        setBooksDir
        setTacticsBasesDir
        setPhotoDir
        ::utils::sound::OptionsDialogChooseFolder
    } {
        incr idx
        ttk::label $w.$file -text [tr $label]:
        ttk::frame $w.$idx
        set temp ""
        if { [info exists $file] } { set temp [set $file] }
        ttk::entry $w.$idx.file -width 80
        $w.$idx.file insert end $temp
        ttk::button $w.$idx.b -text "..." -command [list $command $w.$idx.file]
        $w.$idx.file configure -validate key -validatecommand [list apply {{w checkvaluecommand valtype varName} {
              after cancel [list ::preferences::checkFileDir $w $checkvaluecommand $valtype $varName]
              after 200 [list ::preferences::checkFileDir $w $checkvaluecommand $valtype $varName]
              return true
        } ::} $w.$idx.file $checkvaluecommand $valtype $file]
        pack $w.$file $w.$idx -anchor w -fill x
        pack $w.$idx.b -side right -padx 2
        pack $w.$idx.file -side left -padx 2 -fill x -expand yes
    }
    ttk::label $w.folderHelp -text $::tr(SoundsFolderHelp)
    pack $w.folderHelp -side top -anchor w

    ttk::frame $w.b
    pack $w.b -side bottom -fill x
    dialogbutton $w.b.ok -text "OK" -command [list destroy $w]
    packbuttons right $w.b.ok

    wm protocol $w WM_DELETE_WINDOW [list apply {{w} {
        if {[grab current $w] eq $w} {
            destroy $w
        }
    }} $w]
    wm resizable $w 1 0
    grab $w
}

################################################################################
# ::preferences::validateautoplay
#   Validates and applies the autoplay delay from the moves preferences pane.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - ok: 1 when `::tempdelay` is a digit string, otherwise 0.
# Side effects:
#   - Reads and updates the globals `::tempdelay` and `::autoplayDelay`.
#   - Clamps `::autoplayDelay` to a minimum of 0.1.
################################################################################
proc ::preferences::validateautoplay { } {
    global autoplayDelay tempdelay
    if { ! [string is digit $tempdelay] } {
        set tempdelay 1
        return 0
    }
    if { $tempdelay != "" } {
        set autoplayDelay [expr {int($tempdelay * 1000)}]
    }
    if {$autoplayDelay < 0.1} { set autoplayDelay 0.1 }
    return 1
}

################################################################################
# ::preferences::moves
#   Populates the “Moves” preferences pane within the preferences window.
# Visibility:
#   Private.
# Inputs:
#   - t: Container widget path for the pane.
# Returns:
#   - None.
# Side effects:
#   - Creates and configures multiple widgets under `$t` bound to global
#     preferences variables (e.g. `::pgn::moveNumberSpaces`, `moveEntry(*)`,
#     `::highlightLastMove`, etc.).
#   - Initialises `::tempdelay` from `::autoplayDelay`.
################################################################################
proc ::preferences::moves { t } {
    global autoplayDelay tempdelay

    set tempdelay [expr {int($autoplayDelay / 1000.0)}]
    ttk::frame $t.ani
    ttk::label $t.ani.al -text [tr OptionsMovesAnimate]
    ttk::label $t.ani.ms -text "ms"
    ttk::combobox $t.ani.animate -width 4 -textvar animateDelay \
        -values {0 100 150 200 250 300 400 500 600 800 1000}
    pack $t.ani.al $t.ani.animate $t.ani.ms -side left -anchor w -padx "0 5"
    ttk::checkbutton $t.omc -variable  moveEntry(Coord) -text [tr OptionsMovesCoord]
    ttk::checkbutton $t.omk -variable  moveEntry(AutoExpand) -text [tr OptionsMovesKey]
    ttk::checkbutton $t.oms -variable  suggestMoves -text [tr OptionsMovesSuggest]
    ttk::checkbutton $t.osv -variable  showVarPopup -text [tr OptionsShowVarPopup]
    ttk::checkbutton $t.osp -variable ::pgn::moveNumberSpaces -text [tr OptionsMovesSpace]
    ttk::checkbutton $t.sva -variable showVarArrows -text [tr OptionsMovesShowVarArrows]
    ttk::checkbutton $t.god -variable glossOfDanger -text [tr OptionsMovesGlossOfDanger] -command updateBoard

    ttk::frame $t.auto
    ttk::label $t.auto.label -text "[tr OptionsMovesDelay]\n$::tr(AnnotateTime:)"
    ttk::spinbox $t.auto.spDelay -width 4 -textvariable tempdelay -from 1 -to 999 -increment 1 \
        -validate all -validatecommand { ::preferences::validateautoplay }
    ttk::labelframe $t.high -text [tr OptionsMovesHighlightLastMove]
    ttk::checkbutton $t.high.hlm -variable ::highlightLastMove -text [tr OptionsMovesHighlightLastMoveDisplay] -command [list updateBoard]
    ttk::checkbutton $t.high.arrow -variable ::arrowLastMove -text [tr OptionsMovesHighlightLastMoveArrow] -command [list updateBoard]
    ttk::label $t.high.tl -text [tr OptionsMovesHighlightLastMoveWidth]
    ttk::spinbox $t.high.thick -width 2 -textvariable ::highlightLastMoveWidth -from 1 -to 5 -increment 1 \
        -validate key -validatecommand { return [string is digit %S] } -command [list updateBoard]
    ttk::button $t.high.color -text $::tr(ColorMarker) -command chooseHighlightColor
    ttk::checkbutton $t.high.nag -variable ::highlightLastMoveNag -text [tr OptionsMovesHighlightLastMoveNag] -command [list updateBoard]
    grid $t.high.hlm -row 0 -column 0 -sticky w
    grid $t.high.tl -row 0 -column 1 -padx "10 5"
    grid $t.high.thick -row 0 -column 2
    grid $t.high.color -row 1 -column 2 -pady "2 0"
    grid $t.high.arrow -row 1 -column 0 -columnspan 2 -sticky w
    grid $t.high.nag -row 2 -column 0 -sticky w
    pack $t.auto.label $t.auto.spDelay -side left -padx "0 10" -anchor w
    pack $t.ani $t.omc $t.omk $t.oms $t.osv $t.osp $t.auto $t.sva $t.god -side top -anchor w
    pack $t.high -side top -anchor w -pady "5 0"
}

################################################################################
# ::preferences::numbers
#   Applies the selected numeric formatting (decimal/thousands separator pair).
# Visibility:
#   Private.
# Inputs:
#   - w: Combobox widget path providing the selected index via `$w current`.
# Returns:
#   - None.
# Side effects:
#   - Updates `::locale(numeric)`.
#   - Calls `updateLocale`.
################################################################################
proc ::preferences::numbers { w } {
    global locale
    set numeric {".,"   ". "   ",."   ", "   "."   ","}
    set locale(numeric) [lindex $numeric [$w current]]
    updateLocale
}

################################################################################
# ::preferences::internationalization
#   Populates the “Internationalisation” preferences pane.
# Visibility:
#   Private.
# Inputs:
#   - w: Container widget path for the pane.
# Returns:
#   - None.
# Side effects:
#   - Creates widgets under `$w` bound to internationalisation-related globals.
#   - Updates `::newNumbers` and wires selection to `::preferences::numbers`.
#   - Calls `setLanguage` / `::notify::PosChanged pgnonly` when toggling
#     piece translation.
################################################################################
proc ::preferences::internationalization { w } {
    global locale

    ttk::checkbutton $w.tp -variable ::translatePieces -text [tr OptionsMovesTranslatePieces] \
        -command [list apply {{} {
            setLanguage
            ::notify::PosChanged pgnonly
        } ::}]
    set numList { }
    set pre ""
    foreach numeric {".,"   ". "   ",."   ", "   "."   ","} {
        set decimal [string index $numeric 0]
        set thousands [string index $numeric 1]
        if { [string length $numeric] < 2 } { set pre " " }
        lappend numList "${pre}12${thousands}345${decimal}67"
        if { $numeric == $locale(numeric) } { set ::newNumbers "12${thousands}345${decimal}67" }
    }
    ttk::frame $w.n
    ttk::label $w.n.nlb -text [tr OptionsNumbers]
    ttk::combobox $w.n.number -width 9 -textvar ::newNumbers -values $numList \
        -state readonly -font font_Fixed \
        -postcommand [list ::preferences::configureComboboxListboxFont $w.n.number font_Fixed]
    bind $w.n.number <<ComboboxSelected>> [list ::preferences::numbers $w.n.number]
    pack $w.n.nlb $w.n.number -side left -padx "0 5"
    pack $w.n $w.tp  -side top -anchor w
}

################################################################################
# ::preferences::configureComboboxListboxFont
#   Schedules configuration of a combobox popdown listbox font.
# Visibility:
#   Private.
# Inputs:
#   - combo: Combobox widget path.
#   - font: Font name to apply to the posted listbox.
# Returns:
#   - None.
# Side effects:
#   - Schedules `::preferences::configureComboboxListboxFont_` via `after idle`.
################################################################################
proc ::preferences::configureComboboxListboxFont {combo font} {
    if {![winfo exists $combo]} { return }

    # Avoid ttk private APIs and instead locate the posted popdown via public geometry
    # plus `winfo containing`.
    after idle [list ::preferences::configureComboboxListboxFont_ $combo $font]
}

################################################################################
# ::preferences::configureComboboxListboxFont_
#   Applies a font to the posted combobox listbox (implementation helper).
# Visibility:
#   Private.
# Inputs:
#   - combo: Combobox widget path.
#   - font: Font name to apply.
# Returns:
#   - None.
# Side effects:
#   - Walks the widget tree below the posted popdown window to find a Listbox.
#   - Attempts to configure the Listbox font (errors are caught and ignored).
################################################################################
proc ::preferences::configureComboboxListboxFont_ {combo font} {
    if {![winfo exists $combo]} { return }

    set rootX [winfo rootx $combo]
    set rootY [winfo rooty $combo]
    set h [winfo height $combo]

    # Prefer a point just below the widget; also try just above for cases where
    # Tk posts the list upwards (near the bottom of the screen).
    set x [expr {$rootX + 2}]
    foreach y [list [expr {$rootY + $h + 2}] [expr {$rootY - 2}]] {
        set start [winfo containing $x $y]
        if {$start eq ""} { continue }

        set stack [list $start]
        while {[llength $stack] > 0} {
            set w [lindex $stack 0]
            set stack [lrange $stack 1 end]
            if {![winfo exists $w]} { continue }
            if {[winfo class $w] eq "Listbox"} {
                catch { $w configure -font $font }
                return
            }
            set stack [concat [winfo children $w] $stack]
        }
    }
}

################################################################################
# ::preferences::fonts
#   Populates the “Fonts” preferences pane.
# Visibility:
#   Private.
# Inputs:
#   - w: Container widget path for the pane.
# Returns:
#   - None.
# Side effects:
#   - Creates sample labels and a font picker button per font category.
#   - Updates `::fontOptions(*)` when the user selects a new font.
################################################################################
proc ::preferences::fonts { w } {
    global locale

    set idx 0
    foreach font { Regular Menu Small Tiny Fixed } {
        set f [string tolower $font]
        ttk::label $w.lb$f -font font_$font -text "[tr OptionsFonts$font]: AaBbCcDdEe 01234"
        ttk::button $w.font$f  -text "..." -command [list apply {{name} {
            set new_options [FontDialog font_$name $::fontOptions($name)]
            if {$new_options != ""} {
                set ::fontOptions($name) $new_options
            }
        }} $font]
        grid $w.lb$f -row $idx -column 0 -sticky w -pady 5
        grid $w.font$f -row $idx -column 1 -sticky w -padx 5 -pady 5
        incr idx
    }
}
