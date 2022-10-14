# Copyright (c) 2020-2022 Oleg Nemanov <lego12239@yandex.ru>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

namespace eval conf {
######################################################################
# load routines
######################################################################
# Load a conf from a file.
# SYNOPSIS:
#   load_from_file [-hd STR] [-default_conf STR] FILE_NAME
#
#   -hd STR
#       use STR as hierarchy delimiter in key names and group names
#   -default_conf STR
#       use STR text as a default conf.
# RETURN:
#   conf dict
proc load_from_file {args} {
	lassign [_opts_parse $args {} "-s -e"] opts idx
	if {$idx >= [llength $args]} {
		error "File name must be specified"
	}
	if {[expr {$idx + 1}] != [llength $args]} {
		error "Too many files are specified"
	}
	set fh [open [lindex $args $idx]]
	set src [dict create\
	  src $fh\
	  gets_r [namespace current]::gets_from_fh]

	set ctx [_ctx_mk $opts]
	_ctx_src_push ctx $src

	set err ""
	if {[catch {_load $ctx} conf]} {
		set err [list $conf $::errorInfo $::errorCode]
	}

	_ctx_src_pop ctx

	close $fh
	if {$err ne ""} {
		error {*}$err
	}
	return $conf
}

# Load a conf from an open file handle.
# SYNOPSIS:
#   load_from_fh [-hd STR] [-default_conf STR] CHAN
#
#   -hd STR
#       use STR as hierarchy delimiter in key names and group names
#   -default_conf STR
#       use STR text as a default conf.
# RETURN:
#   conf dict
proc load_from_fh {args} {
	lassign [_opts_parse $args {} "-s -e"] opts idx
	if {$idx >= [llength $args]} {
		error "Chan must be specified"
	}
	if {[expr {$idx + 1}] != [llength $args]} {
		error "Too many chans are specified"
	}
	set src [dict create\
	  src [lindex $args $idx]\
	  gets_r [namespace current]::gets_from_fh]

	set ctx [_ctx_mk $opts]
	_ctx_src_push ctx $src
	set conf [_load $ctx]
	_ctx_src_pop ctx

	return $conf
}

# Load a conf from a string.
# SYNOPSIS:
#   load_from_str [-hd STR] [-default_conf STR] [-s START_IDX] [-e END_IDX] CONF_STR
#
#   -hd STR
#       use STR as hierarchy delimiter in key names and group names
#   -default_conf STR
#       use STR text as a default conf.
#   -s START_IDX
#       start index for the parsing
#   -e END_IDX
#       end index for the parsing(including char at this idx)
# RETURN:
#   conf dict
proc load_from_str {args} {
	lassign [_opts_parse $args {-s 0}] opts idx
	if {$idx >= [llength $args]} {
		error "String must be specified"
	}
	if {[expr {$idx + 1}] != [llength $args]} {
		error "Too many strings are specified"
	}
	set src [dict create\
	  src [lindex $args $idx]\
	  gets_r [namespace current]::gets_from_str]
	set opts [dict merge\
	  [dict create -e [string length [lindex $args $idx]]]\
	  $opts]
	if {[dict get $opts -e] < [dict get $opts -s]} {
		error "-e is less than -s"
	}
	set ctx [_ctx_mk $opts]
	_ctx_src_push ctx $src
#	puts "CTX: $ctx"
	set conf [_load $ctx]
	_ctx_src_pop ctx

	return $conf
}

proc _opts_parse {argslist {defaults ""} {mask ""}} {
	set opts [dict create]

	for {set i 0} {$i < [llength $argslist]} {incr i} {
		set lex [lindex $argslist $i]
		if {[lsearch -exact $mask $lex] >= 0} {
			error "wrong parameter: $lex"
		}
		switch -glob -- $lex {
		-hd -
		-default_conf -
		-s -
		-e {
			incr i
			# Uncomment this if you want opts without "-".
			# Note: in this case "-" should be removed in every element of
			# list in the defaults arg too.
			#set lex [string range $lex 1 end]
			dict set opts $lex [lindex $argslist $i]
		}
		-- {
			incr i
			break
		}
		-* {
			error "unknown parameter: [lindex $argslist $i]"
		}
		default {
			break
		}
		}
	}

	set opts [dict merge $defaults $opts]

	return [list $opts $i]
}

# Start a parsing.
# prms:
#  ctx - context
proc _load {ctx} {
	if {[dict get $ctx prms -default_conf] ne ""} {
		if {[catch {load_from_str -hd [dict get $ctx prms -hd]\
		  [dict get $ctx prms -default_conf]} conf_default]} {
			error "default conf parse error: $conf_default"\
			  "default conf parse error: $::errorInfo"\
			  $::errorCode
		}
	} else {
		set conf_default [dict create]
	}

	return [_parse ctx $conf_default]
}

proc _parse {_ctx conf} {
	upvar $_ctx ctx
	set err ""
	if {[catch {__parse ctx $conf} conf]} {
		if {$::errorCode ne "CONFERR"} {
			if {[dict get $ctx src lineno_tok] != 0} {
				set err "conf lines: from [_toks_lineno ctx 0] to [dict get $ctx src lineno_tok]"
			}
			error "$conf\($err)" "$err\n$::errorInfo" $::errorCode
		}
		set err $conf
	}
	if {[dict get $ctx src buf] ne ""} {
		if {[string index [dict get $ctx src buf] 0] eq {"}} {
			error "$err\npossible unclosed quotes at\
			  [dict get $ctx src lineno_tok] line" "" CONFERR
		} else {
			error "$err\ntoken input buffer: '[dict get $ctx src buf]'" "" CONFERR
		}
	} elseif {$err ne ""} {
		error "$err" "" CONFERR
	}
	return $conf
}

proc __parse {_ctx conf} {
	upvar $_ctx ctx
	# cache a sect value
	set sect [lindex [dict get $ctx sect] end]

	while {[_toks_get ctx 3] > 0} {
		if {[_toks_match ctx "6 1 6 "]} {
			_conf_kv_set ctx conf [_toks_str ctx 0] [_toks_str ctx 2]
			_toks_drop ctx 3
		} elseif {[_toks_match ctx "6 1 2 "]} {
			set name [_toks_str ctx 0]
			_toks_drop ctx 3
			_conf_kv_set ctx conf $name [_parse_list ctx]
		} elseif {[_toks_match ctx "4 6 5 "]} {
			_sect_push ctx 0 [_toks_str ctx 1]
			_toks_drop ctx 3
#			puts "sect: [dict get $ctx sect]"
		} elseif {[_toks_match ctx "6 2 "]} {
			_sect_push ctx 1 [_toks_str ctx 0]
			_toks_drop ctx 2
#			puts "sect: [dict get $ctx sect]"
		} elseif {[_toks_match ctx "3 "]} {
			_sect_pop ctx 1
			_toks_drop ctx 1
#			puts "sect: [dict get $ctx sect]"
		} elseif {[_toks_match ctx "8 6 "]} {
			set fh [open [_toks_str ctx 1]]
			set src [dict create\
			  src $fh\
			  gets_r [namespace current]::gets_from_fh]
			_ctx_src_push ctx $src
			set err ""
			if {[catch {_parse ctx $conf} conf]} {
				set err $conf
			}
			_ctx_src_pop ctx
			close $fh
			_toks_drop ctx 2
			if {$err ne ""} {
				error $err $::errorInfo $::errorCode
			}
#			puts "sect: [dict get $ctx sect]"
		} else {
			error "parse error at [dict get $ctx src lineno_tok] line:\
			  unexpected token sequence at [_toks_lineno ctx 0] line:\
			  [_toks_dump ctx]\n\
			  want: KEY = VAL or KEY = \{ or GROUP_NAME \{ or \} or\
			  \[GROUP_NAME\]" "" CONFERR
		}
	}

	return $conf
}

proc _parse_list {_ctx} {
	upvar $_ctx ctx
	set list [list]
	# cache a sect value
	set sect [lindex [dict get $ctx sect] end]

	while {[_toks_get ctx 1] > 0} {
		if {[_toks_match ctx "6 "]} {
			lappend list [_toks_str ctx 0]
			_toks_drop ctx 1
		} elseif {[_toks_match ctx "2 "]} {
			_toks_drop ctx 1
			lappend list [_parse_list ctx]
		} elseif {[_toks_match ctx "3 "]} {
			_toks_drop ctx 1
			break
		} else {
			error "parse error at [dict get $ctx src lineno_tok] line:\
			  unexpected token sequence at [_toks_lineno ctx 0] line:\
			  [_toks_dump ctx]\n\
			  want: VAL or \} or \{" "" CONFERR
		}
	}

	return $list
}

# Create an initial context.
# prms:
#  prms - a dict with parameters:
#         -hd - hierarchy delimiter
#         -default_conf - a string with a default conf
#         -s  - start offset for src str(only for gets_from_str)
#         -e  - last offset for src str(only for gets_from_str)
# ret:
#  context dict with keys:
#    prms - a dict with parameters
#    src  - a current source
#    srcs - a stack with sources
#    sect - a section stack(section is a hierarchy level name)
#    sect_type - a section type stack
proc _ctx_mk {{prms ""}} {
	set prms_def [dict create\
	  -hd ""\
	  -default_conf ""]
	set prms [dict merge $prms_def $prms]

	return [dict create\
	  prms $prms\
	  src [dict create]\
	  srcs [list]\
	  sect [list]\
	  sect_type [list]]
}

# Push to a stack a specified src data and set it as a current src.
# src keys:
#   for lexer:
#     src - a source(string, CHAN or other data specific for a source)
#     gets_r - a routine for next line reading(must work like a gets)
#     lineno - line number of a last read line of a source
#     lineno_tok - line number of a start line of a last token
#     buf - input buffer(lines read from a source)
#   for parser:
#     toks - input tokens buffer(tokens read, but not yet removed)
#     toks_toks - a cache for _toks_match(tokens numbers in one string)
proc _ctx_src_push {_ctx src} {
	upvar $_ctx ctx
	set src_def [dict create\
	  gets_r ""\
	  lineno 0\
	  lineno_tok 0\
	  buf ""\
	  toks ""\
	  toks_toks ""]

	dict lappend ctx srcs [dict get $ctx src]
	set src [dict merge $src_def $src]
	dict set ctx src $src
}

# Pop from a stack one src and set the next one as a current src.
proc _ctx_src_pop {_ctx} {
	upvar $_ctx ctx

	dict set ctx src [lindex [dict get $ctx srcs] end]
	dict set ctx srcs [lrange [dict get $ctx srcs] 0 end-1]
}

# Add a sect with specified name and type to a sects stack.
# prms:
#  _ctx - ctx var name
#  type - 0 for [] sect, 1 for {} sect
#  name - a sect name string
proc _sect_push {_ctx type name} {
	upvar $_ctx ctx

	if {($type == 0) && ([lindex [dict get $ctx sect_type] end] == 0)} {
		_sect_pop ctx 0
	}
	set sect [lindex [dict get $ctx sect] end]
	lappend sect {*}[_mk_name ctx $name]
	dict lappend ctx sect $sect
	dict lappend ctx sect_type $type
}

# Remove a section with specified type from a sects stack.
# prms:
#  _ctx - ctx var name
# Remove all sections with other types until the needed is found.
proc _sect_pop {_ctx type} {
	upvar $_ctx ctx
	set is_run 1

	while {$is_run} {
		if {[llength [dict get $ctx sect_type]] == 0} {
			error "can't find a section with type $type during a pop"\
			  "" CONFERR
		}
		if {[lindex [dict get $ctx sect_type] end] == $type} {
			set is_run 0
		}
		dict set ctx sect [lrange [dict get $ctx sect] 0 end-1]
		dict set ctx sect_type [lrange [dict get $ctx sect_type] 0 end-1]
	}
}

# Get a current section name(list form).
# prms:
#  _ctx - ctx var name
# ret:
#  list - a section full name
proc _sect_get {_ctx} {
	upvar $_ctx ctx

	return [join [lindex [dict get $ctx sect] end]]
}

# Assign a specified value to a specified name
# prms:
#  _ctx - ctx var name
#  name - a conf parameter name(string)
#  val  - a conf parameter value
proc _conf_kv_set {_ctx _conf name val} {
	upvar $_ctx ctx
	upvar $_conf conf

	set names [_sect_get ctx]
	lappend names {*}[_mk_name ctx $name]
	dict set conf {*}$names $val
}

# Get list of names from supplied str by splitting it on hd char sequence.
# If hd is empty string, then use supplied str as is.
# E.g.(ctx with hd set to "->"):
#   _mk_name ctx "a->b->c"
#   returns [a b c]
proc _mk_name {_ctx str} {
	upvar $_ctx ctx
	set name [list]

	set delim [dict get $ctx prms -hd]
	if {$delim eq ""} {
		return [list $str]
	}
	# TODO: check that first chars are not $delim?
	set dlen [string length $delim]
	set idx 0
	while {[set didx [string first $delim $str $idx]] >= 0} {
		lappend name [string range $str $idx ${didx}-1]
		set idx [expr {$didx + $dlen}]
	}
	lappend name [string range $str $idx end]
	return $name
}

proc _toks_get {_ctx cnt} {
	upvar $_ctx ctx

	set toks [dict get $ctx src toks]
	set len [llength $toks]
	# Read tokens
	while {($len < $cnt) && ([set tok [_get_tok ctx]] >= 0)} {
		# Debug output
#		puts "$tok: '[dict get $ctx src tok_str]'"
		lappend toks [list $tok [dict get $ctx src tok_str]\
		  [dict get $ctx src lineno_tok]]
		incr len
	}
	dict set ctx src toks $toks

	# Make a string from a tokens numbers sequence
	set str ""
	for {set i 0} {$i < $len} {incr i} {
		set str "$str[lindex [dict get $ctx src toks] $i 0] "
	}
	dict set ctx src toks_toks $str

	return $len
}

proc _toks_drop {_ctx cnt} {
	upvar $_ctx ctx

	incr cnt -1
	dict set ctx src toks [lreplace [dict get $ctx src toks] 0 $cnt]
}

proc _toks_match {_ctx str} {
	upvar $_ctx ctx
	set len [string length $str]

	return [string equal -length [string length $str]\
	  [dict get $ctx src toks_toks] $str]
}

proc _toks_str {_ctx idx} {
	upvar $_ctx ctx

	return [lindex [dict get $ctx src toks] $idx 1]
}

proc _toks_lineno {_ctx idx} {
	upvar $_ctx ctx

	return [lindex [dict get $ctx src toks] $idx 2]
}

proc _toks_dump {_ctx} {
	upvar $_ctx ctx
	set res ""
	set len [llength [dict get $ctx src toks]]

	for {set i 0} {$i < $len} {incr i} {
		set tok [lindex [dict get $ctx src toks] $i]
		set res "$res'[lindex $tok 1]'#[lindex $tok 0](L[lindex $tok 2]) "
	}
	return [string range $res 0 end-1]
}

# Get a next token.
# return:
#  1 - =
#  2 - {
#  3 - }
#  4 - [
#  5 - ]
#  6 - word/string
#  7 - USED INTERNALLY(for string)!
#  8 - <
proc _get_tok {_ctx} {
	upvar $_ctx ctx
	set tok -1

	dict set ctx src lineno_tok [dict get $ctx src lineno]
	while {$tok < 0} {
		switch -regexp -matchvar mstr [dict get $ctx src buf] {
			{^\s+} {
				_biteoff_buf ctx [string length [lindex $mstr 0]]
			}
			{^=} {
				set tok 1
			}
			{^<} {
				set tok 8
			}
			{^#[^\n]*} {
				_biteoff_buf ctx [string length [lindex $mstr 0]]
			}
			"^{" {
				set tok 2
			}
			"^}" {
				set tok 3
			}
			{^\[} {
				set tok 4
			}
			{^\]} {
				set tok 5
			}
			{^[^][[:space:]=#"{}]+} {
				set tok 6
			}
			{^"([^"\\]+|\\.|)+"} {
				set tok 7
			}
			default {
				if {[[dict get $ctx src gets_r] ctx line] < 0} {
					return -1
				}
				dict set ctx src lineno [expr {[dict get $ctx src lineno]+1}]
				if {[dict get $ctx src buf] ne ""} {
					dict set ctx src buf "[dict get $ctx src buf]\n$line"
				} else {
					dict set ctx src lineno_tok [dict get $ctx src lineno]
					dict set ctx src buf $line
				}
			}
		}
	}
	_biteoff_buf ctx [string length [lindex $mstr 0]]
	if {$tok == 7} {
		set str [string range [lindex $mstr 0] 1 end-1]
		regsub -all {\\(.)} $str {\1} str
		# Remove this to represent string with 7.
		set tok 6
	} else {
		set str [lindex $mstr 0]
	}
	dict set ctx src tok_str $str
	return $tok
}

proc _biteoff_buf {_ctx len} {
	upvar $_ctx ctx
	dict set ctx src buf [string range [dict get $ctx src buf] $len end]
}

######################################################################
# src callbacks
######################################################################
proc gets_from_fh {_ctx _var} {
	upvar $_ctx ctx
	upvar $_var var

	return [gets [dict get $ctx src src] var]
}

proc gets_from_str {_ctx _var} {
	upvar $_ctx ctx
	upvar $_var var

	if {[dict get $ctx prms -s] > [dict get $ctx prms -e]} {
		return -1
	}
	set pos [string first "\n" [dict get $ctx src src] [dict get $ctx prms -s]]
	if {($pos < 0) || ($pos > [dict get $ctx prms -e])} {
		set pos [dict get $ctx prms -e]
		set off ""
	} else {
		set off "-1"
	}
	set var [string range [dict get $ctx src src] [dict get $ctx prms -s]\
	  ${pos}$off]
	dict set ctx prms -s [expr {$pos + 1}]
	return [string length $var]
}
}

package provide conf 0.10

