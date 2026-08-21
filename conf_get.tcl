#!/usr/bin/env tclsh
# +=S - append a string

lappend auto_path [pwd]
package require conf

set conf {}
# conf name parts
set conf_np {}

proc conf_cb {_conf _ctx op kname kval} {
	upvar #0 $_conf conf

	# Check that we don't overwrite a some part of the config.
	if {$op ne "FILE"} {
		set kname_fingerprint [list]
		for {set i 0} {$i < [llength $kname]} {incr i} {
			# non-terminal part
			lappend kname_fingerprint N[lindex $kname $i]
			if {[dict exists $::conf_np [concat $kname_fingerprint T]]} {
				puts "WARNING: [join $kname .] key overwrite [join [lrange $kname 0 $i] .]."
			}
			if {$i != ([llength $kname] - 1)} {
				dict set ::conf_np $kname_fingerprint 1
			}
		}
		# Remove last non-terminal entry and add terminal one instead of it.
		if {$op eq "SECT_CH"} {
			dict set ::conf_np $kname_fingerprint 1
		} else {
			if {[dict exists $::conf_np $kname_fingerprint]} {
				puts "WARNING: [join $kname .] key overwrite [join $kname .] hierarchy."
			}
			# terminal part
			dict set ::conf_np [concat $kname_fingerprint T] 1
		}
	}

	switch $op {
	=S {
		dict set conf $kname $kval
	}
	?=S {
		if {![dict exists $conf $kname]} {
			dict set conf $kname $kval
		}
	}
	+=S {
		dict append conf $kname $kval
	}
	=L {
		dict set conf $kname $kval
	}
	?=L {
		if {![dict exists $conf $kname]} {
			dict set conf $kname $kval
		}
	}
	+=L {
		dict lappend conf $kname $kval
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
	set kname [split $kname .]
	if {![dict exists $::conf $kname]} {
		return {ERR "No such key"}
	}
	return [list OK [dict get $::conf $kname]]
}

######################################################################
# MAIN
######################################################################
if {[lindex $argv 0] eq "-h"} {
	puts "USAGE: $argv0 CONFFILE \[KEYFULLNAME]"
	puts "  KEYFULLNAME  - key name parts separated with commas"
	exit
}

# TODO: use getopt to get -hd value from command line
conf::load_from_file -hd . {conf_cb conf} [lindex $argv 0]

if {[lindex $argv 1] ne ""} {
	set res [get_key [lindex $argv 1]]
	if {[lindex $res 0] eq "ERR"} {
		puts stderr $res
		exit 1
	}
	puts [lindex $res 1]
	exit 0
}

while {[gets stdin line] >= 0} {
	set res [get_key $line]
	puts $res
}
