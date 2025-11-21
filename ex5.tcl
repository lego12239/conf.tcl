#!/usr/bin/env tclsh
# very simple callback for the specific config

lappend auto_path [pwd]
package require conf

set conf {}

proc conf_cb {_conf _ctx op kname kval} {
	upvar #0 $_conf conf

	switch $kname {
	{listen ip} {
		if {![regexp {^\d{1,3}(\.\d{1,3}){3}$} $kval]} {
			error "conf error: listen.ip wrong value: $kval"
		}
	}
	{listen port} {
		if {![regexp {^\d{1,5}$} $kval]} {
			error "conf error: listen.port wrong value: $kval"
		}
	}
	debug {
		if {![string is boolean -strict $kval]} {
			error "conf error: debug wrong value: $kval"
		}
	}
	{syslog facility} -
	{syslog tag} {
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

conf::load_from_file -hd . {conf_cb conf} ex5.conf
# Here we need to set default values for keys that not defined.
puts $conf
