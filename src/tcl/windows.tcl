###
### windows.tcl: part of Scid.
### Copyright (C) 1999-2003  Shane Hudson.
###


########################################################################
###  Optional windows: all off initially.

set treeWin 0
set pgnWin 0
set filterGraph 0

################################################################################
# createToplevel
#   Creates (or raises) a dockable toplevel window.
# Visibility:
#   Public.
# Inputs:
#   - w: (Optional) Toplevel widget path to create/raise (e.g. ".analysisWin").
#   - closeto: (Optional) Reserved; currently unused.
# Returns:
#   - "already_exists" when the toplevel already exists (and is raised).
#   - None otherwise.
# Side effects:
#   - Creates a container frame `.fdock<name>` and the toplevel `$w` when missing.
#   - When `$w` already exists, resolves dock state via `::win::isDocked` and either:
#     - selects the docked tab in its notebook, or
#     - deiconifies the toplevel.
#   - Initialises `::winGeometry($container)` if missing.
#   - Calls `::win::manageWindow` for the container frame.
################################################################################
proc createToplevel { {w} {closeto ""} } {
  # Raise window if already exist
  if { [winfo exists $w] } {
    lassign [::win::isDocked $w] docked_nb w
    if {$docked_nb ne ""} {
        $docked_nb select $w
    } else {
        wm deiconify $w
    }
    return "already_exists"
  }

  set f ".fdock[string range $w 1 end]"
  frame $f  -container 1
  toplevel $w -use [ winfo id $f ]

  # Set default width and height values, if they do not exists
  if {![info exists ::winGeometry($f)]} {
    set ::winGeometry($f) ""
  }

  ::win::manageWindow $f ""
}

################################################################################
# createToplevelFinalize
#   Registers cleanup so docked tabs are removed when a toplevel is destroyed.
# Visibility:
#   Public.
# Inputs:
#   - w: Toplevel widget path previously created by `createToplevel`.
# Returns:
#   - None.
# Side effects:
#   - Binds `$w`'s `<Destroy>` event to invoke `cleanup_todo_remove $w`.
################################################################################
proc createToplevelFinalize {w} {
    bind $w <Destroy> [list +apply {{w} {
      if {[string equal $w %W]} {
        cleanup_todo_remove $w
      }
    } ::} $w]
}

################################################################################
# cleanup_todo_remove
#   Removes the docking container for a toplevel and (if docked) cleans up its tab.
# Visibility:
#   Private.
# Inputs:
#   - w: Toplevel widget path to clean up.
# Returns:
#   - No meaningful return value (returns `0/1` from `catch`).
# Side effects:
#   - If docked, forgets the corresponding tab and calls `::docking::_cleanup_tabs`.
#   - Schedules destruction of the `.fdock<name>` container frame via `after idle`.
#   - Attempts to restore focus to `.main`.
################################################################################
proc cleanup_todo_remove { w } {
    set dockw ".fdock[string range $w 1 end]"
    set tab [::docking::find_tbn $dockw]
    if {$tab != ""} {
      $tab forget $dockw
      ::docking::_cleanup_tabs $tab
    }
    after idle "if {[winfo exists $dockw]} { destroy $dockw }"
    catch { focus .main }
}

################################################################################
# recordWinSize
#   Records a window's geometry (width/height and X/Y) for later restoration.
# Visibility:
#   Public.
# Inputs:
#   - win: Toplevel/widget path whose geometry should be recorded.
# Returns:
#   - None.
# Side effects:
#   - Updates `winWidth($win)`, `winHeight($win)`, `winX($win)`, and `winY($win)`.
#   - Reads `wm geometry $win` (expects a "<w>x<h>+<x>+<y>" shape).
################################################################################
proc recordWinSize {win} {
  global winWidth winHeight winX winY
  if {![winfo exists $win]} { return }
  set temp [wm geometry $win]

  set suffix ""
  set n [scan $temp "%dx%d+%d+%d" width height x y]
  if {$n == 4} {
    set winWidth${suffix}($win) $width
    set winHeight${suffix}($win) $height
    set winX${suffix}($win) $x
    set winY${suffix}($win) $y
  }
}

################################################################################
# setWinLocation
#   Restores a window's saved screen location (X/Y) when available.
# Visibility:
#   Public.
# Inputs:
#   - win: Toplevel/widget path whose location should be restored.
# Returns:
#   - No meaningful return value (returns `0/1` from `catch` when it applies geometry).
# Side effects:
#   - Reads `winX($win)` / `winY($win)` and may call `wm geometry $win +x+y`.
################################################################################
proc setWinLocation {win} {
  global winX winY
  set suffix ""
  if {[info exists winX${suffix}($win)]  &&  [info exists winY${suffix}($win)]  && \
        [set winX${suffix}($win)] >= 0  &&  [set winY${suffix}($win)] >= 0} {
    catch [list wm geometry $win "+[set winX${suffix}($win)]+[set winY${suffix}($win)]"]
  }
}

################################################################################
# setWinSize
#   Restores a window's saved size (width/height) when available.
# Visibility:
#   Public.
# Inputs:
#   - win: Toplevel/widget path whose size should be restored.
# Returns:
#   - No meaningful return value (returns `0/1` from `catch` when it applies geometry).
# Side effects:
#   - Reads `winWidth($win)` / `winHeight($win)` and may call `wm geometry $win wxh`.
################################################################################
proc setWinSize {win} {
  global winWidth winHeight
  set suffix ""
  if {[info exists winWidth${suffix}($win)]  &&  [info exists winHeight${suffix}($win)]  &&  \
        [set winWidth${suffix}($win) ] > 0  &&  [set winHeight${suffix}($win) ] > 0 } {
    catch [list wm geometry $win "[set winWidth${suffix}($win) ]x[set winHeight${suffix}($win) ]"]
  }
}

###
### End of file: windows.tcl
###
