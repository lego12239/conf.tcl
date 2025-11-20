#!/usr/bin/env tclsh
# very simple callback that skip SECT_CH and FILE op and
# treat += and ?= op as = and in all these cases simply assign
# a value to a key.

lappend auto_path [pwd]
package require conf

set conf {}

proc conf_cb {_conf _ctx op kname kval} {
	upvar #0 $_conf conf

	if {($op ne "SECT_CH") && ($op ne "FILE")} {
		dict set conf {*}$kname $kval
	}
}

conf::load_from_file -hd . {conf_cb conf} ex2.conf
puts $conf
