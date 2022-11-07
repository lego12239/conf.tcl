#!/usr/bin/env tclsh

lappend auto_path [pwd]
package require conf

# TODO: use getopt to get -hd value from command line
# TODO: add -type option to get a value type, instead of a value
set cas [conf::load_from_file -hd . [lindex $argv 0]]
set names [split [lindex $argv 1] .]
puts "[conf::get_key $cas $names]"
