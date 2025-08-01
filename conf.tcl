# Copyright (c) 2020-2025 Oleg Nemanov <lego12239@yandex.ru>
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
#   load_from_file [-hd STR] [-path STR] CALLBACK FILE_NAME
#
#   -hd STR
#       use STR as hierarchy delimiter in key names and group names
#   -path STR
#       use STR as file path prefix for every included file
#
#   CALLBACK
#       CALLBACK is a proc name or a list - {CALLBACK ARG1 ...}. This callback
#       is called on every parsed key-value and section enter/leave. It is
#       called with specified arguments and appended context variable name,
#       the operation, a full key name, a value.
#       Callback last parameters must be:
#       - ctx var name
#       - operation (=S, =L, +=S, +=L, ?=S or ?=L)
#       - key full name(list with sect names and a key name)
#       - value
#   FILE_NAME
#       A file name to parse.
#
proc load_from_file {args} {
	set opts [_opts_parse {-hd 1 -path 1} args]
	if {[llength $args] < 2} {
		error "Callback and file name must be specified"
	} elseif {[llength $args] > 2} {
		error "Too many arguments are specified"
	}
	set fh [open [lindex $args 1]]
	set src [dict create\
	  name [lindex $args 1]\
	  src $fh\
	  gets_r [namespace current]::gets_from_fh]

	set ctx [_ctx_mk [lindex $args 0] $opts]
	_ctx_src_push ctx $src

	set err ""
	if {[catch {_parse ctx} res]} {
		set err [list $res $::errorInfo $::errorCode]
	}

	_ctx_src_pop ctx

	close $fh
	if {$err ne ""} {
		error {*}$err
	}
}

# Load a conf from an open file handle.
# SYNOPSIS:
#   load_from_fh [-hd STR] [-path STR] CALLBACK CHAN
#
#   -hd STR
#       use STR as hierarchy delimiter in key names and group names
#   -path STR
#       use STR as file path prefix for every included file
#
#   CALLBACK
#       CALLBACK is a proc name or a list - {CALLBACK ARG1 ...}. This callback
#       is called on every parsed key-value and section enter/leave. It is
#       called with specified arguments and appended context variable name,
#       the operation, a full key name, a value.
#       Callback last parameters must be:
#       - ctx var name
#       - operation (=S, =L, +=S, +=L, ?=S or ?=L)
#       - key full name(list with sect names and a key name)
#       - value
#   CHAN
#       A chan to parse data from.
#
proc load_from_fh {args} {
	set opts [_opts_parse {-hd 1 -path 1} args]
	if {[llength $args] < 2} {
		error "Callback and chan must be specified"
	} elseif {[llength $args] > 2} {
		error "Too many arguments are specified"
	}
	set src [dict create\
	  name "FH:[lindex $args 1]"\
	  src [lindex $args 1]\
	  gets_r [namespace current]::gets_from_fh]

	set ctx [_ctx_mk [lindex $args 0] $opts]
	_ctx_src_push ctx $src
	_parse ctx
	_ctx_src_pop ctx
}

# Load a conf from a string.
# SYNOPSIS:
#   load_from_str [-hd STR] [-path STR] [-s START_IDX] [-e END_IDX]
#     CALLBACK CONF_STR
#
#   -hd STR
#       use STR as hierarchy delimiter in key names and group names
#   -path STR
#       use STR as file path prefix for every included file
#   -s START_IDX
#       start index for the parsing
#       0 by default
#   -e END_IDX
#       end index for the parsing(including char at this idx)
#       last char idx by default
#
#   CALLBACK
#       CALLBACK is a proc name or a list - {CALLBACK ARG1 ...}. This callback
#       is called on every parsed key-value and section enter/leave. It is
#       called with specified arguments and appended context variable name,
#       the operation, a full key name, a value.
#       Callback last parameters must be:
#       - ctx var name
#       - operation (=S, =L, +=S, +=L, ?=S or ?=L)
#       - key full name(list with sect names and a key name)
#       - value
#   CONF_STR
#       A string to parse.
#
proc load_from_str {args} {
	set opts [_opts_parse {-hd 1 -path 1 -s 1 -e 1} args]
	if {[llength $args] < 2} {
		error "Callback and string must be specified"
	} elseif {[llength $args] > 2} {
		error "Too many arguments are specified"
	}
	set src [dict create\
	  name "STR"\
	  src [lindex $args 1]\
	  gets_r [namespace current]::gets_from_str]
	set opts [dict merge\
	  [dict create -s 0 -e [string length [lindex $args 1]]]\
	  $opts]
	if {[dict get $opts -e] < [dict get $opts -s]} {
		error "-e is less than -s"
	}
	set ctx [_ctx_mk [lindex $args 0] $opts]
	_ctx_src_push ctx $src
#	puts "CTX: $ctx"
	_parse ctx
	_ctx_src_pop ctx
}

# Parse proc options.
# prms:
#  _argslist  - a name of list variable with arguments to parse
#  spec       - opts spec. A dict where:
#               key - opt name (started with "-")
#               value - 0 for opt without argument
#                       1 for opt with argument
#  prms       - parameters; you don't need to specify all parameters,
#               just those that differ from the default value.
#               possible parameters:
#               stop_on_nonopts - stop on first non-option argument
#                                 1 by default
#               fail_on_unknown_opt - fail if unknown option is found
#                                 1 by default
#
# ret:
#  DICT - opts dict with opts from argslist
#
# This proc parse options in a specified _argslist.
# Every found option is removed from the list.
# Thus, after proc is finished _argslist contains only non option arguments.
# Stop on first non-option argument or after --.
# E.g.:
#  _opts_parse {-dval 0 -D 1 -t 1} "-dval -t 7 -- fname q"
#
proc _opts_parse {spec _argslist {prms {}}} {
	upvar $_argslist argslist
	set nonopts [list]
	set opts [dict create]

	set prms [dict merge {
	  stop_on_nonopt 1
	  fail_on_unknown_opt 1} $prms]

	for {set i 0} {$i < [llength $argslist]} {incr i} {
		set arg [lindex $argslist $i]
		if {$arg eq "--"} {
			incr i
			break
		}
		if {[dict exists $spec $arg]} {
			if {[dict get $spec $arg]} {
				incr i
				dict set opts $arg [lindex $argslist $i]
			} else {
				dict incr opts $arg
			}
		} else {
			if {([string index $arg 0] eq "-") &&
			    [dict get $prms fail_on_unknown_opt]} {
				error "unknown option: $arg"
			}
			if {[dict get $prms stop_on_nonopt]} {
				break
			}
			lappend nonopts $arg
		}
	}

	lappend nonopts {*}[lrange $argslist $i end]
	set argslist $nonopts

	return $opts
}

proc _parse {_ctx} {
	upvar $_ctx ctx
	set err ""
	set err_from_lineno -1
	set eprefix ""
	if {[catch {__parse ctx} res]} {
		if {[_toks_cnt ctx] > 0} {
			set err_from_lineno [_toks_lineno ctx 0]
		} elseif {$::errorCode eq "CONFERR"} {
			set err_from_lineno [dict get $ctx src lineno]
		}
		set err [list "$res" "$::errorInfo" $::errorCode]
	}
	if {[dict get $ctx src buf] ne ""} {
		if {[string index [dict get $ctx src buf] 0] eq {"}} {
			set eprefix "Possible unclosed quotes at line\
			  [dict get $ctx src lineno_tok]. "
		} else {
			set eprefix "Token input buffer:\
			  '[dict get $ctx src buf]'. "
		}
	}

	if {$err ne ""} {
		# file name and line numbers shouldn't be separated by space
#		set eaddr "conf error at\
#		  [dict get $ctx src name]:${err_from_lineno}-[dict get $ctx src lineno_tok]"
		set eaddr "conf error at\
		  [dict get $ctx src name]:${err_from_lineno}"
		set emsg [lindex $err 0]
		lset err 0 "${eaddr}: ${eprefix}$emsg"
		set emsg [lindex $err 1]
		lset err 1 "${eaddr}: ${eprefix}$emsg"

		error {*}$err
	}
}

proc __parse {_ctx} {
	upvar $_ctx ctx
	# cache a sect value
	set sect [lindex [dict get $ctx sect] end]
	set exptbl [list \
	  {"6 1 6" "=S"} \
	  {"6 9 6" "+=S"} \
	  {"6 10 6" "?=S"} \
	  {"6 1 4" "=L"} \
	  {"6 9 4" "+=L"} \
	  {"6 10 4" "?=L"} \
	  {"4 6 5" "SECT"} \
	  {"6 2" SECT_PUSH} \
	  {"3" SECT_POP} \
	  {"8 6" F}]
	set exptbl [_exptbl_compile $exptbl]

	while {[_toks_read ctx] > 0} {
		set expname [_exptbl_get_match $exptbl [dict get $ctx src toks_css]]
#		puts "DBG __parse: expname=$expname, toks_css=[dict get $ctx src toks_css]"
		switch $expname {
		"=S" {
			if {[_toks_lineno ctx 0] ==
			    [dict get $ctx src lineno_prevexp_end]} {
				error "Key name must start on new line" "" CONFERR
			}
			dict set ctx src lineno_prevexp_end [_toks_lineno_end ctx 2]
			_cb_call ctx "=S" [_toks_data ctx 0] [_toks_data ctx 2]
			_toks_rm_head ctx 3
		}
		"+=S" {
			if {[_toks_lineno ctx 0] ==
			    [dict get $ctx src lineno_prevexp_end]} {
				error "Key name must start on new line" "" CONFERR
			}
			dict set ctx src lineno_prevexp_end [_toks_lineno_end ctx 2]
			_cb_call ctx "+=S" [_toks_data ctx 0] [_toks_data ctx 2]
			_toks_rm_head ctx 3
		}
		"?=S" {
			if {[_toks_lineno ctx 0] ==
			    [dict get $ctx src lineno_prevexp_end]} {
				error "Key name must start on new line" "" CONFERR
			}
			dict set ctx src lineno_prevexp_end [_toks_lineno_end ctx 2]
			_cb_call ctx "?=S" [_toks_data ctx 0] [_toks_data ctx 2]
			_toks_rm_head ctx 3
		}
		"=L" {
			if {[_toks_lineno ctx 0] ==
			    [dict get $ctx src lineno_prevexp_end]} {
				error "Key name must start on new line" "" CONFERR
			}
			dict set ctx src lineno_prevexp_end [_toks_lineno_end ctx 2]
			set name [_toks_data ctx 0]
			_toks_rm_head ctx 3
			_cb_call ctx "=L" $name [_parse_list ctx]
		}
		"+=L" {
			if {[_toks_lineno ctx 0] ==
			    [dict get $ctx src lineno_prevexp_end]} {
				error "Key name must start on new line" "" CONFERR
			}
			dict set ctx src lineno_prevexp_end [_toks_lineno_end ctx 2]
			set name [_toks_data ctx 0]
			_toks_rm_head ctx 3
			_cb_call ctx "+=L" $name [_parse_list ctx]
		}
		"?=L" {
			if {[_toks_lineno ctx 0] ==
			    [dict get $ctx src lineno_prevexp_end]} {
				error "Key name must start on new line" "" CONFERR
			}
			dict set ctx src lineno_prevexp_end [_toks_lineno_end ctx 2]
			set name [_toks_data ctx 0]
			_toks_rm_head ctx 3
			_cb_call ctx "?=L" $name [_parse_list ctx]
		}
		SECT {
			_sect_push ctx 0 [_toks_data ctx 1]
			{*}[dict get $ctx cb] ctx "SECT_CH" [_sect_get ctx] ""
			_toks_rm_head ctx 3
#			puts "sect: [dict get $ctx sect]"
		}
		SECT_PUSH {
			_sect_push ctx 1 [_toks_data ctx 0]
			{*}[dict get $ctx cb] ctx "SECT_CH" [_sect_get ctx] ""
			_toks_rm_head ctx 2
#			puts "sect: [dict get $ctx sect]"
		}
		SECT_POP {
			_sect_pop ctx 1
			{*}[dict get $ctx cb] ctx "SECT_CH" [_sect_get ctx] ""
			_toks_rm_head ctx 1
#			puts "sect: [dict get $ctx sect]"
		}
		F {
			set fmask [_toks_data ctx 1]
			_toks_rm_head ctx 2
			_parse_file_inclusion ctx $fmask
#			puts "sect: [dict get $ctx sect]"
		}
		. {
		}
		default {
			error "Unexpected token sequence:\
			  \"[_toks_dump ctx]\". Want:\
			  KEY = VAL or KEY = \[ or GROUP_NAME \{ or \} or\
			  \[GROUP_NAME\]" "" CONFERR
		}
		}
	}

	if {[_toks_cnt ctx] > 0} {
		error "Unexpected token sequence:\
		  \"[_toks_dump ctx]\". Want:\
		  KEY = VAL or KEY = \[ or GROUP_NAME \{ or \} or\
		  \[GROUP_NAME\]" "" CONFERR
	}
}

proc _parse_list {_ctx} {
	upvar $_ctx ctx
	set list [list]
	# cache a sect value
	set sect [lindex [dict get $ctx sect] end]
	set exptbl [list \
	  {"6" S} \
	  {"4" Ls} \
	  {"5" Le}]
	set exptbl [_exptbl_compile $exptbl]

	while {[_toks_read ctx] > 0} {
		set expname [_exptbl_get_match $exptbl [dict get $ctx src toks_css]]
#		puts "DBG _parse_list: expname=$expname"
		switch $expname {
		"S" {
			lappend list [_toks_data ctx 0]
			_toks_rm_head ctx 1
		}
		"Ls" {
			_toks_rm_head ctx 1
			lappend list [_parse_list ctx]
		}
		"Le" {
			dict set ctx src lineno_prevexp_end [_toks_lineno_end ctx 0]
			_toks_rm_head ctx 1
			break
		}
		"." {
		}
		default {
			error "Unexpected token sequence:\
			  \"[_toks_dump ctx]\".\
			  Want: VAL or \[ or \]" "" CONFERR
		}
		}
	}

	return $list
}

proc _parse_file_inclusion {_ctx fmask} {
	upvar $_ctx ctx

#	puts "DBG _parse_file_inclusion: $ctx"
	set fnames [lsort [glob -directory [dict get $ctx prms -path] $fmask]]
	foreach fname $fnames {
		set fh [open $fname]
		set src [dict create\
		  name "$fname"\
		  src $fh\
		  gets_r [namespace current]::gets_from_fh]
		_ctx_src_push ctx $src
		set err ""
		if {[catch {_parse ctx} res]} {
			set err [list $res $::errorInfo $::errorCode]
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
#  cb   - a callback
#  prms - a dict with parameters:
#         -hd - hierarchy delimiter
#         -path    - a string with a default file path prefix
#         -s  - start offset for src str(only for gets_from_str)
#         -e  - last offset for src str(only for gets_from_str)
# ret:
#  context dict with keys:
#    prms - a dict with parameters
#    cb   - a specified callback
#    src  - a current source
#    srcs - a stack with sources
#    sect - a section stack(section is a hierarchy level name)
#    sect_type - a section type stack
proc _ctx_mk {cb {prms ""}} {
	set prms_def [dict create\
	  -hd ""\
	  -path "./"]
	set prms [dict merge $prms_def $prms]
	if {[string index [dict get $prms -path] end] ne "/"} {
		dict append prms -path "/"
	}

	return [dict create\
	  prms $prms\
	  cb $cb\
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
#     toks_css - a cache for _toks_head_is_match(tokens codes in one string)
proc _ctx_src_push {_ctx src} {
	upvar $_ctx ctx
	set src_def [dict create\
	  name ""\
	  gets_r ""\
	  lineno 0\
	  lineno_tok 0\
	  lineno_tok_end -1\
	  lineno_prevexp_end -1\
	  buf ""\
	  toks ""\
	  toks_css ""]

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

######################################################################
# SECTIONS ROUTINES
######################################################################
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

proc _cb_call {_ctx op kname kval} {
	upvar $_ctx ctx

	set names [_sect_get ctx]
	lappend names {*}[_mk_name ctx $kname]
	{*}[dict get $ctx cb] ctx $op $names $kval
}

proc _exptbl_compile {tbl} {
	set res [dict create]

	foreach entry $tbl {
		set key {}
		set exp [lindex $entry 0]
		set len [llength $exp]
		for {set i 0} {$i < ($len - 1)} {incr i} {
			append key "[lindex $exp $i] "
			if {![dict exists $res $key]} {
				dict set res $key "."
			} else {
				if {[dict get $res $key] ne "."} {
					error "trying to overwrite '$key' exp with '.' value (existent value is '[dict get $res $key]')"
				}
			}
		}
		append key "[lindex $exp $i] "
		if {[dict exists $res $key]} {
			error "trying to overwrite '$key' exp with '[lindex $entry 1]' value (existent value is '[dict get $res $key]')"
		}
		dict set res $key [lindex $entry 1]
	}

	return $res
}

proc _exptbl_get_match {exptbl toks_css} {
#	puts "DBG _exptbl_get_match: $exptbl $toks_css"
	set len [llength $toks_css]
	set key ""
	set exp ""
#	for {set i 0} {$i < $len} {incr i} {
#		append key "[lindex $toks_css $i 0] "
#		if {![dict exists $exptbl $key]} {
#			break
#		}
#		set exp [dict get $exptbl $key]
#	}
	if {[dict exists $exptbl "[join $toks_css " "] "]} {
		return [dict get $exptbl "[join $toks_css " "] "]
	}
	return ""
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

######################################################################
# TOKENS ROUTINES
######################################################################
proc _toks_read {_ctx} {
	upvar $_ctx ctx

	set toks ""
	# Read token
	if {[set tok [_get_tok ctx]] >= 0} {
		# Debug output
#		puts "$tok: '[dict get $ctx src tok_data]'"
		_toks_add_tail ctx [list [_tok_mk $tok [dict get $ctx src tok_data]\
		  [dict get $ctx src lineno_tok]\
		  [dict get $ctx src lineno_tok_end]]]
	}

	return $tok
}

proc _tok_mk {code data lineno lineno_end} {
	return [list $code $data $lineno $lineno_end]
}

proc _toks_add_tail {_ctx toks} {
	upvar $_ctx ctx

	set toks0 [dict get $ctx src toks]
	lappend toks0 {*}$toks
	dict set ctx src toks $toks0

	_toks_rebuild_css ctx
}

proc _toks_rm_head {_ctx cnt} {
	upvar $_ctx ctx

	incr cnt -1
	dict set ctx src toks [lreplace [dict get $ctx src toks] 0 $cnt]

	_toks_rebuild_css ctx
}

proc _toks_rebuild_css {_ctx} {
	upvar $_ctx ctx
	set toks [dict get $ctx src toks]

	# Rebuild tokens codes sequence string.
	set css ""
	set len [llength $toks]
	for {set i 0} {$i < $len} {incr i} {
		lappend css [lindex $toks $i 0]
	}
	dict set ctx src toks_css $css
}

proc _toks_head_is_match {_ctx str} {
	upvar $_ctx ctx
	set len [string length $str]

	return [string equal -length [string length $str]\
	  [dict get $ctx src toks_css] $str]
}

proc _toks_data {_ctx idx} {
	upvar $_ctx ctx

	return [lindex [dict get $ctx src toks] $idx 1]
}

proc _toks_lineno {_ctx idx} {
	upvar $_ctx ctx

	return [lindex [dict get $ctx src toks] $idx 2]
}

proc _toks_lineno_end {_ctx idx} {
	upvar $_ctx ctx

	return [lindex [dict get $ctx src toks] $idx 3]
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
			{^[ \t\r\n]+} {
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
			{^[^\]\[ \t\r\n=#"{}+?]+} {
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
		# Remove the next line to represent string with 7.
		set tok 6
	} else {
		set str [lindex $mstr 0]
	}
	dict set ctx src lineno_tok_end [dict get $ctx src lineno]
	dict set ctx src tok_data $str
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
# Escape specified value according to conf syntax rules.
# prms:
#  val  - a value to escape
# ret:
#  ESCAPED_VAL - escaped value, can be enclosed in double quotes
proc escape_value {val} {
	if {[regexp {^[^\]\[[:space:]=#"{}+?]+$} $val]} {
		return $val
	}
	return "\"[regsub -all {"} $val {\\"}]\""
}
}

package provide conf 0a20250705

