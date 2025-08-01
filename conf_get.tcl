#!/usr/bin/env tclsh

lappend auto_path [pwd]
package require conf

set conf {}
set conf_spec {}

proc conf_cb {_conf _spec _ctx op kname kval} {
	upvar #0 $_conf conf
	upvar #0 $_spec spec
	set kspec ""

	set full_kname [join $kname .]
	if {[dict exists $spec $full_kname]} {
		set kspec [dict get $spec $full_kname]
		set msg "Reassigning the "
		switch $kspec {
		S {
			append msg "key $full_kname from string '[dict get $conf {*}$kname]' "
		}
		L {
			append msg "key $full_kname from list '[dict get $conf {*}$kname]' "
		}
		SECT {
			append msg "sect $full_kname "
		}
		}
		switch $op {
		=S {
			append msg "to string '$kval'"
		}
		?=S -
		+=S {
			if {$kspec eq "SECT"} {
				append msg "to string '$kval'"
			} else {
				set msg ""
			}
		}
		=L {
			append msg "to list '$kval'"
		}
		?=L -
		+=L {
			if {$kspec eq "SECT"} {
				append msg "to list '$kval'"
			} else {
				set msg ""
			}
		}
		SECT {
			append msg "to sect"
		}
		}
		if {$msg ne ""} {
			puts stderr $msg
		}
	}

	switch $op {
	=S {
		dict set spec $full_kname S
		dict set conf {*}$kname $kval
	}
	?=S {
		if {($kspec eq "") || ($kspec eq "SECT")} {
			dict set spec $full_kname S
			dict set conf {*}$kname $kval
		}
	}
	+=S {
		if {($kspec eq "") || ($kspec eq "SECT")} {
			set val ""
			dict set spec $full_kname S
		} else {
			set val [dict get $conf {*}$kname]
			dict set spec $full_kname L
			lappend val $kval
		}
		dict set conf {*}$kname $val
	}
	=L {
		dict set spec $full_kname L
		dict set conf {*}$kname $kval
	}
	?=L {
		if {($kspec eq "") || ($kspec eq "SECT")} {
			dict set spec $full_kname L
			dict set conf {*}$kname $kval
		}
	}
	+=L {
		if {($kspec eq "") || ($kspec eq "SECT")} {
			set val ""
		} else {
			set val [dict get $conf {*}$kname]
		}
		dict set spec $full_kname L
		lappend val $kval
		dict set conf {*}$kname $val
	}
	SECT_CH {
		dict set spec $full_kname SECT
	}
	F {
	}
	default {
		error "Unknown operation: $op"
	}
	}
}

proc get_key {kname} {
	if {![dict exists $::conf_spec $kname]} {
		return {ERR "No such key"}
	}
	if {[dict get $::conf_spec $kname] eq "SECT"} {
		return {ERR "This is a section"}
	}
	set names [split $kname .]
	return [list OK [dict get $::conf {*}$names]]
}

# TODO: use getopt to get -hd value from command line
# TODO: add -h option
conf::load_from_file -hd . {conf_cb conf conf_spec} [lindex $argv 0]

if {[lindex $argv 1] ne ""} {
	set res [get_key [lindex $argv 1]]
	if {[lindex $res 0] eq "ERR"} {
		puts stderr [lindex $res 1]
		exit 1
	}
	puts [lindex $res 1]
	exit 0
}

while {[gets stdin line] >= 0} {
	set res [get_key $line]
	if {[lindex $res 0] eq "ERR"} {
		puts "ERR: [lindex $res 1]"
	} else {
		puts "OK: [lindex $res 1]"
	}
}
