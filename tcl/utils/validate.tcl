
namespace eval ::validate {

    ################################################################################
    # ::validate::integer
    #   Validates integer input for Tk `-validatecommand` usage.
    # Visibility:
    #   Public.
    # Inputs:
    #   - P (string): Proposed text content (e.g. `%P`).
    #   - min (int|string, optional): Minimum bound; pass "" to disable.
    #   - max (int|string, optional): Maximum bound; pass "" to disable.
    # Returns:
    #   - (int): 1 if the proposed content should be accepted; otherwise 0.
    # Side effects:
    #   - None.
    # Notes:
    #   - This uses Tcl's `string is integer`, so it accepts Tcl integer syntax
    #     (e.g. leading/trailing whitespace and non-decimal literals such as
    #     `0x10`). If you require decimal digits only, add a stricter check.
    ################################################################################
    proc integer {P {min ""} {max ""}} {
        # Allow empty and signs (+/-).
        if {$P eq ""} { return 1 }
        if {$P eq "+"} { return 1 }
        if {$P eq "-"} {
            if {$min eq ""} { return 1 }
            return [expr {$min < 0}]
        }

        # Reject non-integer intermediate input (e.g. "2a") without throwing.
        if {![string is integer $P]} { return 0 }

        # Enforce bounds only when the current value is a complete integer.
        #   If Min=10 and P=1, P is invalid but P is "on the way" to 10. We must allow it.
        #   If Min=-10 and P=-20, P is invalid and adding digits (e.g. -200) makes it worse. Block it.
        if {$max ne "" && $P > $max} { return 0 }
        if {$min ne "" && $P < $min && $P < 0} { return 0 }

        return 1
    }
}

################################################################################
# ::utils::validate::Integer
#   Validates an integer variable value (via variable trace callbacks).
# Visibility:
#   Public.
# Inputs:
#   - maxValue (int): Maximum allowed value. If negative, the absolute value is
#     used as the maximum and negative values are permitted.
#   - allowQuestionMarks (int): When non-zero, allows a string containing only
#     "?" characters as a placeholder.
#   - name (string): Variable name (trace callback argument `name1`).
#   - el (string): Array element (trace callback argument `name2`), or "".
#   - op (string): Trace operation (trace callback argument `op`).
# Returns:
#   - None.
# Side effects:
#   - Reads and writes the traced variable (and its corresponding `${name}_old`).
#   - Calls `bell` and reverts to the previous value on invalid input.
# Notes:
#   - `maxValue < 0` is a deliberate convention meaning "allow negatives".
################################################################################
proc ::utils::validate::Integer {maxValue allowQuestionMarks name el op} {
  global $name ${name}_old
  if {[string comp {} $el]} {
    set old  ${name}_old\($el\)
    set name $name\($el\)
  } else {
    set old ${name}_old
  }

  if {$allowQuestionMarks > 0} {
    if {[regexp {^\?*$} [set $name]]} {
      # Accept this value:
      set $old [set $name]
      return
    }
  }

  # Only non-negative integers up to maxValue are allowed, unless the
  # value is negative:
  set allowNegatives 0
  if {$maxValue < 0} {
    set allowNegatives 1
    set maxValue [expr {0 - $maxValue}]
  }

  if {$allowNegatives} {
    if {![regexp {^[-+]?[0-9]*$} [set $name]]} {
      set $name [set $old]
      bell
      return
    }
  } else {
    if {![regexp {^[+]?[0-9]*$} [set $name]]} {
      set $name [set $old]
      bell
      return
    }
  }
  if {[set $name] > $maxValue} {
    set $name [set $old]
    bell
    return
  }
  #if {[expr {0 - [set $name]}] < [expr {0 - $maxValue}]} {
  #  set $name [set $old]
  #  bell
  #  return
  #}
  set $old [set $name]
}



################################################################################
# ::utils::validate::Date
#   Validates a date string variable value (via variable trace callbacks).
# Visibility:
#   Public.
# Inputs:
#   - name (string): Variable name (trace callback argument `name1`).
#   - el (string): Array element (trace callback argument `name2`), or "".
#   - op (string): Trace operation (trace callback argument `op`).
# Returns:
#   - None.
# Side effects:
#   - Reads the traced variable.
#   - Calls `sc_info validDate`.
#   - On invalid input, calls `bell` and reverts to the previous value.
################################################################################
proc ::utils::validate::Date {name el op} {
  global $name ${name}_old
  set old ${name}_old
  if {![sc_info validDate [set $name]]} {
    if {![info exist $old]} { set $old "" }
    set $name [set $old]
    bell
    return
  }
  set $old [set $name]
}

################################################################################
# ::utils::validate::Result
#   Validates a game result token (via variable trace callbacks).
# Visibility:
#   Public.
# Inputs:
#   - name (string): Variable name (trace callback argument `name1`).
#   - el (string): Array element (trace callback argument `name2`), or "".
#   - op (string): Trace operation (trace callback argument `op`).
# Returns:
#   - None.
# Side effects:
#   - On invalid input, calls `bell` and reverts to the previous value.
# Notes:
#   - Valid values are: "" (empty), "1", "0", "=", and "*".
################################################################################
proc ::utils::validate::Result {name el op} {
  global $name ${name}_old
  set old ${name}_old
  if {![regexp {^[10=*]?$} [set $name]]} {
    if {![info exist $old]} { set $old "" }
    set $name [set $old]
    bell
    return
  }
  set $old [set $name]
}

################################################################################
# ::utils::validate::Alpha
#   Validates that an entry contains only ASCII letters (via variable trace callbacks).
# Visibility:
#   Public.
# Inputs:
#   - name (string): Variable name (trace callback argument `name1`).
#   - el (string): Array element (trace callback argument `name2`), or "".
#   - op (string): Trace operation (trace callback argument `op`).
# Returns:
#   - None.
# Side effects:
#   - On invalid input, calls `bell` and reverts to the previous value.
################################################################################
proc ::utils::validate::Alpha {name el op} {
  global $name ${name}_old
  set old ${name}_old
  if {![regexp {^[A-Za-z]*$} [set $name]]} {
    if {![info exist $old]} { set $old "" }
    set $name [set $old]
    bell
    return
  }
  set $old [set $name]

}

################################################################################
# ::utils::validate::Regexp
#   Validates an entry against a regular expression (via variable trace callbacks).
# Visibility:
#   Public.
# Inputs:
#   - expression (string): Regular expression to match.
#   - name (string): Variable name (trace callback argument `name1`).
#   - el (string): Array element (trace callback argument `name2`), or "".
#   - op (string): Trace operation (trace callback argument `op`).
# Returns:
#   - None.
# Side effects:
#   - On invalid input, calls `bell` and reverts to the previous value.
################################################################################
proc ::utils::validate::Regexp {expression name el op} {
  global $name ${name}_old
  set old ${name}_old
  if {![regexp $expression [set $name]]} {
    if {![info exist $old]} { set $old "" }
    set $name [set $old]
    bell
    return
  }
  set $old [set $name]
}

################################################################################
# ::utils::validate::roundScale
#   Snaps a scale value to a tick interval.
# Visibility:
#   Public.
# Inputs:
#   - var (string): Variable name to update.
#   - tickinterval (int|double): Scale tick interval.
#   - value (int|double): Current scale value.
# Returns:
#   - None.
# Side effects:
#   - Updates the variable named by `var`.
# Notes:
#   - This truncates towards zero: `int(value / tickinterval) * tickinterval`.
################################################################################
proc ::utils::validate::roundScale { var tickinterval value } {
  set $var [expr {int($value/$tickinterval ) * $tickinterval}]
}

################################################################################
# ::utils::validate::floatScale
#   Snaps a scale value to a tick interval and formats it to one decimal place.
# Visibility:
#   Public.
# Inputs:
#   - var (string): Variable name to update.
#   - tickinterval (double): Scale tick interval.
#   - value (double): Current scale value.
# Returns:
#   - None.
# Side effects:
#   - Updates the variable named by `var` to a formatted string (e.g. "5.0").
################################################################################
proc ::utils::validate::floatScale { var tickinterval value } {
  set $var [format "%.1f" [expr {($value/$tickinterval ) * $tickinterval}] ]
}
