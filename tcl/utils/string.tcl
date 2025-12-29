################################################################################
# ::utils::string::Surname
#   Returns the portion of a player name before the first comma.
# Visibility:
#   Public.
# Inputs:
#   - name (string): Player name. Typical formats include "Last, First" and
#     "First Last".
# Returns:
#   - (string): The substring before the first comma when a comma is present at
#     an index > 0; otherwise returns `name` unchanged.
# Side effects:
#   - None.
################################################################################
proc ::utils::string::Surname {name} {
  set idx [string first "," $name]
  if {$idx > 0} { set name [string range $name 0 [expr {$idx - 1} ]] }
  return $name
}


################################################################################
# ::utils::string::CityName
#   Normalises a site string into a display-friendly city name.
# Visibility:
#   Public.
# Inputs:
#   - siteName (string): Site string, optionally ending with a space followed by
#     a 3-letter uppercase code.
# Returns:
#   - (string): `siteName` with a trailing " XXX" removed (where XXX is
#     `[A-Z]{3}`), then trimmed, and then passed through
#     `::utils::string::Surname`.
# Side effects:
#   - None.
################################################################################
proc ::utils::string::CityName {siteName} {
  regsub { [A-Z][A-Z][A-Z]$} $siteName "" siteName
  return [string trim [::utils::string::Surname $siteName]]
}


################################################################################
# ::utils::string::Capital
#   Returns a string with the first character uppercased.
# Visibility:
#   Public.
# Inputs:
#   - str (string): Input string.
# Returns:
#   - (string): `str` with its first character uppercased (remaining characters
#     are not modified).
# Side effects:
#   - None.
################################################################################
proc ::utils::string::Capital {str} {
  set s [string toupper [string index $str 0]]
  append s [string range $str 1 end]
  return $s
}

################################################################################
# ::utils::string::PadLeft
#   Pads a string to a minimum length.
# Visibility:
#   Public.
# Inputs:
#   - str (string): Input string.
#   - length (int): Target minimum length.
#   - padChar (string, optional): Padding character (defaults to a space).
# Returns:
#   - (string): `str`, padded to at least `length` characters.
# Side effects:
#   - None.
# Notes:
#   - Despite the name, this implementation appends padding to the end.
################################################################################
proc ::utils::string::PadLeft {str length {padChar " "}} {
  set s $str
  for {set actual [string length $s]} {$actual < $length} {incr actual} {
    append s $padChar
  }
  return $s
}

################################################################################
# ::utils::string::Pad
#   Alias for `::utils::string::PadLeft`.
# Visibility:
#   Public.
# Inputs:
#   - str (string): Input string.
#   - length (int): Target minimum length.
#   - padChar (string, optional): Padding character (defaults to a space).
# Returns:
#   - (string): Alias for `::utils::string::PadLeft`.
# Side effects:
#   - None.
################################################################################
proc ::utils::string::Pad {str length {padChar " "}} {
  return [::utils::string::PadLeft $str $length $padChar]
}

################################################################################
# ::utils::string::PadRight
#   Pads a string to a minimum length.
# Visibility:
#   Public.
# Inputs:
#   - str (string): Input string.
#   - length (int): Target minimum length.
#   - padChar (string, optional): Padding character (defaults to a space).
# Returns:
#   - (string): `str`, padded to at least `length` characters.
# Side effects:
#   - None.
# Notes:
#   - Despite the name, this implementation prefixes padding to the start.
################################################################################
proc ::utils::string::PadRight {str length {padChar " "}} {
  set s $str
  for {set actual [string length $s]} {$actual < $length} {incr actual} {
    set s "$padChar$s"
  }
  return $s
}

################################################################################
# ::utils::string::PadCenter
#   Pads a string to a minimum length.
# Visibility:
#   Public.
# Inputs:
#   - str (string): Input string.
#   - length (int): Target minimum length.
#   - padChar (string, optional): Padding character (defaults to a space).
# Returns:
#   - (string): `str`, padded to at least `length` characters.
# Side effects:
#   - None.
# Notes:
#   - Padding alternates prefix/suffix, starting with the prefix.
################################################################################
proc ::utils::string::PadCenter {str length {padChar " "}} {
  set pre 1
  set s $str
  for {set actual [string length $s]} {$actual < $length} {incr actual} {
    if {$pre} {
      set s "$padChar$s"
      set pre 0
    } else {
      append s $padChar
      set pre 1
    }
  }
  return $s
}

