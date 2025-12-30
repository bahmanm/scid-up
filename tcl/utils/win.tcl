# Copyright (C) 2008-2009 Pascal Georges
# Copyright (C) 2013-2018 Fulvio Benini
#
# This file is part of Scid (Shane's Chess Information Database).
#
# Scid is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.
#
# Scid is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Scid.  If not, see <http://www.gnu.org/licenses/>.

namespace eval ::win {}

################################################################################
# ::win::createWindow
#   Creates a managed tool window and docks or undocks it.
# Visibility:
#   Public.
# Inputs:
#   - w (string): Window path (e.g. `.pgnWin`).
#   - title (string): Window title / tab label.
#   - default_geometry (string, optional): Default geometry to remember for `w`
#     when no stored geometry exists.
# Returns:
#   - (int): 1 if the window was created; otherwise 0 when it already exists.
# Side effects:
#   - Creates `frame $w`.
#   - May initialise `::winGeometry($w)`.
#   - Delegates to `::win::manageWindow`.
################################################################################
proc ::win::createWindow { {w} {title} {default_geometry ""} } {
	if { [winfo exists $w] } {
		return 0
	}

	# Set default width and height values, if they do not exists
	if {![info exists ::winGeometry($w)]} {
		set ::winGeometry($w) $default_geometry
	}

	# Create the window
	frame $w
	::win::manageWindow $w $title

	return 1
}

################################################################################
# ::win::closeWindow
#   Closes a tool window, regardless of whether it is docked.
# Visibility:
#   Public.
# Inputs:
#   - w (string): Window path.
# Returns:
#   - None.
# Side effects:
#   - If `w` is docked, removes it from its notebook and records its previous
#     notebook in `::docking::prev_nb`.
#   - If `w` is undocked, calls `::win::saveWinGeometry`.
#   - Destroys the widget via `destroy`.
################################################################################
proc ::win::closeWindow {w} {
	lassign [::win::isDocked $w] docked_nb w
	if {$docked_nb ne ""} {
		::docking::remove_tab $w $docked_nb
		lappend ::docking::prev_nb [list $docked_nb $w]
		set ::docking::prev_nb [lsort -unique -index 1 $::docking::prev_nb]
	} else {
		::win::saveWinGeometry $w
	}
	destroy $w
}

################################################################################
# ::win::getWindows
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - (list): Window paths for all open tool windows (both undocked toplevel
#     windows and docked notebook tabs).
# Side effects:
#   - None.
################################################################################
proc ::win::getWindows {} {
	set res {}
	foreach undocked [array names ::docking::notebook_name] {
		if {[winfo exists $undocked]} {
			 lappend res $undocked
		}
	}
	foreach noteb [array names ::docking::tbs] {
		foreach docked [$noteb tabs] {
			 lappend res $docked
		}
	}
	return $res
}

################################################################################
# ::setTitle
#   Sets the title for a window, handling both docked and undocked states.
# Visibility:
#   Public.
# Inputs:
#   - w (string): Window path.
#   - title (string): Title to apply.
# Returns:
#   - None.
# Side effects:
#   - If `w` is docked, updates the containing notebook tab label.
#   - If `w` is undocked, updates the toplevel title via `wm title`.
# Notes:
#   - In docked mode, a leading "Scid: " prefix is trimmed to save space.
################################################################################
proc setTitle { w title } {
	lassign [::win::isDocked $w] docked_nb w
	if {$docked_nb ne ""} {
		# in docked mode trim down title to spare space
		if {[string equal -length 6 $title "Scid: "]} {
			set title [string range $title 6 end]
		}
		$docked_nb tab $w -text $title
	} else {
		wm title $w $title
	}
}

################################################################################
# ::win::getMenu
#   Returns the menu associated with a tool window.
# Visibility:
#   Public.
# Inputs:
#   - w (string): Window path, possibly including the `.fdock` prefix.
# Returns:
#   - (list): A 2-item list `{menu window}` where `menu` is the stored menu path
#     (or "" when unset) and `window` is the unadulterated window path (without
#     `.fdock`).
# Side effects:
#   - None.
################################################################################
proc ::win::getMenu {w} {
	lassign [::win::isDocked $w] docked_nb wnd
	if {[string equal -length 6 $wnd ".fdock"]} {
		set w [string replace $wnd 1 5]
	}
	if {[info exists ::win::menu_($wnd)]} {
		return [list $::win::menu_($wnd) $w]
	}
	return [list "" $w]
}

################################################################################
# ::setMenu
#   Sets the menu for a window, handling both docked and undocked states.
# Visibility:
#   Public.
# Inputs:
#   - w (string): Window path (without `.fdock`).
#   - m (string): Menu widget path.
# Returns:
#   - None.
# Side effects:
#   - If `w` is docked, adds a menu icon to the notebook tab.
#   - If `w` is undocked, configures the toplevel `-menu` option.
#   - Updates `::win::menu_($wnd)` for lookup by `::win::getMenu`.
################################################################################
proc setMenu {w m} {
	lassign [::win::isDocked $w] docked_nb wnd
	if {$docked_nb ne ""} {
		$docked_nb tab $wnd -image tb_tabmenu -compound left
	} else {
		$w configure -menu $m
	}
	set ::win::menu_($wnd) $m
}

################################################################################
# ::win::saveWinGeometry
# Visibility:
#   Public.
# Inputs:
#   - w (string): Window path.
# Returns:
#   - None.
# Side effects:
#   - When `w` is undocked, stores its geometry (or the sentinel "zoomed") in
#     `::winGeometry($w)`.
################################################################################
proc ::win::saveWinGeometry {w} {
	lassign [::win::isDocked $w] docked_nb w
	if {$docked_nb eq ""} {
		update idletasks
		if {[wm state $w] == "zoomed"} {
			set ::winGeometry($w) "zoomed"
		} else {
			set ::winGeometry($w) [wm geometry $w]
		}
	}
}

################################################################################
# ::win::restoreWinGeometry
#   Restores a previously stored geometry for an undocked window.
# Visibility:
#   Public.
# Inputs:
#   - w (string): Window path.
# Returns:
#   - (int): 1 if a stored geometry was applied; otherwise 0.
# Side effects:
#   - Updates the window geometry via `wm geometry` or applies the "zoomed"
#     state via `wm state` / `wm attributes`.
################################################################################
proc ::win::restoreWinGeometry {w} {
	if {[info exists ::winGeometry($w)]} {
		if {$::winGeometry($w) == "zoomed"} {
			if { $::windowsOS || $::macOS } {
				wm state $w zoomed
			} else {
				wm attributes $w -zoomed
			}
		} else {
			wm geometry $w $::winGeometry($w)
		}
		return 1
	}
	return 0
}

################################################################################
# ::win::isDocked
#   Determines whether a window is docked into a notebook.
# Visibility:
#   Public.
# Inputs:
#   - wnd (string): Window path (may be a descendant widget).
# Returns:
#   - (list): A 2-item list `{notebook window}` where `notebook` is the
#     containing notebook path (or "" if undocked) and `window` is the top-level
#     window container used by the docking framework (possibly `.fdock...`).
# Side effects:
#   - None.
################################################################################
proc ::win::isDocked {wnd} {
	# Get the window at the top of the hierarchy (not the toplevel)
	regexp {[.]\w*} "$wnd" wnd
	set f ".fdock[string range $wnd 1 end]"
	if {[winfo exists $f]} { set wnd $f }

	set docked_nb [ ::docking::find_tbn $wnd ]
	return [list $docked_nb $wnd]
}

################################################################################
# ::win::undockWindow
#   Undocks a window (removing it from a notebook when needed) and manages it as
#   a toplevel.
# Visibility:
#   Public.
# Inputs:
#   - wnd (string): Window path.
#   - srctab (string): Source notebook path, or "" if the window is not being
#     removed from a notebook.
#   - title (string, optional): Window title to set when undocking. When `srctab`
#     is non-empty, the title is derived from the tab text.
# Returns:
#   - None.
# Side effects:
#   - May call `::docking::remove_tab`.
#   - Converts `wnd` into a toplevel via `wm manage`, sets its title and close
#     protocol.
#   - Restores any window menu via `::setMenu`.
#   - Records the source notebook in `::docking::notebook_name($wnd)`.
#   - Schedules `::win::restoreWinGeometry` via `after idle after 1`.
################################################################################
proc ::win::undockWindow { wnd srctab {title ""} } {
	# The default widgets' bindtags is an empty list that's dynamically
	# resolved to window's name, window's class, window's toplevel and all.
	# Setting the bindtags we get the same docked/undocked event propagation.
	set children $wnd
	while {$children ne ""} {
		set tmp {}
		foreach elem $children {
			lappend tmp {*}[winfo children $elem]
			bindtags $elem [bindtags $elem]
		}
		set children $tmp
	}

	if {$srctab ne "" } {
		set old_options [::docking::remove_tab $wnd $srctab]
		set title "Scid: [dict get $old_options -text]"
	}

	wm manage $wnd
	wm title $wnd $title
	wm protocol $wnd WM_DELETE_WINDOW "::win::closeWindow $wnd"

	lassign [::win::getMenu $wnd] menu wmenu
	if {$menu ne ""} {
		#HACK: In Linux (tk8.6.8) without "update idletasks"
		#      sometimes the menu is not shown.
		update idletasks
		::setMenu $wmenu $menu
	}

	# Remember the source notebook
	set ::docking::notebook_name($wnd) $srctab

	#HACK: In Linux (tk8.6.8) without "after idle after 1"
	#      sometimes the geometry is not restored correctly.
	after idle after 1 "::win::restoreWinGeometry $wnd"
}

################################################################################
# ::win::dockWindow
#   Docks an undocked toplevel window into a notebook.
# Visibility:
#   Public.
# Inputs:
#   - wnd (string): Window path.
# Returns:
#   - None.
# Side effects:
#   - Saves the current window geometry via `::win::saveWinGeometry`.
#   - Removes the window from the window manager via `wm forget`.
#   - Inserts the window as a notebook tab via `::docking::insert_tab`.
#   - Restores any associated menu via `::setMenu`.
################################################################################
proc ::win::dockWindow {wnd} {
	::win::saveWinGeometry $wnd
	# in docked mode trim down title to spare space
	set title [wm title $wnd]
	if {[string equal -length 6 $title "Scid: "]} {
		set title [string range $title 6 end]
	}

	lassign [::win::getMenu $wnd] menu wmenu
	$wmenu configure -menu {}

	wm forget $wnd

	if {[winfo exists $::docking::notebook_name($wnd)]} {
		set dsttab $::docking::notebook_name($wnd)
	} else {
		set dsttab [::docking::choose_notebook $wnd]
	}
	unset ::docking::notebook_name($wnd)
	::docking::insert_tab $wnd $dsttab end \
		[list -text $title -image tb_close -compound left]

	if {$menu ne ""} { ::setMenu $wmenu $menu }
}

################################################################################
# ::win::toggleDocked
#   Toggles a window between docked and undocked states.
# Visibility:
#   Public.
# Inputs:
#   - wnd (string): Window path (may be a descendant widget).
# Returns:
#   - None.
# Side effects:
#   - Calls `::win::dockWindow` or `::win::undockWindow` depending on the
#     current docking state.
# Notes:
#   - The main board window (`.main`) is not docked/undocked here.
################################################################################
proc ::win::toggleDocked {wnd} {
	lassign [::win::isDocked $wnd] docked_nb wnd

	# Check if the window can be docked/undocked
	if {$wnd eq ".main" || [winfo class $wnd] ne "Frame"} {
		return
	}

	if {$docked_nb ne ""} {
		::win::undockWindow $wnd $docked_nb
	} else {
		::win::dockWindow $wnd
	}
}

################################################################################
# ::win::manageWindow
#   Applies the current docking policy when creating a tool window.
# Visibility:
#   Public.
# Inputs:
#   - wnd (string): Window path.
#   - title (string): Window title / tab label.
# Returns:
#   - None.
# Side effects:
#   - Clears any previously stored menu and notebook association for `wnd`.
#   - Inserts `wnd` into a notebook when docking is enabled, otherwise undocks it.
#   - When restoring a saved layout, obeys `::docking::layout_dest_notebook`.
################################################################################
proc ::win::manageWindow {wnd title} {
	unset -nocomplain ::win::menu_($wnd)
	unset -nocomplain ::docking::notebook_name($wnd)

	if { [info exists ::docking::layout_dest_notebook]} {
		set dsttab $::docking::layout_dest_notebook
		set docked [expr { $dsttab ne "undocked" }]
	} else  {
		set docked $::windowsDock
	}
	if {$docked} {
		if {![info exists dsttab]} {
			set dsttab [::docking::choose_notebook $wnd]
		}
		::docking::insert_tab $wnd $dsttab end \
			[list -text $title -image tb_close -compound left]
	} else {
		::win::undockWindow $wnd "" $title
	}
}

################################################################################
# ::win::createDialog
#   Creates a standard Scid dialog toplevel and applies theme styling.
# Visibility:
#   Public.
# Inputs:
#   - w (string): Toplevel window path.
#   - y (int, optional): Vertical padding. Use `0` for windows that have a menu.
# Returns:
#   - None.
# Side effects:
#   - Creates `toplevel $w` with padding and calls `::applyThemeColor_background`.
################################################################################
proc ::win::createDialog {w {y 10}} {
	toplevel $w -padx 10 -pady $y
	::applyThemeColor_background $w
}

################################################################################
# ::win::makeVisible
#   Ensures that a window is visible, selecting its tab when docked.
# Visibility:
#   Public.
# Inputs:
#   - wnd (string): Window path.
# Returns:
#   - None.
# Side effects:
#   - Selects the appropriate notebook tab when `wnd` is docked.
#   - Raises and deiconifies the containing toplevel.
################################################################################
proc ::win::makeVisible { wnd } {
	lassign [::win::isDocked $wnd] wnd_nb wnd_top
	if {$wnd_nb ne ""} {
		$wnd_nb select $wnd_top
		set wnd_top [winfo toplevel $wnd_top]
	}
	::raise $wnd_top
	wm deiconify $wnd_top
}

################################################################################
#
#     DockingFramework
#
#     Code is inspired by
#     http://wiki.tcl.tk/21846
#     which is published under BSD license
#
################################################################################

namespace eval docking {
  # associates notebook to paned window
  variable tbs
  variable prev_nb {}
}

################################################################################
# ::docking::find_tbn
#   Finds the notebook that currently contains the given tab.
# Visibility:
#   Private.
# Inputs:
#   - path (string): Window path.
# Returns:
#   - (string): Notebook widget path containing `path`, or "" if none.
# Side effects:
#   - None.
################################################################################
proc ::docking::find_tbn {path} {
  foreach tb [array names ::docking::tbs] {
    if {[lsearch -exact [$tb tabs] $path]>=0} {
      return $tb
    }
  }
  return {}
}

################################################################################
# ::docking::_cleanup_tabs
#   Removes empty notebooks and prunes empty paned windows (but keeps `.pw`).
# Visibility:
#   Private.
# Inputs:
#   - srctab (string): Notebook widget path.
# Returns:
#   - None.
# Side effects:
#   - Destroys `srctab` when it has no tabs.
#   - Updates `::docking::tbs`.
#   - May destroy empty paned windows up the hierarchy until reaching `.pw`.
################################################################################
proc ::docking::_cleanup_tabs {srctab} {
  variable tbs

  # if srctab is empty, then remove it
  if {[llength [$srctab tabs]]==0} {
    destroy $srctab
    set pw $tbs($srctab)
    unset tbs($srctab)

    while {[llength [$pw panes]]==0} {
      set parent [winfo parent $pw]

      if {$pw == ".pw"} {
        break
      }
      destroy $pw
      set pw $parent
    }

  }
}
################################################################################
################################################################################
################################################################################


# The coefficients for the selections of the container Notebook
# have been calculated doing a linear regression of this matrix:
# board   tabs    tabs^2   similar  sim^2   sim^3   area     fitness
# 0       0       0        0        0       0       0,9      120900
# 0       0       0        0        0       0       0,5      120500
# 0       0       0        0        0       0       0,1      120100
# 0       5       25       5        25      125     0,9      99900
# 0       5       25       5        25      125     0,5      99500
# 0       5       25       5        25      125     0,1      99100
# 0       3       9        3        9       27      0,9      93900
# 0       3       9        3        9       27      0,5      93500
# 0       3       9        3        9       27      0,1      93100
# 0       2       4        2        4       8       0,9      87900
# 0       2       4        2        4       8       0,5      87500
# 0       2       4        2        4       8       0,1      87100
# 0       4       16       3        9       27      0,9      81900
# 0       4       16       3        9       27      0,5      81500
# 0       4       16       3        9       27      0,1      81100
# 0       3       9        2        4       8       0,9      75900
# 0       3       9        2        4       8       0,5      75500
# 0       3       9        2        4       8       0,1      75100
# 0       2       4        1        1       1       0,9      69900
# 0       2       4        1        1       1       0,5      69500
# 0       2       4        1        1       1       0,1      69100
# 0       3       9        1        1       1       0,9      63900
# 0       3       9        1        1       1       0,5      63500
# 0       3       9        1        1       1       0,1      63100
# 0       2       4        1        1       1       0,9      57900
# 0       2       4        1        1       1       0,5      57500
# 0       2       4        1        1       1       0,1      57100
# 0       1       1        0        0       0       0,9      39900
# 0       1       1        0        0       0       0,5      39500
# 0       1       1        0        0       0       0,1      39100
# 0       3       9        0        0       0       0,9      33900
# 0       3       9        0        0       0       0,5      33500
# 0       3       9        0        0       0       0,1      33100
# 1       2       4        1        1       1       0,9      9900
# 1       2       4        1        1       1       0,5      9500
# 1       2       4        1        1       1       0,1      9100
# 1       1       1        0        0       0       0,9      7900
# 1       1       1        0        0       0       0,5      7500
# 1       1       1        0        0       0       0,1      7100
# 1       2       4        0        0       0       0,9      5900
# 1       2       4        0        0       0       0,5      5500
# 1       2       4        0        0       0       0,1      5100
################################################################################
# ::docking::choose_notebook
#   Chooses a destination notebook for docking a window.
# Visibility:
#   Public.
# Inputs:
#   - path (string): Window path being docked.
# Returns:
#   - (string): Notebook widget path.
# Side effects:
#   - None.
# Notes:
#   - Prefers the most recently used destination in `::docking::prev_nb` when it
#     still exists; otherwise uses a heuristic score over the available notebooks.
################################################################################
proc ::docking::choose_notebook { path } {
    lassign [lsearch -index 1 -inline $::docking::prev_nb $path] prev_dest
    if {[winfo exists $prev_dest]} { return $prev_dest }

    set dsttab {}
    set best_fitting ""
    foreach tb [array names ::docking::tbs] {
      if {[winfo class $tb] != "TNotebook"} { continue }

      set tabs [$tb tabs]

      # Features
      set feat(0) 1
      set coeff(0) "105622.84"
      # number of boards
      set feat(1) [llength [lsearch -all -regexp $tabs ".*main"]]
      set coeff(1) "-48019.31"
      # number of tabs
      set feat(2) [llength $tabs]
      set coeff(2) "-51266.84"
      # number of tabs^2
      set feat(3) [expr { $feat(2) * $feat(2) }]
      set coeff(3) "8661.97"
      # number of similar windows
      set name_striptrailnum [regsub {\d*$} $path ""]
      set feat(4) [llength [lsearch -all -regexp $tabs ".*$name_striptrailnum.*"]]
      set coeff(4) "40000.0"
      # number of similar windows^2
      set feat(5) [expr { $feat(4) * $feat(4) }]
      set coeff(5) "3000.0"
      # number of similar windows^3
      set feat(6) [expr { $feat(4) * $feat(4) * $feat(4) }]
      set coeff(6) "300.0"
      # ratio between the area of the notebook and the screen
      set feat(7) [expr { double([winfo width $tb] * [winfo height $tb]) }]
      set feat(7) [expr { $feat(7) / ([winfo screenwidth $tb] * [winfo screenheight $tb]) }]
      set coeff(7) "1000"

      set fit 0;
      for {set i 0} {$i < [array size feat]} {incr i} {
        set fit [expr { $fit + $feat($i) * $coeff($i)}]
      }

      if {$best_fitting == "" || $fit > $best_fitting} {
        set best_fitting $fit
        set dsttab $tb
      }
    }
    return $dsttab
}

################################################################################
# ::docking::insert_tab
#   Inserts a window as a tab in a notebook and selects it.
# Visibility:
#   Public.
# Inputs:
#   - wnd (string): Window path.
#   - dest_noteb (string): Destination notebook widget path.
#   - dest_pos (string|int, optional): Notebook insert position (default: "end").
#   - options (list, optional): Tab options to pass to `ttk::notebook insert`.
# Returns:
#   - None.
# Side effects:
#   - Inserts and selects the tab and raises the window.
################################################################################
proc ::docking::insert_tab {wnd dest_noteb {dest_pos "end"} {options ""}} {
	$dest_noteb insert $dest_pos $wnd {*}$options
	$dest_noteb select $wnd
	raise $wnd
}

################################################################################
# ::docking::remove_tab
#   Removes a window tab from a notebook.
# Visibility:
#   Public.
# Inputs:
#   - wnd (string): Window path.
#   - src_noteb (string): Source notebook widget path.
# Returns:
#   - (dict): The tab options (as returned by `ttk::notebook tab $wnd`).
# Side effects:
#   - Removes the tab and may clean up empty notebooks/panes.
################################################################################
proc ::docking::remove_tab {wnd src_noteb} {
	set options [$src_noteb tab $wnd]
	$src_noteb forget $wnd
	::docking::_cleanup_tabs $src_noteb
	return $options
}

################################################################################
# ::docking::generate_unique_path_
# Visibility:
#   Private.
# Inputs:
#   - prefix (string): Widget path prefix.
# Returns:
#   - (string): A widget path of the form "${prefix}<n>" that does not exist.
# Side effects:
#   - None.
################################################################################
proc ::docking::generate_unique_path_ { prefix } {
	set tmp 0
	while {[winfo exists $prefix$tmp]} {
		incr tmp
	}
	return "$prefix$tmp"
}

################################################################################
# ::docking::move_tab_
#   Moves a window tab between notebooks (and may split panes).
# Visibility:
#   Private.
# Inputs:
#   - wnd (string): Window path.
#   - src_noteb (string): Source notebook widget path.
#   - dest_noteb (string): Destination notebook widget path, or a direction
#     anchor (`n`, `s`, `e`, `w`) to create a new adjacent notebook.
#   - dest_pos (string|int, optional): Insert position (default: "end").
# Returns:
#   - None.
# Side effects:
#   - Removes the tab from the source notebook and inserts it into the
#     destination.
#   - May create a new notebook and/or paned window to satisfy the requested
#     direction anchor.
################################################################################
proc ::docking::move_tab_ {wnd src_noteb dest_noteb {dest_pos "end"} } {
	set options [::docking::remove_tab $wnd $src_noteb]
	if {[string length $dest_noteb] == 1} {
		set idx [::docking::orient_pw_ $src_noteb $dest_noteb]
		if {$dest_noteb eq "s" || $dest_noteb eq "e"} {
			incr idx
		}
		set pw $::docking::tbs($src_noteb)
		set dest_noteb [::docking::generate_unique_path_ $pw.tb]
		::docking::create_notebook_ $dest_noteb
		::docking::insert_notebook_ $pw $idx $dest_noteb
	}
	::docking::insert_tab $wnd $dest_noteb $dest_pos $options
}

################################################################################
# ::docking::orient_pw_
#   Ensures that the paned window containing a notebook has the correct
#   orientation for adding a neighbouring notebook.
# Visibility:
#   Private.
# Inputs:
#   - tbn (string): Notebook widget path.
#   - anchor (string): Direction anchor (`n`, `s`, `e`, `w`).
# Returns:
#   - (int): The index of `tbn` within its (possibly newly created) paned window.
# Side effects:
#   - May create a new `ttk::panedwindow` and reparent the notebook.
################################################################################
proc ::docking::orient_pw_ {tbn anchor} {
	variable tbs

	if {$anchor=="w" || $anchor=="e"} {
		set orient "horizontal"
	} else {
		set orient "vertical"
	}

	set pw $tbs($tbn)
	set idx [lsearch -exact [$pw panes] $tbn]

	if {[$pw cget -orient] ne $orient} {
		# create new paned window
		set old_pw $pw
		set pw [::docking::generate_unique_path_ $pw.pw]
		ttk::panedwindow $pw -orient $orient
		lower $pw
		# move old notebook
		$old_pw forget $tbn
		::docking::insert_notebook_ $pw end $tbn
		::docking::insert_pane_ $old_pw $idx $pw
		set idx 0
	}
	return $idx
}

################################################################################
# ::docking::insert_pane_
# Visibility:
#   Private.
# Inputs:
#   - pw (string): Paned window widget path.
#   - idx (string|int): Insert position (or "end").
#   - wnd (string): Pane widget path to insert.
# Returns:
#   - None.
# Side effects:
#   - Inserts a new pane into `pw` with weight 1.
################################################################################
proc ::docking::insert_pane_ {pw idx wnd} {
	if {$idx ne "end" && $idx >= [llength [$pw panes]]} {
		set idx "end"
	}
	$pw insert $idx $wnd -weight 1
}

################################################################################
# ::docking::insert_notebook_
# Visibility:
#   Private.
# Inputs:
#   - pw (string): Paned window widget path.
#   - idx (string|int): Insert position (or "end").
#   - noteb (string): Notebook widget path.
# Returns:
#   - None.
# Side effects:
#   - Inserts `noteb` into `pw` and records its parent in `::docking::tbs`.
################################################################################
proc ::docking::insert_notebook_ {pw idx noteb} {
	::docking::insert_pane_ $pw $idx $noteb
	set ::docking::tbs($noteb) $pw
}

################################################################################
# ::docking::create_notebook_
#   Creates a new dockable notebook and wires up its drag/click bindings.
# Visibility:
#   Private.
# Inputs:
#   - path (string): Notebook widget path.
# Returns:
#   - (string): The created notebook widget path.
# Side effects:
#   - Creates `ttk::notebook $path`.
#   - Installs bindings used for tab drag, close and context menu actions.
################################################################################
proc ::docking::create_notebook_ {path} {
	set noteb [ttk::notebook $path -width 1 -height 1]
	bind $noteb <B1-Motion> {
		if {[info exists ::docking::motion_]} { continue }
		set ::docking::motion_ [::docking::identify_tab_ %W %x %y]
		if {[lindex $::docking::motion_ 0] eq ""} {
			# Do nothing if motion started outside a tab
			continue
		}
		if {[lindex $::docking::motion_ 1]} {
			# Not a motion event if it starts and ends over the icon
			unset ::docking::motion_
		} else {
			%W configure -cursor hand2
		}
	}
	bind $noteb <ButtonRelease-1> {
		if {[info exists ::docking::motion_]} {
			%W configure -cursor {}
			::docking::manage_motion_ %W %X %Y
		} else {
			::docking::manage_click_ %W %X %Y %x %y
		}
	}
	bind $noteb <ButtonRelease-$::MB3> {
		::docking::manage_rightclick_ %W %X %Y %x %y
	}
	return $noteb
}

################################################################################
# ::docking::identify_tab_
#   Identifies which tab is under a point in a notebook.
# Visibility:
#   Private.
# Inputs:
#   - noteb (string): Notebook widget path.
#   - localX (int): X coordinate relative to the notebook.
#   - localY (int): Y coordinate relative to the notebook.
# Returns:
#   - (list): A 2-item list `{tab isIcon}` where `tab` is the tab index (or "")
#     and `isIcon` is true when the point is over the tab image.
# Side effects:
#   - None.
################################################################################
proc ::docking::identify_tab_ {noteb localX localY} {
	set isIcon 0
	set tab [$noteb identify tab $localX $localY]
	if {$tab ne ""} {
		set icon [$noteb tab $tab -image]
		if {$icon ne ""} {
			set iconW [expr { 4 + [image width $icon] }]
			set localX [expr { $localX - $iconW }]
			if {$localX <= 0 || [$noteb identify tab $localX $localY] != $tab} {
				set isIcon 1
			}
		}
	}
	return [list $tab $isIcon]
}

################################################################################
# ::docking::manage_motion_
#   Handles drag-to-relocate events for notebook tabs.
# Visibility:
#   Private.
# Inputs:
#   - src_noteb (string): Source notebook widget path.
#   - x (int): Root X coordinate.
#   - y (int): Root Y coordinate.
# Returns:
#   - None.
# Side effects:
#   - May reorder tabs within a notebook, move a tab between notebooks, or undock
#     a window.
################################################################################
proc ::docking::manage_motion_ {src_noteb x y} {
	lassign $::docking::motion_ src_tab
	unset ::docking::motion_
	if {$src_tab eq ""} { return }

	set wnd [lindex [$src_noteb tabs] $src_tab]
	set dest_noteb [winfo containing $x $y]
	if {$dest_noteb eq ""} {
		::win::undockWindow $wnd $src_noteb
		return
	}
	if {![info exists ::docking::tbs($dest_noteb)]} {
		return
	}

	set localX [expr $x-[winfo rootx $dest_noteb]]
	set localY [expr $y-[winfo rooty $dest_noteb]]
	set dest_pos [$dest_noteb identify tab $localX $localY]
	if {$dest_pos eq ""} { set dest_pos "end" }

	if {$src_noteb eq $dest_noteb} {
		$dest_noteb insert $dest_pos $wnd
	} else {
		::docking::move_tab_ $wnd $src_noteb $dest_noteb $dest_pos
	}
}

################################################################################
# ::docking::manage_click_
#   Handles a left-click on a tab icon (menu or close).
# Visibility:
#   Private.
# Inputs:
#   - noteb (string): Notebook widget path.
#   - x (int): Root X coordinate.
#   - y (int): Root Y coordinate.
#   - localX (int): X coordinate relative to the notebook.
#   - localY (int): Y coordinate relative to the notebook.
# Returns:
#   - None.
# Side effects:
#   - Pops up the window menu (if present) or closes the window.
################################################################################
proc ::docking::manage_click_ {noteb x y localX localY} {
	lassign [::docking::identify_tab_ $noteb $localX $localY] tab isIcon
	if {$tab eq "" || ! $isIcon} { return }

	set wnd [lindex [$noteb tabs] $tab]
	lassign [::win::getMenu $wnd] menu
	if {$menu ne ""} {
		tk_popup $menu $x $y
	} else {
		::win::closeWindow $wnd
	}
}

################################################################################
# ::docking::manage_rightclick_
#   Handles right-click on a tab label by showing a window management menu.
# Visibility:
#   Private.
# Inputs:
#   - noteb (string): Notebook widget path.
#   - x (int): Root X coordinate.
#   - y (int): Root Y coordinate.
#   - localX (int): X coordinate relative to the notebook.
#   - localY (int): Y coordinate relative to the notebook.
# Returns:
#   - None.
# Side effects:
#   - Creates/destroys `.ctxtMenu` and displays it via `tk_popup`.
#   - Selects the clicked tab.
################################################################################
proc ::docking::manage_rightclick_ {noteb x y localX localY} {
	lassign [::docking::identify_tab_ $noteb $localX $localY] tab isIcon
	if {$tab eq "" || $isIcon} { return }

	$noteb select $tab

	set noteb_tabs [$noteb tabs]
	set state [expr { [llength $noteb_tabs] > 1 ? "normal" : "disabled" }]
	set wnd [lindex $noteb_tabs $tab]

	set m .ctxtMenu
	if { [winfo exists $m] } { destroy $m }
	menu $m -tearoff 0
	$m add command -label [ ::tr DockTop ] -state $state \
		-command "::docking::move_tab_ $wnd $noteb n"
	$m add command -label [ ::tr DockBottom ] -state $state \
		-command "::docking::move_tab_ $wnd $noteb s"
	$m add command -label [ ::tr DockLeft ] -state $state \
		-command "::docking::move_tab_ $wnd $noteb w"
	$m add command -label [ ::tr DockRight ] -state $state \
		-command "::docking::move_tab_ $wnd $noteb e"
	# Main board can not be closed or undocked
	if { $wnd != ".main" } {
		$m add separator
		$m add command -label [ ::tr Undock ] -command "::win::undockWindow $wnd $noteb"
		$m add command -label [ ::tr Close ] -command "::win::closeWindow $wnd"
	}
	tk_popup $m $x $y
}


################################################################################
# Layout management
################################################################################

################################################################################
# ::docking::layout_save
#   Saves the current docking layout into an in-memory slot.
# Visibility:
#   Public.
# Inputs:
#   - slot (string): Layout slot name.
# Returns:
#   - None.
# Side effects:
#   - Updates `::docking::layout_list($slot)` with window geometry, paned-window
#     structure, and the list of currently undocked windows.
################################################################################
# saves layout (bail out if some windows cannot be restored)
proc ::docking::layout_save { slot } {
  # on Windows the geometry is false if the window was maximized (x and y offsets are the ones before the maximization)
  set geometry [wm geometry .]
  set ::docking::layout_list($slot) [list [list "MainWindowGeometry" $geometry] ]
  if {[wm state .] == "zoomed"} {
    if { [scan $geometry "%dx%d+%d+%d" w h x y] == 4 } {
      set geometry "${w}x${h}+0+0"
      set ::docking::layout_list($slot) [list [list "MainWindowGeometry" $geometry "zoomed"] ]
    }
  }

  lappend ::docking::layout_list($slot) [ layout_save_pw .pw ]

  # Append undocked windows
  foreach wnd [array names ::docking::notebook_name] {
    if {[winfo exists $wnd]} {
      lappend ::docking::layout_list($slot) [list [list "Toplevel" $wnd]]
    }
  }
}
################################################################################
# ::docking::layout_save_pw
#   Serialises a paned window and its nested notebooks for layout persistence.
# Visibility:
#   Private.
# Inputs:
#   - pw (string): Paned window widget path.
# Returns:
#   - (list): A serialised representation of `pw` and its panes.
# Side effects:
#   - None.
################################################################################
proc ::docking::layout_save_pw {pw} {
  set ret {}

  # record sash position for each panes
  set sashpos {}
  for {set i 0} {$i < [ expr [llength [$pw panes]] -1]} {incr i} {
    lappend sashpos [$pw sashpos $i]
  }
  lappend ret [list $pw [$pw cget -orient ] $sashpos ]

  foreach p [$pw panes] {
    if {[winfo class $p] == "TNotebook"} {
      set wins [$p tabs]
      # Keep only the first glistWin in each pane
      set glistWins [lsearch -all -regexp $wins "\.(fdock)?glistWin\[0-9\]+"]
      set i [llength $glistWins]
      while {$i > 1} {
        incr i -1
        set remove [lindex $glistWins $i]
        set wins [lreplace $wins $remove $remove]
      }
      lappend ret [list "TNotebook" $p $wins ]

    } elseif {[winfo class $p] == "TPanedwindow"} {
      lappend ret [ list "TPanedwindow" [layout_save_pw $p] ]
    }
  }

  return $ret
}

################################################################################
# ::docking::layout_restore_pw
#   Recreates paned windows and notebooks from saved layout data.
# Visibility:
#   Private.
# Inputs:
#   - data (list): Serialised layout data (as produced by `layout_save_pw`).
# Returns:
#   - None.
# Side effects:
#   - Creates `ttk::panedwindow` and `ttk::notebook` widgets.
#   - Populates `::docking::restore_wnds` and `::docking::restore_sashpos`.
################################################################################
proc ::docking::layout_restore_pw { data } {
  foreach elt $data {
    lassign $elt type pathName
    if {$type == "Toplevel"} {
      lappend ::docking::restore_wnds [list "undocked" $pathName ]

    } elseif {$type == "TPanedwindow"} {
      layout_restore_pw [lindex $elt 1]

    } elseif {$type == "TNotebook"} {
      ::docking::create_notebook_ $pathName
      ::docking::insert_notebook_ $pw end $pathName
      foreach wnd [lindex $elt 2] {
        lappend ::docking::restore_wnds [list $pathName $wnd]
      }

    } else {
      lassign $elt pw orient sash_positions
      if {$sash_positions ne ""} {
        lappend ::docking::restore_sashpos [ list $pw $sash_positions ]
      }
      # build a new pw
      ttk::panedwindow $pw -orient $orient
      set parent [string range $pw 0 [expr [string last "." $pw ]-1 ] ]
      if { $parent eq "" } {
        pack $pw -fill both -expand true
      } else {
        ::docking::insert_pane_ $parent end $pw
      }
    }
  }
}

################################################################################
# ::docking::create_window
#   Creates (opens) a window given its path name during layout restore.
# Visibility:
#   Private.
# Inputs:
#   - wnd (string): Window path to create.
# Returns:
#   - None.
# Side effects:
#   - Calls the appropriate window-open routine based on `wnd`.
################################################################################
proc ::docking::create_window {wnd} {
      switch -regexp -matchvar regmatch -- $wnd {
      "\.(fdock)?main"                { ::docking::insert_tab .main $::docking::layout_dest_notebook end [list -text $::tr(Board) -compound none] }
      "\.(fdock)?pgnWin"              { ::pgn::OpenClose }
      "\.(fdock)?baseWin"             { ::windows::switcher::Open }
      "\.(fdock)?bookWin"             { ::book::open }
      "\.(fdock)?ecograph"            { ::windows::eco::OpenClose }
      "\.(fdock)?commentWin"          { ::makeCommentWin }
      "\.(fdock)?oprepWin"            { ::optable::makeReportWin }
      "\.(fdock)?plist"               { ::plist::Open }
      "\.(fdock)?tourney"             { ::tourney::Open }
      "\.(fdock)?sgraph"              { ::tools::graphs::score::Refresh }
      "\.(fdock)?glistWin([0-9]+)"    { ::windows::gamelist::Open }
      "\.(fdock)?treeWin([0-9]+)"     { ::tree::make [lindex $regmatch end]}
      "\.(fdock)?engineWin([0-9]+)"   { ::enginewin::Open [lindex $regmatch end]}
      "\.(fdock)?analysisWin([0-9]+)" { ::makeAnalysisWin [lindex $regmatch end] 0 0}
      "\.(fdock)?crosstableWin"       { ::crosstab::Open }
      }
}

################################################################################
# ::docking::layout_restore
#   Restores a previously saved docking layout.
# Visibility:
#   Public.
# Inputs:
#   - slot (string): Layout slot name.
# Returns:
#   - None.
# Side effects:
#   - Closes existing tool windows and destroys current layout widgets.
#   - Recreates paned windows/notebooks, restores window geometry and sash
#     positions, and reopens windows recorded in the layout.
################################################################################
proc ::docking::layout_restore { slot } {
  # if no layout recorded, retry with the last used
  if { $::docking::layout_list($slot) == {} } {
    if { $slot != "auto" } { ::docking::layout_restore "auto" }
    return
  }

  # closeAll
  foreach wnd [::win::getWindows] {
    ::win::closeWindow $wnd
  }
  foreach wnd [winfo children .] {
    if { [winfo class $wnd] ne "Menu" } {
      destroy $wnd
    }
  }

  # Parse geometry, sashpos and windows; create paned windows and notebooks
  set restore_geometry {}
  set ::docking::restore_sashpos {}
  set ::docking::restore_wnds {}
  foreach data $::docking::layout_list($slot) {
    if {[lindex $data 0] eq "MainWindowGeometry"} {
      lappend restore_geometry [list "." [lindex $data 1] [lindex $data 2]]
    } else {
      ::docking::layout_restore_pw $data
    }
  }

  # Restore geometry
  foreach geom $restore_geometry {
    lassign $geom wnd size_pos zoomed
    wm geometry $wnd $size_pos
    if {$zoomed eq "zoomed"} {
      if { $::windowsOS || $::macOS } {
        wm state $wnd zoomed
      } else {
        wm attributes $wnd -zoomed
      }
    }
  }

  # Restore paned windows' sash positions
  foreach sashpos $::docking::restore_sashpos {
    # It is necessary to process all the events beforehand because
    # "sashpos" will query the panedwindow's available space.
    update

    lassign $sashpos pw sash
    set i 0
    foreach pos $sash {
      $pw sashpos $i $pos
      incr i
    }
  }
  unset -nocomplain ::docking::restore_sashpos

  # Create .main beforehand because some other windows depend on it
  # TODO: remove the dependencies
  set ::docking::layout_dest_notebook [::docking::choose_notebook $wnd]
  ::CreateMainBoard .main
  lassign [::win::isDocked .main] docked_nb w
  $docked_nb forget $w

  # Restore windows
  foreach pair $::docking::restore_wnds {
    lassign $pair ::docking::layout_dest_notebook wnd
    ::docking::create_window $wnd

    # Needed for ttk::notebooks with multiple tabs (e.g., .baseWin and. main)
    # that are not displayed correctly otherwise (due to "notebook select").
    update
  }
  unset -nocomplain ::docking::layout_dest_notebook
  unset -nocomplain ::docking::restore_wnds

  ::win::makeVisible .main.board
  ::focus .main.board
}
