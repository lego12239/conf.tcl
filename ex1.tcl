#!/usr/bin/env tclsh
# just print callback parameters on every call

lappend auto_path [pwd]
package require conf

proc conf_cb {_ctx op kname kval} {
	puts "$op \"$kname\" \"$kval\""
}

conf::load_from_file -hd . conf_cb ex2.conf
