
### history.tcl
### Text entry history functions for Scid.
### Copyright (C) 2004 Shane Hudson.

namespace eval ::utils::history {}


set ::utils::history::defaultListLength 10
array set ::utils::history::listLength {}
array set ::utils::history::comboboxWidget {}

if {! [info exists ::utils::history::listData]} {
  array set ::utils::history::listData {}
}

# Load any history lists that were saved in the last session:
catch {source [scidConfigFile history]}


################################################################################
# ::utils::history::SetList
# Visibility:
#   Public.
# Inputs:
#   - key (string): History list key.
#   - list (list): Entries to store.
# Returns:
#   - None.
# Side effects:
#   - Updates `::utils::history::listData($key)`.
################################################################################
proc ::utils::history::SetList {key list} {
  set ::utils::history::listData($key) $list
}


################################################################################
# ::utils::history::GetList
# Visibility:
#   Public.
# Inputs:
#   - key (string): History list key.
# Returns:
#   - (list): Stored entries for `key`, or `{}` when unset.
# Side effects:
#   - None.
################################################################################
proc ::utils::history::GetList {key} {
  variable listData
  if {[info exists listData($key)]} {
    return $listData($key)
  }
  return {}
}


################################################################################
# ::utils::history::AddEntry
#   Adds an entry to the front of a history list (deduped and pruned).
# Visibility:
#   Public.
# Inputs:
#   - key (string): History list key.
#   - entry (string): Entry to add (ignored when empty).
# Returns:
#   - None.
# Side effects:
#   - Updates `::utils::history::listData($key)`.
#   - Calls `::utils::history::PruneList` when updating an existing list.
#   - Calls `::utils::history::RefillCombobox`.
#   - If a combobox widget is registered and exists, selects index 0.
################################################################################
proc ::utils::history::AddEntry {key entry} {
  variable listData
  # We do not add the empty string to a history list:
  if {$entry == "" } {
    return
  }
  
  if {[info exists listData($key)]} {
    # Take out this entry if it exists, so it will not appear twice:
    set index [lsearch -exact $listData($key) $entry]
    if {$index == 0} {
      # The entry is already at the start of the list; nothing to do
      return
    } elseif {$index > 0} {
      set listData($key) [lreplace $listData($key) $index $index]
    }
    set listData($key) [linsert $listData($key) 0 $entry]
    ::utils::history::PruneList $key
  } else {
    set listData($key) [list $entry]
  }
  RefillCombobox $key
  
  if { [llength [GetList $key]] > 0 } {
    set cb [ GetCombobox $key ]
    if { $cb != "" && [winfo exists $cb]} {
      $cb current 0
    }
  }
  
}


################################################################################
# ::utils::history::SetLimit
# Visibility:
#   Public.
# Inputs:
#   - key (string): History list key.
#   - length (int): Maximum number of entries to keep.
# Returns:
#   - None.
# Side effects:
#   - Updates `::utils::history::listLength($key)`.
#   - Calls `::utils::history::PruneList`.
################################################################################
proc ::utils::history::SetLimit {key length} {
  set ::utils::history::listLength($key) $length
  ::utils::history::PruneList $key
}


################################################################################
# ::utils::history::GetLimit
# Visibility:
#   Public.
# Inputs:
#   - key (string): History list key.
# Returns:
#   - (int): Maximum length for the list (`listLength($key)` or
#     `defaultListLength`).
# Side effects:
#   - None.
################################################################################
proc ::utils::history::GetLimit {key} {
  variable listLength
  variable defaultListLength
  if {[info exists ::utils::history::listLength($key)]} {
    return $::utils::history::listLength($key)
  }
  return $defaultListLength
}


################################################################################
# ::utils::history::PruneList
# Visibility:
#   Public.
# Inputs:
#   - key (string): History list key.
#   - length (int, optional): Maximum entries to keep. When negative (default),
#     uses `::utils::history::GetLimit $key`.
# Returns:
#   - None.
# Side effects:
#   - Updates `::utils::history::listData($key)`.
# Notes:
#   - `length == 0` currently does not prune the list (due to `lrange 0 -1`).
################################################################################
proc ::utils::history::PruneList {key {length -1}} {
  variable listData
  if {! [info exists listData($key)]} { return }
  if {$length < 0} {
    set length [::utils::history::GetLimit $key]
  }
  set listData($key) [lrange $listData($key) 0 [expr {$length - 1}]]
}



################################################################################
# ::utils::history::GetCombobox
# Visibility:
#   Public.
# Inputs:
#   - key (string): History list key.
# Returns:
#   - (string): Registered combobox widget path, or `""` when none.
# Side effects:
#   - None.
################################################################################
proc ::utils::history::GetCombobox {key} {
  variable comboboxWidget
  if {[info exists comboboxWidget($key)]} {
    return $comboboxWidget($key)
  }
  return ""
}


################################################################################
# ::utils::history::SetCombobox
#   Associates a combobox widget with a history key.
# Visibility:
#   Public.
# Inputs:
#   - key (string): History list key.
#   - cbWidget (string): Combobox widget path.
# Returns:
#   - None.
# Side effects:
#   - Updates `::utils::history::comboboxWidget($key)`.
#   - Calls `::utils::history::RefillCombobox`.
################################################################################
proc ::utils::history::SetCombobox {key cbWidget} {
  set ::utils::history::comboboxWidget($key) $cbWidget
  RefillCombobox $key
}


################################################################################
# ::utils::history::RefillCombobox
#   Repopulates the associated combobox’s values from the current history list.
# Visibility:
#   Public.
# Inputs:
#   - key (string): History list key.
# Returns:
#   - None.
# Side effects:
#   - If a combobox is registered and exists, updates it via:
#     - `$cbWidget delete 0 end`
#     - `$cbWidget configure -values <entries>`
################################################################################
proc ::utils::history::RefillCombobox {key} {
  variable comboboxWidget
  
  set cbWidget [GetCombobox $key]
  if {$cbWidget == ""} { return }
  
  # If the combobox widget is part of a dialog which is generated as needed,
  # it may not exist right now:
  if {! [winfo exists $cbWidget]} { return }
  
  $cbWidget delete 0 end
  set entries [GetList $key]
  $cbWidget configure -values $entries
}


################################################################################
# ::utils::history::Save
#   Persists history lists to `[scidConfigFile history]`.
# Visibility:
#   Public.
# Inputs:
#   - reportError (bool/int, optional): When true, shows a warning message box
#     if the history file cannot be opened for writing.
# Returns:
#   - None.
# Side effects:
#   - Writes `[scidConfigFile history]`.
#   - May show a `tk_messageBox` warning when opening the file fails.
# Notes:
#   - This proc does not currently catch/report failures from `puts` or `close`.
################################################################################
proc ::utils::history::Save {{reportError 0}} {
  variable listData
  
  set f {}
  set filename [scidConfigFile history]
  
  if  {[catch {open $filename w} f]} {
    if {$reportError} {
      tk_messageBox -title [tr ScidUp] -type ok -icon warning \
          -message "Unable to write file: $filename\n$f"
    }
    return
  }
  
  puts $f "# ScidUp $::scidReleaseVersion combobox history lists"
  puts $f ""
  foreach i [lsort [array names listData]] {
    puts $f "set ::utils::history::listData($i) [list $listData($i)]"
  }
  close $f
}
