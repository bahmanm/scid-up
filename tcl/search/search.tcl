###
### search.tcl: Search routines for Scid.
###

namespace eval ::search {}

# searchType: set to Header or Material in a SearchOptions file
set searchType 0

set ::search::filter::operation 2


################################################################################
# ::search::filter::reset
#   Resets the current game list filter (deprecated helper).
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Calls `sc_base current` and delegates to `::windows::gamelist::FilterReset`.
# Notes:
#   - TODO: remove this function.
################################################################################
proc ::search::filter::reset {} {
  ::windows::gamelist::FilterReset "" [sc_base current]
}

################################################################################
# ::search::addFilterOpFrame
#   Adds a filter-operation selection frame (AND/OR/IGNORE) to a search window.
# Visibility:
#   Public.
# Inputs:
#   - w: Parent widget path.
#   - small: When true, uses small radiobutton styles.
# Returns:
#   - None.
# Side effects:
#   - Creates ttk widgets under `$w.filterop` and packs them.
#   - Binds the radio buttons to `::search::filter::operation` (0=and, 1=or, 2=reset).
################################################################################
proc ::search::addFilterOpFrame {w {small 0}} {
  ttk::labelframe $w.filterop -text $::tr(FilterOperation)
  set f $w.filterop
  pack $f -side top -fill x
  
  set regular TRadiobutton
  if {$small} {
    set regular Small.TRadiobutton
  }
  
  ttk::frame $f.b
  ttk::radiobutton $f.b.and -textvar ::tr(FilterAnd) -variable ::search::filter::operation -value 0 -style $regular 
  ttk::radiobutton $f.b.or -textvar ::tr(FilterOr) -variable ::search::filter::operation -value 1 -style $regular
  ttk::radiobutton $f.b.ignore -textvar ::tr(FilterIgnore) -variable ::search::filter::operation -value 2 -style $regular
  pack $f.b -anchor w -side top
  pack $f.b.and $f.b.or $f.b.ignore -side left -padx 5
}


################################################################################
# ::search::Config
#   Sets the enabled/disabled state of Search buttons in search windows.
# Visibility:
#   Public.
# Inputs:
#   - state: Optional widget state (e.g. "normal" or "disabled"). When empty,
#     the state is derived from `sc_base inUse`.
# Returns:
#   - None.
# Side effects:
#   - May call `sc_base inUse`.
#   - Attempts to configure `.sh.b.search`, `.sb.b.search`, and `.sm.b3.search`.
################################################################################
proc ::search::Config {{state ""}} {
  if {$state == ""} {
    set state disabled
    if {[sc_base inUse]} { set state normal }
  }
  catch {.sh.b.search configure -state $state }
  catch {.sb.b.search configure -state $state }
  catch {.sm.b3.search configure -state $state }
}


################################################################################
# ::search::usefile
#   Opens and applies a saved SearchOptions (`.sso`) file.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Prompts for a file via `tk_getOpenFile`.
#   - Sets `::fName` to the selected file path.
#   - Sources the file into the global scope.
#   - On success, dispatches to `::search::material` or `::search::header` based
#     on `::searchType` as set by the sourced file.
#   - On source failure, shows a `tk_messageBox` warning.
################################################################################
proc ::search::usefile {} {
  set ftype { { "Scid SearchOption files" {".sso"} } }
  set ::fName [tk_getOpenFile -initialdir $::initialDir(base) \
      -filetypes $ftype -title "Select a SearchOptions file"]
  if {$::fName == ""} { return }
  
  if {[catch {uplevel "#0" {source $::fName} } ]} {
    tk_messageBox -title "Scid: Error reading file" -type ok -icon warning \
        -message "Unable to open or read SearchOptions file: $::fName"
  } else {
    switch -- $::searchType {
      "Material" { ::search::material }
      "Header"   { ::search::header }
      default    { return }
    }
  }
}
