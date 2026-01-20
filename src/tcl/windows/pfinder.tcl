### file pfinder.tcl: part of Scid.

####################
# Player List window

namespace eval ::plist {}

set plistWin 0

set ::plist::sort Name

################################################################################
# ::plist::defaults
#   Resets the player list search criteria to default values.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Sets `::plist::name`, `::plist::minGames`, `::plist::maxGames`,
#     `::plist::minElo`, `::plist::maxElo`, and `::plist::size`.
################################################################################
proc ::plist::defaults {} {
  set ::plist::name ""
  set ::plist::minGames ""
  set ::plist::maxGames ""
  set ::plist::minElo ""
  set ::plist::maxElo ""
  set ::plist::size 50
}

::plist::defaults

trace add variable ::plist::minElo write [list ::utils::validate::Integer [sc_info limit elo] 0]
trace add variable ::plist::maxElo write [list ::utils::validate::Integer [sc_info limit elo] 0]
trace add variable ::plist::minGames write [list ::utils::validate::Integer 9999 0]
trace add variable ::plist::maxGames write [list ::utils::validate::Integer 9999 0]

################################################################################
# ::plist::toggle
#   Toggles the player list window.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Closes `.plist` if it exists; otherwise opens it via `::plist::Open`.
################################################################################
proc ::plist::toggle {} {
  set w .plist
  if {[winfo exists $w]} {
    ::win::closeWindow $w
  } else {
    ::plist::Open
  }
}

################################################################################
# ::plist::Open
#   Opens the player list window (if it is not already open) and populates it.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Creates `.plist` and its widgets, binds event handlers, and focuses the
#     search field.
#   - Sets `::plistWin` to 1 while the window is open.
#   - Registers an input-validation trace for `::plist::size`.
#   - Runs an initial refresh via `::plist::refresh`.
################################################################################
proc ::plist::Open {} {
  set w .plist
  if {[winfo exists .plist]} { return }
  set ::plistWin 1

  ::createToplevel $w
  ::setTitle $w "[tr ScidUp]: [tr WindowsPList]"

  autoscrollText both $w.t $w.t.text Treeview
  $w.t.text configure -width 55 -height 25 -font font_Small -wrap none  -state normal
  set xwidth [font measure [$w.t.text cget -font] "0"]
  set tablist {}
  foreach {tab justify} {4 r 10 r 18 r 24 r 32 r 35 l} {
    set tabwidth [expr {$xwidth * $tab} ]
    lappend tablist $tabwidth $justify
  }
  $w.t.text configure -tabs $tablist
  $w.t.text tag configure ng -foreground DodgerBlue3
  $w.t.text tag configure date -foreground firebrick3
  $w.t.text tag configure elo -foreground Green
  $w.t.text tag configure title -background lightSteelBlue

  set font font_Small
  set fbold font_SmallBold

  set f $w.o1
  ttk::frame $f
  ttk::label $f.nlabel -text $::tr(Player:) -font $fbold
  ttk::combobox $f.name -textvariable ::plist::name -width 20
  ::utils::history::SetCombobox ::plist::name $f.name
  focus $f.name
  ttk::label $f.size -text $::tr(TmtLimit:) -font $fbold
  ttk::combobox $f.esize -width 4 -justify right -textvar ::plist::size -values {50 100 200 500 1000}
  trace add variable ::plist::size write {::utils::validate::Integer 1000 0}
  # foreach n {50 100 200 500 1000} {
    # $f.esize list insert end $n
  # }
  pack $f.esize -side right -padx "0 8" -pady 2
  pack $f.size -side right -pady 2
  pack $f.nlabel -side left -padx "8 0" -pady 2
  pack $f.name -side left -pady 2

  set f $w.o2
  ttk::frame $f
  ttk::label $f.elo -text "[tr PListSortElo]:" -font $fbold
  ttk::entry $f.emin -textvariable ::plist::minElo
  ttk::label $f.eto -text "-"
  ttk::entry $f.emax -textvariable ::plist::maxElo
  ttk::label $f.games -text "[tr PListSortGames]:" -font $fbold
  ttk::entry $f.gmin -textvariable ::plist::minGames
  ttk::label $f.gto -text "-"
  ttk::entry $f.gmax -textvariable ::plist::maxGames

  foreach entry {emin emax} {
    $f.$entry configure -width 4 -justify right -font $font
  }

  foreach entry {gmin gmax} {
    $f.$entry configure -width 6 -justify right -font $font
  }

  pack $f.elo -side left -padx "8 0"
  pack $f.emin $f.eto $f.emax -side left
  pack $f.gmax -side right -padx "0 8"
  pack $f.gto $f.gmin $f.games -side right

  ttk::frame $w.b
  dialogbutton $w.b.defaults -text $::tr(Defaults) -command ::plist::defaults
  dialogbutton $w.b.update -text $::tr(Search) -command ::plist::refresh
  packbuttons left $w.b.defaults
  packbuttons right $w.b.update

  grid $w.o1 -sticky news
  grid $w.o2 -sticky news
  grid $w.b  -sticky news
  grid $w.t  -sticky news
  grid rowconfigure $w 3 -weight 1
  grid columnconfigure $w 0 -weight 1

  bind $w <F1> {helpWindow PList}
  bind $w.t <Destroy> { set plistWin 0 }
  bind $w <Return> ::plist::refresh

  ::plist::refresh
}

################################################################################
# ::plist::refresh
#   Rebuilds the player list display using the current search options.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Updates search history via `::utils::history::AddEntry`.
#   - Queries player data via `sc_name plist ...`.
#   - Clears and repopulates `.plist.t.text`, including tag configuration and
#     per-row tag bindings (hover + click).
#   - Displays any `sc_name` error message in the text widget.
#   - Temporarily shows a busy cursor.
################################################################################
proc ::plist::refresh {} {
  set w .plist
  if {! [winfo exists $w]} { return }

  busyCursor .
  ::utils::history::AddEntry ::plist::name $::plist::name
  set t $w.t.text
  $t configure -state normal
  $t delete 1.0 end

  $t insert end "\t" title
  foreach i {Games Oldest Newest Elo Name} {
    $t tag configure s$i -font font_SmallBold
    $t tag bind s$i <1> [list apply {{i} {
      set ::plist::sort $i
      ::plist::refresh
    } ::} $i]
    $t tag bind s$i <Any-Enter> [list $t tag config s$i -foreground red]
    $t tag bind s$i <Any-Leave> [list $t tag config s$i -foreground {}]
    $t insert end "\t" title
    $t insert end [tr PListSort$i] [list title s$i]
  }
  $t insert end "\n" title

  ::plist::check
  #TODO: check if this update is necessary
  update

  if {[catch { sc_name plist {*}[::plist::getSearchOptions] } pdata]} {
    $t insert end "\n$pdata\n"
    unbusyCursor .
    return
  }

  set hc yellow
  set count 0
  foreach player $pdata {
    incr count
    set ng [lindex $player 0]
    set oldest [lindex $player 1]
    set newest [lindex $player 2]
    set elo [lindex $player 3]
    set name [lindex $player 4]

    $t tag bind p$count <ButtonPress-1> [list ::pinfo::playerInfo $name]
    #$t tag bind p$count <ButtonPress-$::MB3> [list playerInfo $name]
    $t tag bind p$count <Any-Enter> \
      "$t tag configure p$count -background $hc"
    $t tag bind p$count <Any-Leave> \
      "$t tag configure p$count -background {}"
    $t insert end "\n"
    $t insert end "\t$count\t" p$count
    $t insert end $ng [list ng p$count]
    $t insert end "\t" p$count
    $t insert end $oldest [list date p$count]
    $t insert end "\t" p$count
    $t insert end "- $newest" [list date p$count]
    $t insert end "\t" p$count
    $t insert end $elo [list elo p$count]
    $t insert end "\t" p$count
    $t insert end $name [list name p$count]
  }
  $t insert end "\n"
  $t configure -state disabled
  unbusyCursor .
}

################################################################################
# ::plist::check
#   Normalises the numeric range fields by swapping min/max when required.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - May swap `::plist::minGames`/`::plist::maxGames`.
#   - May swap `::plist::minElo`/`::plist::maxElo`.
################################################################################
proc ::plist::check {} {
  if { $::plist::maxGames ne "" && $::plist::minGames > $::plist::maxGames} {
    set help $::plist::maxGames
    set ::plist::maxGames $::plist::minGames
    set ::plist::minGames $help
  }
  if {$::plist::maxElo ne "" && $::plist::minElo > $::plist::maxElo} {
    set help $::plist::maxElo
    set ::plist::maxElo $::plist::minElo
    set ::plist::minElo $help
  }
}

################################################################################
# ::plist::getSearchOptions
#   Builds the `sc_name plist` search options list from the current UI state.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - A list of option/value pairs suitable for `sc_name plist`.
# Side effects:
#   - None.
################################################################################
proc ::plist::getSearchOptions {} {
		set options {}
		if {$::plist::name ne ""} {
			lappend options "-name" $::plist::name
	}
	if {$::plist::size ne ""} {
		lappend options "-size" $::plist::size
	}
	if {$::plist::minGames ne ""} {
		lappend options "-minGames" $::plist::minGames
	}
	if {$::plist::maxGames ne ""} {
		lappend options "-maxGames" $::plist::maxGames
	}
	if {$::plist::minElo ne ""} {
		lappend options "-minElo" $::plist::minElo
	}
	if {$::plist::maxElo ne ""} {
		lappend options "-maxElo" $::plist::maxElo
	}
	if {$::plist::sort ne ""} {
		lappend options "-sort" [string tolower $::plist::sort]
	}
	return $options
}
