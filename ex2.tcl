#!/usr/bin/env tclsh
# Conf spec mismatch to conf spec pattern.
# Example of outputing of comparison results.

lappend auto_path [pwd]
package require conf

set cspec_pat {key1 S sect1 {sect2 {key1 c key2 S}} sect3 A}
set cas [conf::load_from_file -hd . ex.conf]
set res [conf::spec_cmp $cspec_pat [lindex $cas 1]]
if {[llength $res] > 0} {
	foreach mentry $res {
		switch -exact [lindex $mentry 0] {
		"M" {
			puts "missed: \"[lindex $mentry 1]\""
		}
		"T" {
			set wtype [conf::spec_key_get $cspec_pat [lindex $mentry 1]]
			set type [conf::spec_key_get [lindex $cas 1] [lindex $mentry 1]]
			puts "wrong type: \"[lindex $mentry 1]\": $type instead of $wtype"
		}
		"E" {
			puts "excess: \"[lindex $mentry 1]\""
		}
		}
	}
	exit 1
}
# We should not reach this line
puts [dict get [lindex $cas 0] sect1 sect2 key1]
