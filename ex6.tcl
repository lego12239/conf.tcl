#!/usr/bin/env tclsh
# very simple callback for the specific config

lappend auto_path [pwd]
package require conf

set conf {}

proc conf_cb {_conf _ctx op kname kval} {
	upvar #0 $_conf conf

	conf::kname_switch $kname {
	{users #uname home} {
		if {$uname eq ""} {
			error "user name should not be empty"
		}
	}
	default {
		if {($op eq "SECT_CH") || ($op eq "FILE")} {
			return
		}
		error "conf error: unknown key: [join $kname .]"
	}
	}

	dict set conf {*}$kname $kval
}

conf::load_from_file -hd . {conf_cb conf} ex6.conf
# Here we need to set default values for keys that not defined.
puts $conf
