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

	proc clearComment_ {} {
		if {[sc_pos getComment] != ""} {
			undoFeature save
			sc_pos setComment ""
			set ::windows::commenteditor::needNotify_ 1
		}
		notify_ idle
	}

	proc clearNAGs_ {} {
		if {[sc_pos getNags] != 0} {
			undoFeature save
			sc_pos clearNags
			set ::windows::commenteditor::needNotify_ 1
		}
		notify_ idle
	}

	proc notify_ {wait} {
		if {$::windows::commenteditor::needNotify_} {
			after cancel "::notify::PosChanged pgnonly"
			after $wait "::notify::PosChanged pgnonly"
		}
	}

	proc notifyCancel_ {} {
		after cancel "::notify::PosChanged pgnonly"
	}

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
	ttk::button $w_.nf.clear -text [tr Clear] -command [list ::windows::commenteditor::clearNAGs_]
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
		ttk::button $w_.nf.b.b$i -text "$nag" -width 3 -command [list ::addNag $nag]
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
	ttk::button $w_.cf.clear -text [tr Clear] -command [list ::windows::commenteditor::clearComment_]
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
		bind $w_ <Destroy> [list apply {{w} {
			if {[string equal $w %W]} {
				set ::windows::commenteditor::isOpen 0
				::windows::commenteditor::notify_ 1
			}
		} ::} $w_]
		bind $w_.nf.text <KeyPress>   [list ::windows::commenteditor::notifyCancel_]
		bind $w_.nf.text <KeyRelease> [list ::windows::commenteditor::storeNAGs_]
		bind $w_.cf.txtframe.text <KeyPress>   [list ::windows::commenteditor::notifyCancel_]
		bind $w_.cf.txtframe.text <KeyRelease> [list ::windows::commenteditor::notify_ 1000]
	bind $w_.cf.txtframe.text <<Modified>> [list ::windows::commenteditor::storeComment_]

	set ::windows::commenteditor::isOpen 1
	$w_.cf.txtframe.text edit modified false
	after idle focus $w_.cf.txtframe.text
}

# Gets the comment and NAGs for the current position and updates the
# corresponding widgets.
# Disables NAGs widgets if at vstart (NAGs cannot be inserted before moves).
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

proc makeCommentWin {{toggle ""}} {
	::windows::commenteditor::createWin [string compare "$toggle" "toggle"]
}
