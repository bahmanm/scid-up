###################
# htext.tcl: Online help/hypertext display module for Scid
#
# The htext module implements html-like display in a text widget.
# It is used in Scid for the help and crosstable windows, and for
# the game information area.

namespace eval ::htext {}

set helpWin(Stack) {}
set helpWin(yStack) {}
set helpWin(Indent) 0

################################################################################
# help_PushStack
#   Pushes a help page name onto the back-stack.
# Visibility:
#   Private.
# Inputs:
#   - name: Help page identifier (key into `helpText` / `helpTitle`).
#   - heading: Optional section heading to navigate to (currently unused here; the
#     caller passes it to `updateHelpWindow`).
# Returns:
#   - None.
# Side effects:
#   - Appends to `helpWin(Stack)` and prunes it to a maximum of 10 entries.
#   - When `.helpWin` exists, captures the current scroll position from
#     `.helpWin.text yview` into `helpWin(yStack)` (also pruned to 10).
################################################################################
proc help_PushStack {name {heading ""}} {
  global helpWin
  lappend helpWin(Stack) $name
  if {[llength $helpWin(Stack)] > 10} {
    set helpWin(Stack) [lrange $helpWin(Stack) 1 end]
  }
  if {[winfo exists .helpWin]} {
    set helpWin(yStack) [linsert $helpWin(yStack) 0 \
        [lindex [.helpWin.text yview] 0]]
    if {[llength $helpWin(yStack)] > 10} {
      set helpWin(yStack) [lrange $helpWin(yStack) 0 9]
    }
  }
}

set ::htext::headingColor "\#990000"
array set ::htext:updates {}

################################################################################
# help_PopStack
#   Pops the most recent help page from the back-stack and displays the previous
#   page.
# Visibility:
#   Private.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - Mutates `helpWin(Stack)` and `helpWin(yStack)`.
#   - Calls `updateHelpWindow` to redraw the help content.
#   - Moves the help text widget's yview via `.helpWin.text yview moveto ...`.
# Preconditions:
#   - Expects `.helpWin.text` to exist when the stack is non-empty.
################################################################################
proc help_PopStack {} {
  global helpWin helpText
  set len [llength $helpWin(Stack)]
  if {$len < 1} { return }
  incr len -2
  set name [lindex $helpWin(Stack) $len]
  set helpWin(Stack) [lrange $helpWin(Stack) 0 $len]
  
  set ylen [llength $helpWin(yStack)]
  set yview 0.0
  if {$ylen >= 1} {
    set yview [lindex $helpWin(yStack) 0]
    set helpWin(yStack) [lrange $helpWin(yStack) 1 end]
  }
  updateHelpWindow $name
  .helpWin.text yview moveto $yview
}

################################################################################
# helpWindowPertinent
#   Opens the help window and attempts to select a page relevant to the provided
#   widget path.
# Visibility:
#   Public.
# Inputs:
#   - win: Widget path (typically the currently focused widget).
# Returns:
#   - None.
# Side effects:
#   - May open or update the help window via `helpWindow`.
#   - Reads from `::helpTitle` to find available help page titles.
################################################################################
proc helpWindowPertinent {win} {
  set availTitles [array names ::helpTitle]
  regexp {[.]\w*} $win topWin

  # Look for a toplevel page (i.e. ".treeWin1" -> "tree")
  if { [regexp {[.](\w*?)Win\d*$} $topWin -> topTitle] } {
    set title [lsearch -inline -nocase $availTitles $topTitle]
    if {$title != ""} {
      return [helpWindow $title]
    }
  }

  # Default
  return [helpWindow "Contents"]
}

################################################################################
# helpWindow
#   Pushes the given help page onto the back-stack and renders it.
# Visibility:
#   Public.
# Inputs:
#   - name: Help page identifier.
#   - heading: Optional section heading to navigate to.
# Returns:
#   - None.
# Side effects:
#   - Mutates the help back-stack via `help_PushStack`.
#   - Updates the help window via `updateHelpWindow`.
################################################################################
proc helpWindow {name {heading ""}} {
  help_PushStack $name
  updateHelpWindow $name $heading
}

################################################################################
# updateHelpWindow
#   Creates (if necessary) and updates the help window content for a help page.
# Visibility:
#   Private.
# Inputs:
#   - name: Help page identifier.
#   - heading: Optional section heading to navigate to.
# Returns:
#   - None.
# Side effects:
#   - Creates and configures the `.helpWin` toplevel and its child widgets.
#   - Configures bindings for navigation keys.
#   - Renders formatted help content into `.helpWin.text` via `::htext::display`.
################################################################################
proc updateHelpWindow {name {heading ""}} {
  global helpWin helpText helpTitle windowsOS language
  set w .helpWin
  
  set slist [split $name " "]
  if {[llength $slist] > 1} {
    set name [lindex $slist 0]
    set heading [lindex $slist 1]
  }
  
  if {[info exists helpText($language,$name)] && [info exists helpTitle($language,$name)]} {
    set title $helpTitle($language,$name)
    set helptext $helpText($language,$name)
  } elseif {[info exists helpText($name)] && [info exists helpTitle($name)]} {
    set title $helpTitle($name)
    set helptext $helpText($name)
  } else {
    return
  }
  
  if {![winfo exists $w]} {
    toplevel $w
    # wm geometry $w -10+0
    setWinLocation $w
    setWinSize $w
    
    wm minsize $w 20 5
    text $w.text -setgrid yes -wrap word -width $::winWidth($w) -height $::winHeight($w) -relief sunken -border 0 -yscroll [list $w.scroll set]
    ttk::scrollbar $w.scroll -command [list $w.text yview]
    
    ttk::frame $w.b -relief raised -border 2
    pack $w.b -side bottom -fill x
    ttk::button $w.b.contents -textvar ::tr(Contents) -command { helpWindow Contents }
    ttk::button $w.b.index -textvar ::tr(Index) -command { helpWindow Index }
    ttk::button $w.b.back -textvar ::tr(Back) -command { help_PopStack }
    ttk::button $w.b.close -textvar ::tr(Close) -command {
      set ::helpWin(Stack) {}
      set ::helpWin(yStack) {}
      destroy .helpWin
    }
    
    pack $w.b.contents $w.b.index $w.b.back -side left -padx 1 -pady 2
    pack $w.b.close -side right -padx 5 -pady 2
    pack $w.scroll -side right -fill y -padx 2 -pady 2
    pack $w.text -fill both -expand 1 -padx 1
    
	    $w.text configure -font font_Regular -foreground black -background white
	    ::htext::init $w.text
	    bind $w <Configure> [list recordWinSize $w]
	  }
  
  $w.text configure -cursor top_left_arrow
  $w.text configure -state normal
  $w.text delete 0.0 end
  
  $w.b.index configure -state normal
  if {$name == "Index"} { $w.b.index configure -state disabled }
  $w.b.contents configure -state normal
  if {$name == "Contents"} { $w.b.contents configure -state disabled }
  $w.b.back configure -state disabled
  if {[llength $helpWin(Stack)] >= 2} {
    $w.b.back configure -state normal
  }
  
  wm title $w "[tr ScidUp] Help: $title"
  wm iconname $w "[tr ScidUp] help"
  
  $w.text delete 0.0 end
	  bind $w <Up> [list ${w}.text yview scroll -1 units]
	  bind $w <Down> [list ${w}.text yview scroll 1 units]
	  bind $w <Prior> [list ${w}.text yview scroll -1 pages]
	  bind $w <Next> [list ${w}.text yview scroll 1 pages]
	  bind $w <Key-Home> [list ${w}.text yview moveto 0]
	  bind $w <Key-End> [list ${w}.text yview moveto 0.99]
	  bind $w <Escape> [list ${w}.b.close invoke]
	  bind $w <Key-b> [list ${w}.b.back invoke]
	  bind $w <Left> [list ${w}.b.back invoke]
	  bind $w <Key-i> [list ${w}.b.index invoke]
  
  ::htext::display $w.text $helptext $heading 0
  focus $w
}

################################################################################
# ::htext::updateRate
#   Sets the update frequency (in tags-per-cycle) for incremental rendering.
# Visibility:
#   Public.
# Inputs:
#   - w: Text widget path.
#   - rate: Integer number of processed tags between `update idletasks` calls.
# Returns:
#   - None.
# Side effects:
#   - Updates `::htext::updates($w)`.
################################################################################
proc ::htext::updateRate {w rate} {
  set ::htext::updates($w) $rate
}

################################################################################
# ::htext::init
#   Initialises a text widget for use with `::htext::display` by configuring the
#   expected tags.
# Visibility:
#   Public.
# Inputs:
#   - w: Text widget path.
# Returns:
#   - None.
# Side effects:
#   - Sets `::htext::updates($w)` to a default of 100.
#   - Configures a large set of text tags (colours, margins, headings, PGN tags).
#   - Reads `::pgnColor(Var)` and `::pgnColor(Nag)` to configure PGN colouring.
################################################################################
proc ::htext::init {w} {
  set cyan "\#007000"
  set maroon "\#990000"
  set green "green"
  
  set ::htext::updates($w) 100
  $w tag configure black -foreground black
  $w tag configure white -foreground white
  $w tag configure red -foreground red
  $w tag configure blue -foreground RoyalBlue3
  $w tag configure darkblue -foreground DodgerBlue3
  $w tag configure green -foreground $green
  $w tag configure cyan -foreground $cyan
  $w tag configure yellow -foreground yellow
  $w tag configure maroon -foreground $maroon
  $w tag configure gray -foreground gray20
  
  $w tag configure bgBlack -background black
  $w tag configure bgWhite -background white
  $w tag configure bgRed -background red
  $w tag configure bgBlue -background blue
  $w tag configure bgLightBlue -background lightBlue
  $w tag configure bgGreen -background $green
  $w tag configure bgCyan -background $cyan
  $w tag configure bgYellow -background yellow
  
  $w tag configure tab -lmargin2 50
  $w tag configure li -lmargin2 50
  $w tag configure center -justify center
  
  if {[$w cget -font] == "font_Small"} {
    $w tag configure b -font font_SmallBold
    $w tag configure i -font font_SmallItalic
  } else {
    $w tag configure b -font font_Bold
    $w tag configure i -font font_Italic
  }
  $w tag configure bi -font font_BoldItalic
  $w tag configure tt -font font_Fixed
  $w tag configure u -underline 1
  $w tag configure h1 -font font_H1 -foreground $::htext::headingColor \
      -justify center
  $w tag configure h2 -font font_H2 -foreground $::htext::headingColor
  $w tag configure h3 -font font_H3 -foreground $::htext::headingColor
  $w tag configure h4 -font font_H4 -foreground $::htext::headingColor
  $w tag configure h5 -font font_H5 -foreground $::htext::headingColor
  $w tag configure footer -font font_Small -justify center
  
  $w tag configure term -font font_BoldItalic -foreground $::htext::headingColor
  $w tag configure menu -font font_Bold -foreground $cyan
  
  # PGN-window-specific tags:
  $w tag configure var -font font_Regular
  $w tag configure nag -font font_Regular
  if { $::pgnColor(Var) ne "" } {
    $w tag configure var -foreground $::pgnColor(Var)
  }
  $w tag configure nag -foreground $::pgnColor(Nag)

  set lmargin 0
  for {set i 1} {$i <= 19} {incr i} {
    incr lmargin 25
    $w tag configure "ip$i" -lmargin1 $lmargin -lmargin2 $lmargin
  }
}

################################################################################
# ::htext::isStartTag
# Visibility:
#   Private.
# Inputs:
#   - tagName: Tag name string without angle brackets.
# Returns:
#   - Boolean: 1 when the tag is a start tag; 0 when it is an end tag.
# Side effects:
#   - None.
################################################################################
proc ::htext::isStartTag {tagName} {
  return [expr {![strIsPrefix "/" $tagName]} ]
}

################################################################################
# ::htext::isEndTag
# Visibility:
#   Private.
# Inputs:
#   - tagName: Tag name string without angle brackets.
# Returns:
#   - Boolean: 1 when the tag is an end tag; 0 otherwise.
# Side effects:
#   - None.
################################################################################
proc ::htext::isEndTag {tagName} {
  return [strIsPrefix "/" $tagName]
}

################################################################################
# ::htext::isLinkTag
# Visibility:
#   Private.
# Inputs:
#   - tagName: Tag name string without angle brackets.
# Returns:
#   - Boolean: 1 when the tag is a help link tag (`a ...`); 0 otherwise.
# Side effects:
#   - None.
################################################################################
proc ::htext::isLinkTag {tagName} {
  return [strIsPrefix "a " $tagName]
}

################################################################################
# ::htext::extractLinkName
# Visibility:
#   Private.
# Inputs:
#   - tagName: Tag name string without angle brackets.
# Returns:
#   - The help page name for an `a ...` link tag.
#   - Empty string when the tag is not a link tag.
# Side effects:
#   - None.
################################################################################
proc ::htext::extractLinkName {tagName} {
  if {[::htext::isLinkTag $tagName]} {
    return [lindex [split [string range $tagName 2 end] " "] 0]
  }
  return ""
}

################################################################################
# ::htext::extractSectionName
# Visibility:
#   Private.
# Inputs:
#   - tagName: Tag name string without angle brackets.
# Returns:
#   - The section token for an `a ...` link tag (the second whitespace-delimited
#     token after the page name).
#   - Empty string when the tag is not a link tag or no section token is present.
# Side effects:
#   - None.
################################################################################
proc ::htext::extractSectionName {tagName} {
  if {[::htext::isLinkTag $tagName]} {
    return [lindex [split [string range $tagName 2 end] " "] 1]
  }
  return ""
}

set ::htext::interrupt 0

################################################################################
# ::htext::display
#   Renders a small HTML-like markup language into a Tk text widget.
# Visibility:
#   Public.
# Inputs:
#   - w: Text widget path.
#   - helptext: String containing markup (e.g. <b>, <a ...>, <img ...>, <p>).
#   - section: Optional anchor name to scroll to (used by <a ...> links and
#     matched against `<name ...>` tags).
#   - fixed: Boolean. When true, normalises newlines to support simple paragraph
#     formatting.
# Returns:
#   - None.
# Side effects:
#   - Mutates the text widget contents and tag state.
#   - Creates embedded widgets for <img>, <button>, and <window> tags.
#   - Adds tag bindings for links and actions (help links, URLs, Tcl commands).
#   - May call `update idletasks` during long renders.
#   - May return early when `::htext::interrupt` is set.
################################################################################
proc ::htext::display {w helptext {section ""} {fixed 1}} {
  global helpWin
  # set start [clock clicks -milli]
  set helpWin(Indent) 0
  set ::htext::interrupt 0
  $w mark set insert 0.0
  $w configure -state normal
  set linkName ""
  
  set count 0
  set str $helptext
  if {$fixed} {
    regsub -all "\n\n" $str "<p>" str
    regsub -all "\n" $str " " str
  } else {
    regsub -all "\[ \n\]+" $str " " str
    regsub -all ">\[ \n\]+" $str "> " str
    regsub -all "\[ \n\]+<" $str " <" str
  }
  set tagType ""
  set seePoint ""
  
  if {! [info exists ::htext::updates($w)]} {
    set ::htext::updates($w) 100
  }
  
  # Loop through the text finding the next formatting tag:
  
  while {1} {
    set startPos [string first "<" $str]
    if {$startPos < 0} { break }
    set endPos [string first ">" $str]
    if {$endPos < 1} { break }
    
    set tagName [string range $str [expr {$startPos + 1}] [expr {$endPos - 1}]]
    
    # Check if it is a starting tag (no "/" at the start):
    
    if {![strIsPrefix "/" $tagName]} {
      
      # Check if it is a link tag:
      if {[strIsPrefix "a " $tagName]} {
        set linkName [::htext::extractLinkName $tagName]
        set sectionName [::htext::extractSectionName $tagName]
        set linkTag "link ${linkName} ${sectionName}"
        set tagName "a"
        $w tag configure $linkTag -foreground blue -underline 1
        $w tag bind $linkTag <ButtonRelease-1> [list helpWindow $linkName $sectionName]
        $w tag bind $linkTag <Any-Enter> [list apply {{w tag} {
            $w tag configure $tag -background yellow
            $w configure -cursor hand2
        } ::} $w $linkTag]
        $w tag bind $linkTag <Any-Leave> [list apply {{w tag} {
            $w tag configure $tag -background {}
            $w configure -cursor {}
        } ::} $w $linkTag]
      } elseif {[strIsPrefix "url " $tagName]} {
        # Check if it is a URL tag:
        set urlName [string range $tagName 4 end]
        set urlTag "url $urlName"
        set tagName "url"
        $w tag configure $urlTag -foreground red -underline 1
        $w tag bind $urlTag <ButtonRelease-1> [list openURL $urlName]
        $w tag bind $urlTag <Any-Enter> [list apply {{w tag} {
            $w tag configure $tag -background yellow
            $w configure -cursor hand2
        } ::} $w $urlTag]
        $w tag bind $urlTag <Any-Leave> [list apply {{w tag} {
            $w tag configure $tag -background {}
            $w configure -cursor {}
        } ::} $w $urlTag]
      } elseif {[strIsPrefix "run " $tagName]} {
        # Check if it is a Tcl command tag:
        set runName [string range $tagName 4 end]
        set runTag "run $runName"
        set tagName "run"
        $w tag bind $runTag <ButtonRelease-1> [list catch $runName]
        $w tag bind $runTag <Any-Enter> [list apply {{w tag} {
            $w tag configure $tag -foreground white
            $w tag configure $tag -background DodgerBlue4
            $w configure -cursor hand2
        } ::} $w $runTag]
        $w tag bind $runTag <Any-Leave> [list apply {{w tag} {
            $w tag configure $tag -foreground {}
            $w tag configure $tag -background {}
            $w configure -cursor {}
        } ::} $w $runTag]
      } elseif {[strIsPrefix "go " $tagName]} {
        # Check if it is a goto tag:
        set goName [string range $tagName 3 end]
        set goTag "go $goName"
        set tagName "go"
        $w tag bind $goTag <ButtonRelease-1> [list apply {{w goName} {
            set target [lindex [$w tag nextrange $goName 1.0] 0]
            if {$target ne ""} {
                catch {$w see $target}
            }
        } ::} $w $goName]
        $w tag bind $goTag <Any-Enter> [list apply {{w tag} {
            $w tag configure $tag -foreground yellow
            $w tag configure $tag -background maroon
            $w configure -cursor hand2
        } ::} $w $goTag]
        $w tag bind $goTag <Any-Leave> [list apply {{w tag} {
            $w tag configure $tag -foreground {}
            $w tag configure $tag -background {}
            $w configure -cursor {}
        } ::} $w $goTag]
      } elseif {[strIsPrefix "pi " $tagName]} {
        # Check if it is a player info tag:
        set playerTag $tagName
        set playerName [string range $playerTag 3 end]
        set tagName "pi"
        $w tag configure $playerTag -foreground DodgerBlue3
        $w tag bind $playerTag <ButtonRelease-1> [list ::pinfo::playerInfo $playerName]
        $w tag bind $playerTag <Any-Enter> [list apply {{w tag} {
           $w tag configure $tag -foreground white
           $w tag configure $tag -background DodgerBlue4
           $w configure -cursor hand2
        } ::} $w $playerTag]
        $w tag bind $playerTag <Any-Leave> [list apply {{w tag} {
           $w tag configure $tag -foreground DodgerBlue3
           $w tag configure $tag -background {}
           $w configure -cursor {}
        } ::} $w $playerTag]
      } elseif {[strIsPrefix "g_" $tagName]} {
        # Check if it is a game-load tag:
        set gameTag $tagName
        set tagName "g"
        set gnum [string range $gameTag 2 end]
        set glCommand [list ::game::LoadMenu $w [sc_base current] $gnum %X %Y]
        $w tag bind $gameTag <ButtonPress-1> $glCommand
        $w tag bind $gameTag <ButtonPress-$::MB3> [list apply {{gnum} {
          ::gbrowser::new [sc_base current] $gnum
        } ::} $gnum]
        $w tag bind $gameTag <Any-Enter> [list apply {{w tag} {
          $w tag configure $tag -foreground white
          $w tag configure $tag -background DodgerBlue4
          $w configure -cursor hand2
        } ::} $w $gameTag]
        $w tag bind $gameTag <Any-Leave> [list apply {{w tag} {
          $w tag configure $tag -foreground {}
          $w tag configure $tag -background {}
          $w configure -cursor {}
        } ::} $w $gameTag]
      } elseif {[strIsPrefix "m_" $tagName]} {
        # Check if it is a move tag:
        set moveTag $tagName
        set tagName "m"
		  ### TODO
		  ### Does not work for variations as the var-Tag appears before
		  ### the <m_ tags, therefore this overwrites font sizes
        ### $w tag configure $moveTag -font font_Figurine_ML
        $w tag bind $moveTag <ButtonRelease-1> [list apply {{moveTag} {
            sc_move pgn [string range $moveTag 2 end]
            updateBoard
        } ::} $moveTag]
        # Bind middle button to popup a PGN board:
        $w tag bind $moveTag <ButtonPress-$::MB2> [list ::pgn::ShowBoard .pgnWin.text $moveTag %X %Y]
        $w tag bind $moveTag <ButtonRelease-$::MB2> [list ::pgn::HideBoard]
        # invoking contextual menu in PGN window
        $w tag bind $moveTag <ButtonPress-$::MB3> [list apply {{moveTag} {
            sc_move pgn [string range $moveTag 2 end]
            updateBoard
        } ::} $moveTag]
        $w tag bind $moveTag <Any-Enter> [list apply {{w tag} {
            $w tag configure $tag -underline 1
            $w configure -cursor hand2
        } ::} $w $moveTag]
        $w tag bind $moveTag <Any-Leave> [list apply {{w tag} {
            $w tag configure $tag -underline 0
            $w configure -cursor {}
        } ::} $w $moveTag]
      } elseif {[strIsPrefix "c_" $tagName]} {
        # Check if it is a comment tag:
        set commentTag $tagName
        set tagName "c"
        $w tag configure $commentTag -foreground $::pgnColor(Comment) -font font_Regular
        $w tag bind $commentTag <ButtonRelease-1> [list apply {{commentTag} {
            sc_move pgn [string range $commentTag 2 end]
            updateBoard
            ::makeCommentWin
        } ::} $commentTag]
        $w tag bind $commentTag <Any-Enter> [list apply {{w tag} {
            $w tag configure $tag -underline 1
            $w configure -cursor hand2
        } ::} $w $commentTag]
        $w tag bind $commentTag <Any-Leave> [list apply {{w tag} {
            $w tag configure $tag -underline 0
            $w configure -cursor {}
        } ::} $w $commentTag]
      }
      
      if {$tagName == "h1"} {$w insert end "\n"}
      
    }
    
    # Now insert the text up to the formatting tag:
    $w insert end [string range $str 0 [expr {$startPos - 1}]]
    
    # Check if it is a name tag matching the section we want:
    if {$section != ""  &&  [strIsPrefix "name " $tagName]} {
      set sect [string range $tagName 5 end]
      if {$section == $sect} { set seePoint [$w index insert] }
    }
    
    if {[string index $tagName 0] == "/"} {
      # Get rid of initial "/" character:
      set tagName [string range $tagName 1 end]
      switch -- $tagName {
        h1 - h2 - h3 - h4 - h5  {$w insert end "\n"}
      }
      if {$tagName == "p"} {$w insert end "\n"}
      #if {$tagName == "h1"} {$w insert end "\n"}
      if {$tagName == "menu"} {$w insert end "\]"}
      if {$tagName == "ul"} {
        incr helpWin(Indent) -4
        $w insert end "\n"
      }
      if {[info exists startIndex($tagName)]} {
        switch -- $tagName {
          a {$w tag add $linkTag $startIndex($tagName) [$w index insert]}
          g  {$w tag add $gameTag $startIndex($tagName) [$w index insert]}
          c  {$w tag add $commentTag $startIndex($tagName) [$w index insert]}
          m  {$w tag add $moveTag $startIndex($tagName) [$w index insert]}
          pi {$w tag add $playerTag $startIndex($tagName) [$w index insert]}
          url {$w tag add $urlTag $startIndex($tagName) [$w index insert]}
          run {$w tag add $runTag $startIndex($tagName) [$w index insert]}
          go {$w tag add $goTag $startIndex($tagName) [$w index insert]}
          default {$w tag add $tagName $startIndex($tagName) [$w index insert]}
        }
        unset startIndex($tagName)
      }
    } else {
      switch -- $tagName {
        ul {incr helpWin(Indent) 4}
        li {
          $w insert end "\n"
          for {set space 0} {$space < $helpWin(Indent)} {incr space} {
            $w insert end " "
          }
        }
        p  {$w insert end "\n"}
        br {$w insert end "\n"}
        q  {$w insert end "\""}
        lt {$w insert end "<"}
        gt {$w insert end ">"}
        h2 - h3 - h4 - h5  {$w insert end "\n"}
      }
      #Set the start index for this type of tag:
      set startIndex($tagName) [$w index insert]
      if {$tagName == "menu"} {$w insert end "\["}
    }
    
    # Check if it is an image or button tag:
    if {[strIsPrefix "img " $tagName]} {
      set imgName [string range $tagName 4 end]
      #flags are not loaded on start, so check if a flag needs to load
      if { $imgName ne [info commands $imgName] && [string range $imgName 0 3] eq "flag" } {
        set imgLen [string length $imgName]
        set imgName [getFlagImage [string range $imgName [expr {$imgLen - 3}] end] yes]
      }
      set winName $w.$imgName
      while {[winfo exists $winName]} { append winName a }
      ttk::label $winName -image $imgName -relief flat -borderwidth 0 -background white
      $w window create end -window $winName
    }
    if {[strIsPrefix "button " $tagName]} {
      set idx [ string first "-command" $tagName]
      set cmd ""
      if {$idx == -1} {
        set imgName [string range $tagName 7 end]
      } else  {
        set imgName [string trim [string range $tagName 7 [expr {$idx -1}]]]
        set cmd [ string range $tagName [expr {$idx +9}] end ]
      }
      set winName $w.$imgName
      while {[winfo exists $winName]} { append winName a }
      ttk::button $winName -image $imgName -command $cmd
      $w window create end -window $winName
    }
    if {[strIsPrefix "window " $tagName]} {
      set winName [string range $tagName 7 end]
      $w window create end -window $winName
    }
    
    # Now eliminate the processed text from the string:
    set str [string range $str [expr {$endPos + 1}] end]
    incr count
    if {$count == $::htext::updates($w)} { update idletasks; set count 1 }
    if {$::htext::interrupt} {
      $w configure -state disabled
      return
    }
  }
  
  # Now add any remaining text:
  if {! $::htext::interrupt} { $w insert end $str }
  
  if {$seePoint != ""} { $w yview $seePoint }
  $w configure -state disabled
  # set elapsed [expr {[clock clicks -milli] - $start}]
}


################################################################################
# openURL
#   Opens a URL in the user's web browser.
# Visibility:
#   Public.
# Inputs:
#   - url: URL string.
# Returns:
#   - None.
# Side effects:
#   - Executes OS commands to launch a browser (platform-dependent).
#   - Calls `busyCursor .` / `unbusyCursor .` during the attempt.
################################################################################
proc openURL {url} {
  global windowsOS
  busyCursor .
  if {$windowsOS} {
    # On Windows, use the "start" command:
    regsub -all " " $url "%20" url
    if {[string match $::tcl_platform(os) "Windows NT"]} {
      catch {exec $::env(COMSPEC) /c start $url &}
    } else {
      catch {exec start $url &}
    }
  } elseif {$::macOS} {
    # On Mac OS X use the "open" command:
    catch {exec open $url &}
  } else {
    # First, check if xdg-open works:
    if {! [catch {exec xdg-open $url &}] } {
	#lauch default browser seems ok, nothing more to do
    } elseif {[file executable [auto_execok firefox]]} {
      # Mozilla seems to be available:
      # First, try -remote mode:
      if {[catch {exec /bin/sh -c "$::auto_execs(firefox) -remote 'openURL($url)'"}]} {
        # Now try a new Mozilla process:
        catch {exec /bin/sh -c "$::auto_execs(firefox) '$url'" &}
      }
    } elseif {[file executable [auto_execok iceweasel]]} {
      # First, try -remote mode:
      if {[catch {exec /bin/sh -c "$::auto_execs(iceweasel) -remote 'openURL($url)'"}]} {
        # Now try a new Mozilla process:
        catch {exec /bin/sh -c "$::auto_execs(iceweasel) '$url'" &}
      }
    } elseif {[file executable [auto_execok mozilla]]} {
      # First, try -remote mode:
      if {[catch {exec /bin/sh -c "$::auto_execs(mozilla) -remote 'openURL($url)'"}]} {
        # Now try a new Mozilla process:
        catch {exec /bin/sh -c "$::auto_execs(mozilla) '$url'" &}
      }
    } elseif {[file executable [auto_execok www-browser]]} {
      # Now try a new Mozilla process:
      catch {exec /bin/sh -c "$::auto_execs(www-browser) '$url'" &}
    } elseif {[file executable [auto_execok netscape]]} {
      # OK, no Mozilla (poor user) so try Netscape (yuck):
      # First, try -remote mode to avoid starting a new netscape process:
      if {[catch {exec /bin/sh -c "$::auto_execs(netscape) -raise -remote 'openURL($url)'"}]} {
        # Now just try starting a new netscape process:
        catch {exec /bin/sh -c "$::auto_execs(netscape) '$url'" &}
      }
    } else {
      foreach executable {iexplorer opera lynx w3m links epiphan galeon
        konqueror mosaic amaya browsex elinks} {
        set executable [auto_execok $executable]
        if [string length $executable] {
          # Is there any need to give options to these browsers? how?
          set command [list $executable $url &]
          catch {exec /bin/sh -c "$executable '$url'" &}
          break
        }
      }
    }
  }
  unbusyCursor .
}
