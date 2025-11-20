#!/usr/bin/env tclsh

lappend auto_path [pwd]
package require conf

set conf {}
set conf_spec {}

proc conf_cb {_conf _spec _ctx op kname kval} {
	upvar #0 $_conf conf
	upvar #0 $_spec spec

	if {($op ne "SECT_CH") && ($op ne "FILE")} {
		set full_kname ""
		for {set i 0} {$i < [llength $kname]} {incr i} {
			set n [lindex $kname $i]
			append full_kname ".$n"
			if {$i == ([llength $kname] - 1)} {
				set spec_val "S"
			} else {
				set spec_val "SECT"
			}
			if {[dict exists $spec $full_kname]} {
				if {($spec_val eq "S") ||
				    ([dict get $spec $full_kname] ne $spec_val)} {
					error "[join $kname .] key try to overwrite [string range $full_kname 1 end] ([dict get $spec $full_kname])"
				}
			} else {
				dict set spec $full_kname $spec_val
			}
		}

		dict set conf {*}$kname $kval
	}
}

conf::load_from_file -hd . {conf_cb conf conf_spec} ex2.conf
puts $conf
#puts $conf_spec
