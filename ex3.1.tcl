#!/usr/bin/env tclsh
# Callback demo.
# Uncomment a return line to see the result.

lappend auto_path [pwd]
package require conf

proc confcb {_ctx _conf op _names _vlist} {
	upvar $_ctx ctx
	upvar $_names names
	upvar $_vlist vlist
	dict lappend ctx priv [list $names $op $vlist]
#	return ""
	return [string index $op end]
}
set ret [conf::load_from_file -hd . -cb confcb ex.conf]
foreach entry [lindex $ret 2] {
	puts $entry
}
puts "\nCONF:"
puts [lindex $ret 0]
