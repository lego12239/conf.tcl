#!/usr/bin/env tclsh
# +=S - append a string

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
				switch $spec_val {
				SECT {
					if {[dict get $spec $full_kname] ne $spec_val} {
						error "[join $kname .] key try to overwrite [string range $full_kname 1 end] ([dict get $spec $full_kname])"
					}
				}
				S {
					if {([dict get $spec $full_kname] eq "SECT") ||
					    ([dict get $spec $full_kname] ne [string index $op end])} {
						error "[join $kname .] key try to overwrite [string range $full_kname 1 end] ([dict get $spec $full_kname])"
					}
				}
				}
			} else {
				dict set spec $full_kname $spec_val
			}
		}
	}

	switch $op {
	=S {
		dict set conf {*}$kname $kval
	}
	?=S {
		if {![dict exists $conf {*}$kname]} {
			dict set conf {*}$kname $kval
		}
	}
	+=S {
		if {[dict exists $conf {*}$kname]} {
			set val [dict get $conf {*}$kname]
			append val $kval
		} else {
			set val $kval
		}
		dict set conf {*}$kname $val
	}
	=L {
		dict set conf {*}$kname $kval
		dict set spec $full_kname L
	}
	?=L {
		if {![dict exists $conf {*}$kname]} {
			dict set conf {*}$kname $kval
			dict set spec $full_kname L
		}
	}
	+=L {
		if {[dict exists $conf {*}$kname]} {
			set val [dict get $conf {*}$kname]
			lappend val $kval
		} else {
			set val $kval
		}
		dict set conf {*}$kname $val
	}
	SECT_CH {
	}
	F {
	}
	default {
		error "Unknown operation: $op"
	}
	}
}

proc get_key {kname} {
	if {![dict exists $::conf_spec ".$kname"]} {
		return {ERR "No such key"}
	}
	if {[dict get $::conf_spec ".$kname"] eq "SECT"} {
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
