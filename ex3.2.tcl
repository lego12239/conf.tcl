#!/usr/bin/env tclsh
# Convert all string values to list values. Compare to the output of ex3.1.tcl
# to see the difference.
# For example, if we don't want to check a value type after a parsing.
# This is bad, but who will judge us.

lappend auto_path [pwd]
package require conf

proc confcb {_ctx _conf op _names _val} {
	upvar $_ctx ctx
	upvar $_names names
	upvar $_val val
	if {$op eq "=S"} {
		set val [list $val]
		return "L"
	} elseif {$op eq "+=S"} {
		set val [list $val]
		return "L"
	} elseif {$op eq "?=S"} {
		set val [list $val]
		return "L"
	}
	return [string index $op end]
}
set ret [conf::load_from_file -hd . -cb confcb ex.conf]
puts "\nCONF:"
puts [lindex $ret 0]
