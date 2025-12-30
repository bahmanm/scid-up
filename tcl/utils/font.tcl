########################################
### utils/font.tcl: part of Scid.
#
# The following procs implement a font selection dialog. I found the code
# at codearchive.com (I don't think there was an author listed for it) and
# simplified it for use with Scid.

################################################################################
# FontDialog
#   Shows a font selection dialog and previews changes on the given Tk font.
# Visibility:
#   Public.
# Inputs:
#   - font_name (string): Tk font name to preview/configure.
#   - options (list, optional): When a 4-item list `{family size weight slant}`,
#     uses these as the initial values instead of `font actual`.
#   - fixedOnly (bool/int, optional): When true, limits the family list to fixed-
#     width fonts.
# Returns:
#   - (list): `{family size weight slant}` when the user confirms.
#   - (string): `""` when cancelled (or when the dialog already exists).
# Side effects:
#   - Creates and destroys the `.fontdialog` toplevel.
#   - Updates global variables `fd_family`, `fd_style`, `fd_size`, `fd_close`.
#   - Configures `font_name` during preview; restores it on cancel.
#   - Calls `::updateFonts` to apply the changes.
################################################################################
proc FontDialog {font_name {options ""} {fixedOnly 0}} {
  global fd_family fd_style fd_size fd_close
  global fd_strikeout fd_underline

  set tl .fontdialog
  if { [winfo exists $tl] } return

  set fd_family {}; set fd_style {}; set fd_size {}
  set fd_close  -1

  set unsorted_fam [font families]
  set families [lsort $unsorted_fam]
  if {$fixedOnly} {
    set fams $families
    set families {}
    foreach f $fams {
      if {[font metrics [list $f] -fixed] == 1} { lappend families $f }
    }
  }

  # Get current font's family and so on.
  if {[llength $options] == 4} {
    # Use provided font settings:
    set family [lindex $options 0]
    set size [lindex $options 1]
    set weight [lindex $options 2]
    set slant [lindex $options 3]
  } else {
    # Get options using [font actual]:
    set family [font actual $font_name -family]
    set size   [font actual $font_name -size]
    set weight    [font actual $font_name -weight]
    set slant     [font actual $font_name -slant]
  }

  # Default style.
  set fd_style "Regular"
  if { $slant == "italic" } {
    if { $weight == "bold" } {
      set fd_style "Bold Italic"
    } else {
      set fd_style "Italic"
    }
  } else {
    if { $weight == "bold" } {
      set fd_style "Bold"
    }
  }

  set fd_family $family
  set fd_size   $size

  # Create font dialog.
  set tl .fontdialog
  toplevel $tl
  set dlg $tl.f
  pack [ttk::frame $tl.f] -expand 1 -fill both
  wm protocol $tl WM_DELETE_WINDOW "set fd_close 0"
  wm title $tl [tr OptionsFonts]

  ttk::label $dlg.family_lbl -text [tr OptionsFonts] -anchor w
  ttk::entry $dlg.family_ent -textvariable fd_family -background white
  bind  $dlg.family_ent <Key-Return> "FontDialogRegen $font_name"
  grid config $dlg.family_lbl -column 0 -row 0 -sticky w
  grid config $dlg.family_ent -column 0 -row 1 -sticky snew

  ttk::label $dlg.style_lbl  -text "Font Style" -anchor w
  ttk::entry $dlg.style_ent  -textvariable fd_style -width 11 -background white
  bind  $dlg.style_ent  <Key-Return>  "FontDialogRegen $font_name"
  grid config $dlg.style_lbl  -column 1 -row 0 -sticky w
  grid config $dlg.style_ent  -column 1 -row 1 -sticky snew

  ttk::label $dlg.size_lbl   -text [tr FinderSortSize] -anchor w
  ttk::entry $dlg.size_ent   -textvariable fd_size -width 4 -background white
  bind  $dlg.size_ent   <Key-Return> "FontDialogRegen $font_name"
  grid config $dlg.size_lbl   -column 2 -row 0 -sticky w
  grid config $dlg.size_ent   -column 2 -row 1 -sticky snew

  # Font family listbox.
  set fr $dlg.family_list
  ttk::frame $fr
  ttk::treeview $fr.list -columns {0} -show {} -selectmode browse \
             -yscrollcommand [list $fr.scroll set]
  $fr.list configure -height 7
  $fr.list column 0 -width 140
  ttk::scrollbar $fr.scroll -command [list $fr.list yview]

  set i 0
  foreach f $families {
      $fr.list insert {} end -id $i -values [list $f]
      incr i
  }

  bind $fr.list <Double-Button-1> "FontDialogFamily $fr.list $font_name $dlg.family_ent"

  pack $fr.scroll -side right -fill y
  pack $fr.list -side left -fill x
  grid config $fr -column 0 -row 2 -rowspan 16

  # Font style listbox.
  set fr $dlg.style_list
  ttk::frame $fr
  ttk::treeview $fr.list -columns {0} -show {} -selectmode browse \
             -yscrollcommand [list $fr.scroll set]
  $fr.list configure -height 7
  $fr.list column 0 -width 60
  ttk::scrollbar $fr.scroll -command [list $fr.list yview]

  set i 0
  foreach style { "Regular" "Bold" "Italic" "Bold Italic" } {
      $fr.list insert {} end -id $i -values [list $style]
      incr i
  }

  bind $fr.list <Double-Button-1> "FontDialogStyle $fr.list $font_name $dlg.style_ent"

  pack $fr.scroll -side right -fill y
  pack $fr.list -side left
  grid config $fr -column 1 -row 2 -rowspan 16

  # Font size listbox.
  set fr $dlg.size_list
  ttk::frame $fr
  ttk::treeview $fr.list -columns {0} -show {} -selectmode browse \
             -yscrollcommand [list $fr.scroll set]
  $fr.list configure -height 7
  $fr.list column 0 -width 30
  ttk::scrollbar $fr.scroll -command [list $fr.list yview]

  set i 0
  for {set j 7} {$j <= 20} {incr j} {
      $fr.list insert {} end -id $i -values $j
      incr i
  }

  bind $fr.list <Double-Button-1> "FontDialogSize $fr.list $font_name $dlg.size_ent"

  pack $fr.scroll -side right -fill y
  pack $fr.list -side left
  grid config $fr -column 2 -row 2 -rowspan 16

  # OK/Cancel
  set fr $dlg.ok_cancel
  ttk::frame $fr

  ttk::button $fr.ok -text "OK" -command [list set fd_close 1]
  ttk::button $fr.cancel  -text [tr Cancel] -command [list set fd_close 0]
  pack $fr.ok -side top -fill x
  pack $fr.cancel -side top -fill x -pady 2
  ttk::button $fr.help -text [tr Help] -command [list helpWindow Options]
  pack $fr.help -side top -fill x -pady 10
  grid config $fr -column 4 -row 1 -rowspan 2 -sticky snew -padx "10 0"

  # Sample text
  set fr $dlg.sample
  ttk::labelframe $fr -text "Sample"

  ttk::label $fr.sample -font $font_name -text "This is some sample text\nAaBbCcDdEeFfGgHhIiJjKkLlMm\n 0123456789. +=-\n\u2654 \u2655 \u2656 \u2657 \u2658"

  pack  $fr.sample -side top -pady 4

  grid config $fr -column 0 -columnspan 3 -sticky snew  -pady 5

  # Make this a modal dialog.
  tkwait variable fd_close

  # Get rid of dialog and return value.
  destroy $tl

  # Restore old font characteristics on a cancel:
  if { $fd_close == 0 } {
    font configure $font_name -family $family -size $size -slant $slant -weight $weight
    ::updateFonts $font_name
    return ""
  }

  return [list $fd_family $fd_size [FontWeight $fd_style] [FontSlant $fd_style]]
}


################################################################################
# FontDialogFamily
# Visibility:
#   Internal.
# Inputs:
#   - listname (string): Treeview widget path containing font families.
#   - font_name (string): Tk font name to preview/configure.
#   - entrywidget (string): Entry widget path to update.
# Returns:
#   - None.
# Side effects:
#   - Updates `entrywidget` with the selected family.
#   - Calls `FontDialogRegen` to apply the selection.
#   - Silently ignores errors (wrapped in `catch`).
################################################################################
proc FontDialogFamily { listname font_name entrywidget } {
  # Get selected text from list.
  catch {
    set item_num [$listname selection]
    set item [$listname set $item_num 0]

    # Set selected list item into entry for font family.
    $entrywidget delete 0 end
    $entrywidget insert end $item

    # Use this family in the font and regenerate font.
    FontDialogRegen $font_name
  }
}


################################################################################
# FontDialogStyle
# Visibility:
#   Internal.
# Inputs:
#   - listname (string): Treeview widget path containing font styles.
#   - font_name (string): Tk font name to preview/configure.
#   - entrywidget (string): Entry widget path to update.
# Returns:
#   - None.
# Side effects:
#   - Updates `entrywidget` with the selected style.
#   - Calls `FontDialogRegen` to apply the selection.
#   - Silently ignores errors (wrapped in `catch`).
################################################################################
proc FontDialogStyle { listname font_name entrywidget } {
  # Get selected text from list.
  catch {
    set item_num [$listname selection]
    set item [$listname set $item_num 0]

    # Set selected list item into entry for font family.
    $entrywidget delete 0 end
    $entrywidget insert end $item

    # Use this family in the font and regenerate font.
    FontDialogRegen $font_name
  }
}


################################################################################
# FontDialogSize
# Visibility:
#   Internal.
# Inputs:
#   - listname (string): Treeview widget path containing font sizes.
#   - font_name (string): Tk font name to preview/configure.
#   - entrywidget (string): Entry widget path to update.
# Returns:
#   - None.
# Side effects:
#   - Updates `entrywidget` with the selected size.
#   - Calls `FontDialogRegen` to apply the selection.
#   - Silently ignores errors (wrapped in `catch`).
################################################################################
proc FontDialogSize { listname font_name entrywidget } {
  # Get selected text from list.
  catch {
    set item_num [$listname selection]
    set item [$listname set $item_num 0]

    # Set selected list item into entry for font family.
    $entrywidget delete 0 end
    $entrywidget insert end $item

    # Use this family in the font and regenerate font.
    FontDialogRegen $font_name
  }
}

################################################################################
# FontWeight
# Visibility:
#   Internal.
# Inputs:
#   - style (string): Font style (e.g. "Regular", "Bold", "Italic",
#     "Bold Italic").
# Returns:
#   - (string): Tk weight name ("bold" or "normal").
# Side effects:
#   - None.
################################################################################
proc FontWeight {style} {
  if { $style == "Bold Italic" || $style == "Bold" } {
    return "bold"
  }
  return "normal"
}

################################################################################
# FontSlant
# Visibility:
#   Internal.
# Inputs:
#   - style (string): Font style (e.g. "Regular", "Bold", "Italic",
#     "Bold Italic").
# Returns:
#   - (string): Tk slant name ("italic" or "roman").
# Side effects:
#   - None.
################################################################################
proc FontSlant {style} {
  if { $style == "Bold Italic" || $style == "Italic" } {
    return "italic"
  }
  return "roman"
}

################################################################################
# FontDialogRegen
#   Regenerates the preview font from the dialog’s current settings.
# Visibility:
#   Internal.
# Inputs:
#   - font_name (string): Tk font name to preview/configure.
# Returns:
#   - None.
# Side effects:
#   - Reads globals `fd_family`, `fd_style`, `fd_size`.
#   - Calls `font configure` on `font_name`.
#   - Calls `::updateFonts` to apply the changes.
################################################################################
proc FontDialogRegen { font_name } {
  global fd_family fd_style fd_size

  set weight "normal"
  if { $fd_style == "Bold Italic" || $fd_style == "Bold" } {
    set weight "bold"
  }

  set slant "roman"
  if { $fd_style == "Bold Italic" || $fd_style == "Italic" } {
    set slant "italic"
  }

  # Change font to have new characteristics.
  font configure $font_name -family $fd_family -size $fd_size -slant $slant -weight $weight
  ::updateFonts $font_name
}

## End of file: fontsel.tcl
