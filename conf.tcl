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
#   load_from_file [-hd STR] [-default CAS] [-path STR] [-cb CB_AND_PRIV]
#     FILE_NAME
#
#   -hd STR
#       use STR as hierarchy delimiter in key names and group names
#   -default CAS
#       use CAS(list with 2 elements: conf and spec) as an initial(default)
#       conf.
#   -path STR
#       use STR as file path prefix for every included file
#   -cb CB_AND_PRIV
#       CB_AND_PRIV is a list: {CALLBACK PRIV}. Use specified CALLBACK
#       proc as value set/append callback; and specified PRIV will be
#       used as initial value for priv in a context.
#       Callback must ret value type(S or L) or "" if value shouldn't be saved.
# RETURN:
#   {CONF CSPEC}   - dict with conf parameters, conf dict specification
#   {CONF CSPEC PRIV} - dict with conf parameters, conf dict
#                            specification and priv
proc load_from_file {args} {
	lassign [_opts_parse $args {-hd 1 -default 1 -path 1 -cb 1}] opts idx
	if {$idx >= [llength $args]} {
		error "File name must be specified"
	}
	if {[expr {$idx + 1}] != [llength $args]} {
		error "Too many files are specified"
	}
	set fh [open [lindex $args $idx]]
	set src [dict create\
	  name [lindex $args $idx]\
	  src $fh\
	  gets_r [namespace current]::gets_from_fh]

	set ctx [_ctx_mk $opts]
	_ctx_src_push ctx $src

	set err ""
	if {[catch {_parse ctx [dict get $ctx default]} conf]} {
		set err [list $conf $::errorInfo $::errorCode]
	}

	_ctx_src_pop ctx

	close $fh
	if {$err ne ""} {
		error {*}$err
	}
	if {[dict exists $opts -cb]} {
		return [list $conf [dict get $ctx cspec] [dict get $ctx priv]]
	}
	return [list $conf [dict get $ctx cspec]]
}

# Load a conf from an open file handle.
# SYNOPSIS:
#   load_from_fh [-hd STR] [-default CAS] [-path STR] [-cb CB_AND_PRIV] CHAN
#
#   -hd STR
#       use STR as hierarchy delimiter in key names and group names
#   -default CAS
#       use CAS(list with 2 elements: conf and spec) as an initial(default)
#       conf.
#   -path STR
#       use STR as file path prefix for every included file
#   -cb CB_AND_PRIV
#       CB_AND_PRIV is a list: {CALLBACK PRIV}. Use specified CALLBACK
#       proc as value set/append callback; and specified PRIV will be
#       used as initial value for priv in a context.
#       Callback must ret value type(S or L) or "" if value shouldn't be saved.
# RETURN:
#   {CONF CSPEC}   - dict with conf parameters, conf dict specification
#   {CONF CSPEC PRIV} - dict with conf parameters, conf dict
#                            specification and priv
proc load_from_fh {args} {
	lassign [_opts_parse $args {-hd 1 -default 1 -path 1 -cb 1}] opts idx
	if {$idx >= [llength $args]} {
		error "Chan must be specified"
	}
	if {[expr {$idx + 1}] != [llength $args]} {
		error "Too many chans are specified"
	}
	set src [dict create\
	  name "FH:[lindex $args $idx]"\
	  src [lindex $args $idx]\
	  gets_r [namespace current]::gets_from_fh]

	set ctx [_ctx_mk $opts]
	_ctx_src_push ctx $src
	set conf [_parse ctx [dict get $ctx default]]
	_ctx_src_pop ctx

	if {[dict exists $opts -cb]} {
		return [list $conf [dict get $ctx cspec] [dict get $ctx priv]]
	}
	return [list $conf [dict get $ctx cspec]]
}

# Load a conf from a string.
# SYNOPSIS:
#   load_from_str [-hd STR] [-default CAS] [-path STR] [-cb CB_AND_PRIV]
#     [-s START_IDX] [-e END_IDX] CONF_STR
#
#   -hd STR
#       use STR as hierarchy delimiter in key names and group names
#   -default CAS
#       use CAS(list with 2 elements: conf and spec) as an initial(default)
#       conf.
#   -path STR
#       use STR as file path prefix for every included file
#   -cb CB_AND_PRIV
#       CB_AND_PRIV is a list: {CALLBACK PRIV}. Use specified CALLBACK
#       proc as value set/append callback; and specified PRIV will be
#       used as initial value for priv in a context.
#       Callback must ret value type(S or L) or "" if value shouldn't be saved.
#   -s START_IDX
#       start index for the parsing
#   -e END_IDX
#       end index for the parsing(including char at this idx)
# RETURN:
#   {CONF CSPEC}   - dict with conf parameters, conf dict specification
#   {CONF CSPEC PRIV} - dict with conf parameters, conf dict
#                            specification and priv
proc load_from_str {args} {
	lassign [_opts_parse $args {-hd 1 -default 1 -path 1 -cb 1 -s 1 -e 1}]\
	  opts idx
	if {$idx >= [llength $args]} {
		error "String must be specified"
	}
	if {[expr {$idx + 1}] != [llength $args]} {
		error "Too many strings are specified"
	}
	set src [dict create\
	  name "STR"\
	  src [lindex $args $idx]\
	  gets_r [namespace current]::gets_from_str]
	set opts [dict merge\
	  [dict create -s 0 -e [string length [lindex $args $idx]]]\
	  $opts]
	if {[dict get $opts -e] < [dict get $opts -s]} {
		error "-e is less than -s"
	}
	set ctx [_ctx_mk $opts]
	_ctx_src_push ctx $src
#	puts "CTX: $ctx"
	set conf [_parse ctx [dict get $ctx default]]
	_ctx_src_pop ctx

	if {[dict exists $opts -cb]} {
		return [list $conf [dict get $ctx cspec] [dict get $ctx priv]]
	}
	return [list $conf [dict get $ctx cspec]]
}

# Parse options from argslist.
# Stop on first non-option argument or after --.
# prms:
#  argslist - arguments to parse
#  spec     - opts spec. A dict where:
#             key - opt name (started with "-")
#             value - 0 for opt without argument
#                     1 for opt with argument
# ret:
#  list - 1 item is opts dict with opts from argslist, 2 item is index for first
#         non-option argument
#
# E.g.:
#  _opts_parse "-dval -t 7 -- fname q" {-dval 0 -D 1 -t 1}
#
proc _opts_parse {argslist spec} {
	set opts [dict create]

	for {set i 0} {$i < [llength $argslist]} {incr i} {
		set lex [lindex $argslist $i]
		if {![string equal -length 1 $lex "-"]} {
			break
		}
		if {$lex eq "--"} {
			incr i
			break
		}
		if {![dict exists $spec $lex]} {
			error "wrong option: $lex"
		}
		set val [dict get $spec $lex]
		if {[lindex $val 0]} {
			incr i
			dict set opts $lex [lindex $argslist $i]
		} else {
			dict incr opts $lex
		}
	}

	return [list $opts $i]
}

proc _parse {_ctx conf} {
	upvar $_ctx ctx
	set err ""
	set emsg ""
	if {[catch {__parse ctx $conf} conf]} {
		if {[_toks_cnt ctx] > 0} {
			set err_from_lineno [_toks_lineno ctx 0]
		}
		# file name and line numbers shouldn't be separated by space
#		set emsg "[dict get $ctx src name]:${err_from_lineno}-[dict get $ctx src lineno_tok]"
		set emsg "[dict get $ctx src name]:${err_from_lineno}"
		set emsg "conf error at $emsg"
		set err [list "${emsg}: $conf" "$emsg\n$::errorInfo" $::errorCode]
	}
	if {[dict get $ctx src buf] ne ""} {
		set emsg [lindex $err 0]
		if {[string index [dict get $ctx src buf] 0] eq {"}} {
			lset err 0 "${emsg}. Possible unclosed quotes at line\
			  [dict get $ctx src lineno_tok]"
		} else {
			lset err 0 "${emsg}. Token input buffer:\
			  '[dict get $ctx src buf]'"
		}
	}

	if {$err ne ""} {
		error {*}$err
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
		} elseif {[_toks_match ctx "6 9 6 "]} {
			_conf_kv_append ctx conf [_toks_str ctx 0] [_toks_str ctx 2]
			_toks_drop ctx 3
		} elseif {[_toks_match ctx "6 10 6 "]} {
			_conf_kv_set_if_not_exist ctx conf [_toks_str ctx 0]\
			  [_toks_str ctx 2]
			_toks_drop ctx 3
		} elseif {[_toks_match ctx "6 1 4 "]} {
			set name [_toks_str ctx 0]
			_toks_drop ctx 3
			_conf_kv_set_list ctx conf $name [_parse_list ctx]
		} elseif {[_toks_match ctx "6 9 4 "]} {
			set name [_toks_str ctx 0]
			_toks_drop ctx 3
			_conf_kv_append_list ctx conf $name [_parse_list ctx]
		} elseif {[_toks_match ctx "6 10 4 "]} {
			set name [_toks_str ctx 0]
			_toks_drop ctx 3
			_conf_kv_set_list_if_not_exist ctx conf $name [_parse_list ctx]
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
			set fmask [_toks_str ctx 1]
			_toks_drop ctx 2
			_parse_file_inclusion ctx conf $fmask
#			puts "sect: [dict get $ctx sect]"
		} else {
			error "unexpected token sequence:\
			  \"[_toks_dump ctx]\". Want:\
			  KEY = VAL or KEY = \[ or GROUP_NAME \{ or \} or\
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
		} elseif {[_toks_match ctx "4 "]} {
			_toks_drop ctx 1
			lappend list [_parse_list ctx]
		} elseif {[_toks_match ctx "5 "]} {
			_toks_drop ctx 1
			break
		} else {
			error "unexpected token sequence:\
			  \"[_toks_dump ctx]\".\
			  Want: VAL or \[ or \]" "" CONFERR
		}
	}

	return $list
}

proc _parse_file_inclusion {_ctx _conf fmask} {
	upvar $_ctx ctx
	upvar $_conf conf

	set fnames [lsort [glob -directory [dict get $ctx prms -path] $fmask]]
	foreach fname $fnames {
		set fh [open $fname]
		set src [dict create\
		  name "$fname"\
		  src $fh\
		  gets_r [namespace current]::gets_from_fh]
		_ctx_src_push ctx $src
		set err ""
		if {[catch {_parse ctx $conf} conf]} {
			set err [list $conf $::errorInfo $::errorCode]
		}
		_ctx_src_pop ctx
		close $fh
		if {$err ne ""} {
			error {*}$err
		}
	}
}

# Create an initial context.
# prms:
#  prms - a dict with parameters:
#         -hd - hierarchy delimiter
#         -default - a list with a default conf and its spec
#         -path    - a string with a default file path prefix
#         -cb      - a value set/append callback
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
	  -default ""\
	  -path "./"\
	  -cb ""]
	set prms [dict merge $prms_def $prms]
	if {[string index [dict get $prms -path] end] ne "/"} {
		dict append prms -path "/"
	}
	set cb [lindex [dict get $prms -cb] 0]
	set priv [lindex [dict get $prms -cb] 1]
	set default [lindex [dict get $prms -default] 0]
	set cspec [lindex [dict get $prms -default] 1]

	return [dict create\
	  prms $prms\
	  cb $cb\
	  priv $priv\
	  default $default\
	  cspec $cspec\
	  src [dict create]\
	  srcs [list]\
	  sect [list]\
	  sect_type [list]]
}

# Push to a stack a specified src data and set it as a current src.
# src keys:
#   common:
#     name - a source name(e.g. filename) for error reporting
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
	  name ""\
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

	# If previous sect is [] sect, then pop a previous name - we need to
	# replace it with a new name.
	if {[lindex [dict get $ctx sect_type] end] == 0} {
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
#  value  - a conf parameter value
proc _conf_kv_set {_ctx _conf name value} {
	upvar $_ctx ctx
	upvar $_conf conf

	_conf_kv_set_list ctx conf $name $value "=S"
}

# Assign a specified values list to a specified name
# prms:
#  _ctx - ctx var name
#  name - a conf parameter name(string)
#  vlist  - a conf parameter value
proc _conf_kv_set_list {_ctx _conf name vlist {op "=L"}} {
	upvar $_ctx ctx
	upvar $_conf conf
	set data ""

	set type [string index $op end]
	set names [_sect_get ctx]
	lappend names {*}[_mk_name ctx $name]
	if {[dict get $ctx cb] ne ""} {
		set type [[dict get $ctx cb] ctx conf $op names vlist]
		if {$type eq ""} {
			return
		}
	}
	# Protect from a case where we assign to an existing key as if it would
	# be a section. E.g. "k1=\[k2 v2 k4 v4\] k1.k4=v44" config can
	# mistakenly got {k1 {k2 v2 k4 v44}} instead of {k1 {k4 v44}}.
	set ret [spec_key_existence {ctx cspec} $names data]
	if {$ret == -2} {
		dict set conf {*}$data ""
		spec_path_unset {ctx cspec} $data
	}
	dict set conf {*}$names $vlist
	spec_key_set {ctx cspec} $names $type
}

# Assign a specified value to a specified name if it's not exist.
# prms:
#  _ctx - ctx var name
#  name - a conf parameter name(string)
#  value  - a conf parameter value
proc _conf_kv_set_if_not_exist {_ctx _conf name value} {
	upvar $_ctx ctx
	upvar $_conf conf

	_conf_kv_set_list_if_not_exist ctx conf $name $value "?=S"
}

# Assign a specified values list to a specified name if it's not exist.
# prms:
#  _ctx - ctx var name
#  name - a conf parameter name(string)
#  vlist  - a conf parameter value
proc _conf_kv_set_list_if_not_exist {_ctx _conf name vlist {op "?=L"}} {
	upvar $_ctx ctx
	upvar $_conf conf

	set type [string index $op end]
	set names [_sect_get ctx]
	lappend names {*}[_mk_name ctx $name]
	if {[dict get $ctx cb] ne ""} {
		set type [[dict get $ctx cb] ctx conf $op names vlist]
		if {$type eq ""} {
			return
		}
	}
	set ret [spec_key_existence {ctx cspec} $names]
	if {$ret != -1} {
		return
	}
	dict set conf {*}$names $vlist
	spec_key_set {ctx cspec} $names $type
}

# Append a specified value to a specified name
# prms:
#  _ctx - ctx var name
#  name - a conf parameter name(string)
#  value  - a conf parameter value
proc _conf_kv_append {_ctx _conf name value} {
	upvar $_ctx ctx
	upvar $_conf conf

	_conf_kv_append_list ctx conf $name $value "+=S"
}

# Append a specified values list to a specified name
# prms:
#  _ctx - ctx var name
#  name - a conf parameter name(string)
#  vlist  - a conf parameter value
proc _conf_kv_append_list {_ctx _conf name vlist {op "+=L"}} {
	upvar $_ctx ctx
	upvar $_conf conf
	set data ""

	set type [string index $op end]
	set names [_sect_get ctx]
	lappend names {*}[_mk_name ctx $name]
	if {[dict get $ctx cb] ne ""} {
		set type [[dict get $ctx cb] ctx conf $op names vlist]
		if {$type eq ""} {
			return
		}
	}
	if {$type eq "S"} {
		set vlist [list $vlist]
	}
	# Protect from reassign mistakes. See _conf_kv_set proc for the
	# explanation.
	set ret [spec_key_existence {ctx cspec} $names data]
	if {$ret == -2} {
		dict set conf {*}$data ""
		spec_path_unset {ctx cspec} $data
	} elseif {$ret == 1} {
		# This isn't actually needed, becase {*}$names key will replaced
		# with new value in any case.
		dict set conf {*}$names ""
		spec_path_unset {ctx cspec} $names
	} elseif {$ret == 0} {
		if {$data eq "S"} {
			set vlist [list [dict get $conf {*}$names] {*}$vlist]
		} else {
			set vlist [list {*}[dict get $conf {*}$names] {*}$vlist]
		}
	}
	dict set conf {*}$names $vlist
	spec_key_set {ctx cspec} $names "L"
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

proc _toks_cnt {_ctx} {
	upvar $_ctx ctx

	return [llength [dict get $ctx src toks]]
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
#  9 - +=
#  10 - ?=
proc _get_tok {_ctx} {
	upvar $_ctx ctx
	set tok -1

	dict set ctx src lineno_tok [dict get $ctx src lineno]
	while {$tok < 0} {
		switch -regexp -matchvar mstr [dict get $ctx src buf] {
			{^\s+} {
				_biteoff_buf ctx [string length [lindex $mstr 0]]
			}
			{^\+=} {
				set tok 9
			}
			{^\?=} {
				set tok 10
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
			{^[^\]\[[:space:]=#"{}+?]+} {
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

######################################################################
# conf dict access routines
######################################################################
# Get a specified key with specified type(optional) from a parsed conf.
# prms:
#  cas   - a list with conf and spec(this list is returned from load_* proc)
#  names - a list with key full name
#  type  - S or L
# ret:
#  VALUE - a key value
#
# If a key isn't found(or it is a section, instead of a leaf), then exception is
# thrown. If type is specified and it isn't equal to key type, then exception is
# thrown.
proc get_key {cas names {type ""}} {
	set ret [conf::spec_key_existence [lindex $cas 1] $names val]
	if {[$ret != 0]} {
		throw [list CONF NOKEY $names $ret] "conf error: $ret: no key {$names}"
	}
	set value [dict get [lindex $cas 0] $names]
	if {($type ne "") && ($type ne $val)} {
		throw [list CONF WRONGTYPE $names $val] "conf error: key {$names} has type\
		  $val instead of $type"
	}

	return $value
}

######################################################################
# spec manipulation routines
######################################################################
# Set a specified key to a specified value
# prms:
#  _cspec - a var name of config specification.
#           This can be a list of names, where first name is a dict name
#           and next names are full name of config specification key saved
#           in this dict.
#  names  - a key full name(separated with spaces)
#  value  - a new value for a key
proc spec_key_set {_cspec names value} {
	if {($value ne "S") && ($value ne "L")} {
		error "wrong cspec key value: $value"
	}

	upvar [lindex $_cspec 0] cspec0
	if {[llength $_cspec] > 1} {
		set cspec [list cspec0 [lrange $_cspec 1 end]]
	} else {
		set cspec [list cspec0]
	}

	dict set {*}$cspec {*}$names $value
}

# Unset a specifid key
# prms:
#  _cspec - a var name of config specification.
#           This can be a list of names, where first name is a dict name
#           and next names are full name of config specification key saved
#           in this dict.
#  names  - a key full name(separated with spaces)
proc spec_path_unset {_cspec names} {
	upvar [lindex $_cspec 0] cspec0
	if {[llength $_cspec] > 1} {
		set cspec [list cspec0 [lrange $_cspec 1 end]]
	} else {
		set cspec [list cspec0]
	}
	dict unset {*}$cspec {*}$names
}

# Return key existence state.
# prms:
#  spec   - specification of some dict, where key is a key and
#           a leaf value is a dot
#  names  - a key full path(keys separated by spaces)
#  _out   - a variable name to save some data in addition to ret value;
#           this data is different for each ret value(see description of ret
#           value below)
# ret:
#  -2 - specified key doesn't exists and some predecessor key is a leaf key;
#       $_out var contains existent part of key path(a part of names list)
#  -1 - specified key doesn't exists
#   0 - specified key exists and it is a leaf key
#       $_out var contains
#   1 - specified key exists, but it is not a leaf key
#
# E.g. we have a dict:
#  k1 {k2 {k3 "some data"}}
# A dict spec for this dict is:
#  set d [dict create k1 {k2 {k3 S}}]
# So:
# % spec_key_existence $d {k1 k2 k3 k4} val
# -2
# % puts $val
# k1 k2 k3
# % spec_key_existence $d {k1 k4}
# -1
# % spec_key_existence $d {k1 k2 k3} val
# 0
# % puts $val
# S
# % spec_key_existence $d {k1 k2}
# 1
proc spec_key_existence {_cspec names {_out ""}} {
	upvar [lindex $_cspec 0] cspec0
	if {[llength $_cspec] > 1} {
		set v [dict get $cspec0 {*}[lrange $_cspec 1 end]]
	} else {
		set v $cspec0
	}

	set len [llength $names]
	incr len -1
	for {set i 0} {$i <= $len} {incr i} {
		set k [lindex $names $i]
		if {![dict exists $v $k]} {
			return -1
		}
		set v [dict get $v $k]
		if {$i < $len} {
			if {($v eq "S") || ($v eq "L")} {
				if {$_out ne ""} {
					upvar $_out val
					set val [lrange $names 0 $i]
				}
				return -2
			}
		} else {
			if {($v ne "S") && ($v ne "L")} {
				return 1
			}
		}
	}

	if {$_out ne ""} {
		upvar $_out val
		set val $v
	}
	return 0
}

# Compare a cspec against a reference cspec
# prms:
#  ref   - reference cspec, where a value of a leaf key can be:
#          S - string
#          L - list
#          A - string or list
#          c - any conf hierarchy
#          C - any conf hierarchy or string or list
#  cspec - cspec to compare
# ret:
#  LIST - each item is a mismatch entry which is a list, where 1 item is
#         a mismatch type and 2 item is full path to a key:
#         {M KEY_PATH} - miss, KEY_PATH from ref is missed from cspec
#         {T KEY_PATH} - wrong type, KEY_PATH from ref is different type
#                        than in cspec
#         {E KEY_PATH} - excess, KEY_PATH from cspec is missed from ref
proc spec_cmp {ref cspec} {
	return [_spec_cmp $ref $cspec]
}

proc _spec_cmp {ref cspec {prefix ""}} {
	set res [list]

#	puts "ENTER: $prefix"
	dict for {k vref} $ref {
#		puts "$k: $vref"
		if {![dict exists $cspec $k]} {
			lappend res [list M [list {*}$prefix $k]]
			continue
		}
		set v [dict get $cspec $k]
#		puts "=$k: $v"
		if {($vref eq "S") || ($vref eq "L")} {
			if {$vref ne $v} {
				lappend res [list T [list {*}$prefix $k]]
			}
			continue
		} elseif {$vref eq "A"} {
			if {($v ne "S") && ($v ne "L")} {
				lappend res [list T [list {*}$prefix $k]]
			}
			continue
		} elseif {$vref eq "c"} {
			if {($v eq "S") || ($v eq "L")} {
				lappend res [list T [list {*}$prefix $k]]
			}
			continue
		} elseif {$vref eq "C"} {
			continue
		}
		if {($v eq "S") || ($v eq "L")} {
			lappend res [list T [list {*}$prefix $k]]
			continue
		}
		lappend res {*}[_spec_cmp $vref $v [list {*}$prefix $k]]
	}
	# Collect excess keys
	dict for {k v} $cspec {
		if {![dict exists $ref $k]} {
			lappend res [list E [list {*}$prefix $k]]
		}
	}

	return $res
}
}

package provide conf 0.10

