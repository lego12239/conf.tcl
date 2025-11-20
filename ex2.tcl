#!/usr/bin/env tclsh
# Conf spec mismatch to conf spec pattern.
# Example of outputing of comparison results.

lappend auto_path [pwd]
package require conf

set conf {}

proc conf_cb {_conf _ctx op kname kval} {
	upvar #0 $_conf conf

	if {($op ne "SECT_CH") && ($op ne "FILE")} {
		dict set conf {*}$kname $kval
	}
}

#conf::load_from_file -hd . {conf_cb conf} ex2.conf
conf::load_from_file -hd . {conf_cb conf} m.conf
puts $conf
