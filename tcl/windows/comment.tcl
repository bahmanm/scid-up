############################################################
### Comment Editor window
# Copyright (C) 2016 Fulvio Benini
#
# This file is part of Scid (Shane's Chess Information Database).
# Scid is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.

namespace eval ::windows::commenteditor {
	variable isOpen 0
	variable w_ .commentWin
	variable needNotify_ 0
	variable undoComment_ 1
	variable undoNAGs_ 1

	################################################################################
	# ::windows::commenteditor::clearComment_
	# Visibility:
	#   Private.
	# Inputs:
	#   - None.
	# Returns:
	#   - None.
	# Side effects:
	#   - When a comment exists, calls `undoFeature save` and clears the current
	#     position comment via `sc_pos setComment ""`.
	#   - Sets `::windows::commenteditor::needNotify_` when a change is made.
	#   - Schedules a `::notify::PosChanged pgnonly` notification.
	################################################################################
	proc clearComment_ {} {
		if {[sc_pos getComment] != ""} {
			undoFeature save
			sc_pos setComment ""
			set ::windows::commenteditor::needNotify_ 1
		}
		notify_ idle
	}


	################################################################################
	# ::windows::commenteditor::clearNAGs_
	# Visibility:
	#   Private.
	# Inputs:
	#   - None.
	# Returns:
	#   - None.
	# Side effects:
	#   - When NAGs exist, calls `undoFeature save` and clears them via
	#     `sc_pos clearNags`.
	#   - Sets `::windows::commenteditor::needNotify_` when a change is made.
	#   - Schedules a `::notify::PosChanged pgnonly` notification.
	################################################################################
	proc clearNAGs_ {} {
		if {[sc_pos getNags] != 0} {
			undoFeature save
			sc_pos clearNags
			set ::windows::commenteditor::needNotify_ 1
		}
		notify_ idle
	}


	################################################################################
	# ::windows::commenteditor::notify_
	#   Schedules a position-changed notification if the editor has made changes.
	# Visibility:
	#   Private.
	# Inputs:
	#   - wait: Delay passed to `after` (e.g. "idle", or a millisecond count).
	# Returns:
	#   - None.
	# Side effects:
	#   - Cancels and re-schedules `::notify::PosChanged pgnonly`.
	################################################################################
	proc notify_ {wait} {
		if {$::windows::commenteditor::needNotify_} {
			after cancel "::notify::PosChanged pgnonly"
			after $wait "::notify::PosChanged pgnonly"
		}
	}


	################################################################################
	# ::windows::commenteditor::notifyCancel_
	# Visibility:
	#   Private.
	# Inputs:
	#   - None.
	# Returns:
	#   - None.
	# Side effects:
	#   - Cancels any pending `::notify::PosChanged pgnonly`.
	################################################################################
	proc notifyCancel_ {} {
		after cancel "::notify::PosChanged pgnonly"
	}


	################################################################################
	# ::windows::commenteditor::storeComment_
	#   Persists the edited comment to the current position.
	# Visibility:
	#   Private.
	# Inputs:
	#   - None.
	# Returns:
	#   - None.
	# Side effects:
	#   - Reads from `$w_.cf.txtframe.text`.
	#   - When the comment has changed, calls `undoFeature save` at most once per
	#     refresh cycle (guarded by `::windows::commenteditor::undoComment_`).
	#   - Updates the current position comment via `sc_pos setComment`.
	#   - Sets `::windows::commenteditor::needNotify_` when a change is made.
	#   - Schedules a delayed `::notify::PosChanged pgnonly`.
	#   - Resets the text widget's modified flag.
	################################################################################
	proc storeComment_ {} {
		variable w_
		if {![$w_.cf.txtframe.text edit modified]} { return }

		# The "end-1c" below is because Tk adds a newline to text contents:
		set oldComment [sc_pos getComment]
		set newComment [$w_.cf.txtframe.text get 1.0 end-1c]
		if {"$oldComment" ne "$newComment"} {
			variable undoComment_
			if { $undoComment_ } {
				set undoComment_ 0
				undoFeature save
			}
			sc_pos setComment $newComment
			set ::windows::commenteditor::needNotify_ 1
		}
		notify_ 1500
		$w_.cf.txtframe.text edit modified false
	}


	################################################################################
	# ::windows::commenteditor::storeNAGs_
	#   Persists the edited NAG list to the current position.
	# Visibility:
	#   Private.
	# Inputs:
	#   - None.
	# Returns:
	#   - None.
	# Side effects:
	#   - Reads NAGs from `$w_.nf.text`.
	#   - When NAGs have changed, calls `undoFeature save` at most once per refresh
	#     cycle (guarded by `::windows::commenteditor::undoNAGs_`).
	#   - Updates the current position NAGs via `sc_pos clearNags` / `sc_pos addNag`.
	#   - Sets `::windows::commenteditor::needNotify_` when a change is made.
	#   - Schedules a delayed `::notify::PosChanged pgnonly`.
	################################################################################
	proc storeNAGs_ {} {
		variable w_
		set nag_stored [sc_pos getNags]
		set nag_text [$w_.nf.text get]
		#sc_pos getNags returns 0 when empty
		if {$nag_text == ""} { set nag_text 0 }
		if {"$nag_text" ne "$nag_stored"} {
			variable undoNAGs_
			if { $undoNAGs_ } {
				set undoNAGs_ 0
				undoFeature save
			}
			sc_pos clearNags
			foreach {nag} [split "$nag_text" " "] {
				sc_pos addNag $nag
			}
			set ::windows::commenteditor::needNotify_ 1
		}
		notify_ 1500
	}
}

################################################################################
# ::windows::commenteditor::createWin
#   Creates (or focuses) the comment editor window.
# Visibility:
#   Public.
# Inputs:
#   - focus_if_exists: When the window already exists, a non-zero value focuses
#     it; a zero value closes it. (When the window does not exist, it is created
#     regardless of this flag.)
# Returns:
#   - None.
# Side effects:
#   - Creates `.commentWin` and its child widgets when not already open.
#   - Calls `::windows::commenteditor::Refresh` to load the current comment and
#     NAGs.
#   - Sets up bindings and schedules focus on the comment text widget.
################################################################################
proc ::windows::commenteditor::createWin { {focus_if_exists 1} } {
	variable w_

	if {! [::win::createWindow $w_ [tr {WindowsComment}] 530x220]} {
		if { $focus_if_exists } {
			::win::makeVisible $w_
			focus $w_.cf.txtframe.text
		} else {
			::win::closeWindow $w_
		}
		return
	}

	# NAGs frame:
	ttk::frame $w_.nf
	ttk::label $w_.nf.label -font font_Bold -text [tr AnnotationSymbols]
	ttk::button $w_.nf.clear -text [tr Clear] -command "::windows::commenteditor::clearNAGs_"
	ttk::entry $w_.nf.text
	ttk::frame $w_.nf.b
	set i 0
	foreach {nag description} {
		!! ExcellentMove
		! GoodMove
		!? InterestingMove
		?! DubiousMove
		? PoorMove
		?? Blunder
		N Novelty
		+-- WhiteCrushing
		+- WhiteDecisiveAdvantage
		+/- WhiteClearAdvantage
		+= WhiteSlightAdvantage
		= Equality
		D Diagram
		--+ BlackCrushing
		-+ BlackDecisiveAdvantage
		-/+ BlackClearAdvantage
		=+ BlackSlightAdvantage
		~ Unclear
	} {
		ttk::button $w_.nf.b.b$i -text "$nag" -width 3 -command "::addNag $nag"
		::utils::tooltip::Set $w_.nf.b.b$i [tr $description]
		grid $w_.nf.b.b$i -column [expr {$i % 6}] -row [expr {int($i / 6)}] -padx 1 -pady 1
		incr i
	}
	grid columnconfig $w_.nf 0 -weight 1
	grid $w_.nf.label $w_.nf.clear -sticky nsew
	grid $w_.nf.text -sticky nsew -columnspan 2
	grid $w_.nf.b -sticky nsew -columnspan 2

	# Comment frame:
	ttk::frame $w_.cf
	ttk::label $w_.cf.label -font font_Bold -text [tr Comment]
	ttk::button $w_.cf.clear -text [tr Clear] -command "::windows::commenteditor::clearComment_"
	autoscrollText y $w_.cf.txtframe $w_.cf.txtframe.text Treeview
	$w_.cf.txtframe.text configure -wrap word -state normal
	grid rowconfig $w_.cf 1 -weight 1
	grid columnconfig $w_.cf 0 -weight 1
	grid $w_.cf.label $w_.cf.clear -sticky nsew
	grid $w_.cf.txtframe -sticky nsew -columnspan 2


	# Arrange frames:
	grid $w_.cf -row 0 -column 0 -columnspan 2 -sticky nsew
	grid $w_.nf -row 1 -column 0 -columnspan 2 -sticky nsew
	grid rowconfig $w_ 0 -weight 1
	grid columnconfig $w_ 0 -weight 1

	# Load current NAGs and comment
	Refresh

	# Add bindings at the end
	bind $w_ <Destroy> "if {\[string equal $w_ %W\]} { set ::windows::commenteditor::isOpen 0; ::windows::commenteditor::notify_ 1 }"
	bind $w_.nf.text <KeyPress>   "::windows::commenteditor::notifyCancel_"
	bind $w_.nf.text <KeyRelease> "::windows::commenteditor::storeNAGs_"
	bind $w_.cf.txtframe.text <KeyPress>   "::windows::commenteditor::notifyCancel_"
	bind $w_.cf.txtframe.text <KeyRelease> "::windows::commenteditor::notify_ 1000"
	bind $w_.cf.txtframe.text <<Modified>> "::windows::commenteditor::storeComment_"

	set ::windows::commenteditor::isOpen 1
	$w_.cf.txtframe.text edit modified false
	after idle focus $w_.cf.txtframe.text
}

################################################################################
# ::windows::commenteditor::Refresh
#   Updates the comment and NAG widgets for the current position.
# Visibility:
#   Public.
# Inputs:
#   - None.
# Returns:
#   - None.
# Side effects:
#   - When the window is open, reads the current comment and NAGs via `sc_pos`
#     and updates the corresponding widgets.
#   - Cancels any pending `::notify::PosChanged pgnonly`.
#   - Resets `::windows::commenteditor::needNotify_`, `undoNAGs_`, and
#     `undoComment_`.
#   - Disables NAG controls when at `vstart` (NAGs cannot be inserted before
#     moves).
################################################################################
proc ::windows::commenteditor::Refresh {} {
	variable w_
	if {![winfo exists $w_]} { return }

	::windows::commenteditor::notifyCancel_
	variable needNotify_ 0
	variable undoNAGs_ 1
	variable undoComment_ 1

	set comment [sc_pos getComment]
	if {$comment != [$w_.cf.txtframe.text get 1.0 end-1c]} {
		$w_.cf.txtframe.text delete 1.0 end
		$w_.cf.txtframe.text insert end $comment
	}
	$w_.cf.txtframe.text edit modified false

	set nag [sc_pos getNags]
	$w_.nf.text configure -state normal
	$w_.nf.text delete 0 end
	if {$nag != "0"} {
		$w_.nf.text insert end $nag
	}
	# if at vstart, disable NAG codes
	if {[sc_pos isAt vstart]} {
		set state "disabled"
	} else	{
		set state "normal"
	}
	$w_.nf.clear configure -state $state
	$w_.nf.text configure -state $state
	foreach c [winfo children $w_.nf.b] {
		$c configure -state $state
	}
}

################################################################################
# makeCommentWin
#   Convenience entry point for opening the comment editor window.
# Visibility:
#   Public.
# Inputs:
#   - toggle: When equal to "toggle", closes the window if it is already open.
#     Otherwise, focuses the existing window.
# Returns:
#   - None.
# Side effects:
#   - Delegates to `::windows::commenteditor::createWin`.
################################################################################
proc makeCommentWin {{toggle ""}} {
	::windows::commenteditor::createWin [string compare "$toggle" "toggle"]
}
