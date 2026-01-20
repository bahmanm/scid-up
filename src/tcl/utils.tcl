

################################################################################
# ::utils::thousands
#   Formats an integer using the current locale thousands separator.
# Visibility:
#   Public.
# Inputs:
#   - n: Integer to format.
#   - kilo: When true, abbreviates large values with K/M.
# Returns:
#   - Formatted string.
# Side effects:
#   - Reads ::locale(numeric).
################################################################################
proc ::utils::thousands {n {kilo 0}} {
  global locale
  set commaChar [string index $locale(numeric) 1]
  set unit ""
  if {$kilo} {
    if {$n >= 1000000} {
      set decimalChar [string index $locale(numeric) 0]
      set decimalPart [format "%02d" [expr {(int($n / 10000)) % 100}]]
      set n [expr {int($n) / 1000000}]
      set unit "${decimalChar}${decimalPart}M"
    } elseif {$n >= 100000} {
      set unit "K"
      set n [expr {int($n / 1000)} ]
    }
  }
  if {$commaChar == ""} { return "$n$unit" }
  while {[regsub {^([-+]?[0-9]+)([0-9][0-9][0-9])} $n "\\1$commaChar\\2" n]} {}
  return "$n$unit"
}

################################################################################
# ::utils::percentFormat
#   Formats a numerator and percentage of a denominator.
# Visibility:
#   Public.
# Inputs:
#   - num: Numerator.
#   - denom: Denominator (0 is treated as 1).
# Returns:
#   - Formatted string: "<num> (<percent>%)".
# Side effects:
#   - Reads ::locale(numeric) via ::utils::thousands.
################################################################################
proc ::utils::percentFormat {num denom} {
  # Ensure denominator is not zero:
  if {$denom == 0} {set denom 1}
  return "[::utils::thousands $num] ([expr {$num * 100 / $denom}]%)"
}

