Overview
=======
conf package contains 3 main routines for text configuration file loading:
* conf::load_from_file - to load a conf from a file
* conf::load_from_fh - to load a conf from an open file handler
* conf::load_from_str - to load a conf from a string

Each routine returns a parsed conf as a dict. Single word/string value is
saved into this dict as a list with one element. Thus every value is a
list(with one or more elements). On error an exception is thrown.

Synopsis
========
```
  load_from_file [-hd STR] [-default DICT] FILE_NAME
  load_from_fh [-hd STR] [-default DICT] CHAN
  load_from_str [-hd STR] [-default DICT] [-s START_INDEX] [-e END_INDEX] CONF_STR
  get_key CAS NAME [TYPE]
```

Where parameters:
  -hd
      use STR as hierarchy delimiter in key names and group names("." by default)
  -default DICT
      use DICT as an initial(default) conf.
  -s
      start parsing of a string from specified position(in chars)
  -e
      end parsing of a string at specified position(in chars); this will be
      the last character we read

Conf syntax
===========
Conf consists from key-value pairs, which can be grouped in sections.
Whitespaces are ignored. Comment can be started by # symbols at almost any
place(excluding # inside a quoted string). Key, value and section name can
consist of any chars exclude any space chars, '=', '#', '"', '[', ']', '{',
'}', '+', '?'. If a key, value or section name contains any of these
characters, then the entire key, value or section name must be enclosed in
double quotes.
In this case, if double quotes appears inside the value, it must be escaped
with a backslash(\).

Conf file can include another conf files with syntax:

< FILENAME

Where FILENAME is glob pattern.

ABNF of conf syntax:
```
conf = *(key-value / group / include-stmt / WSP0)
key-value = key "=" (value / list)
key = word / str
value = word / str
list = WSP0 "[" *((word / str / list) WSP) "]"
group = ("[" (word / str) "]" *conf) /
        ((word / str) "{" *conf "}")
include-stmt = "<" WSP0 word
word = WSP0 (%d33 / %d36-60 / %d62-90 / %d92 / %d94-122 / %d124 / %d126 - %d255) WSP0
        ; all except any space (belong to [:space:] char class), =, #, ",
        ; [, ], {, }
str = WSP0 DQUOTE %d01-%d255 DQUOTE WSP0
        ; any chars in double quotes, where double quotes inside string
        ; can be escaped with \ char
WSP0 = *WSP
WSP = SP / HTAB / CR / LF / CRLF / AND_ANY_UNICODE_WHITESPACE_CHAR
```

Sections
--------
A parser context contains a default section prefix for keys, which we can
change. Thus we shouldn't prepend every key with a section name, if we
specify a needed section prefix before. E.g. instead of:

```
sect1.sect2.key1 = val1
sect1.sect2.key2 = val2
sect1.sect2.sect3.key3 = val3
sect1.sect2.key4 = val4
...
```

we can write:

```
[sect1.sect2]
key1 = val1
key2 = val2
sect3.key3 = val3
key4 = val4
...
```

or:

```
[sect1.sect2]
key1 = val1
key2 = val2
[sect1.sect2.sect3]
key3 = val3
[sect1.sect2]
key4 = val4
...
````

If a section is defined with `[SECT_NAME]` syntax, then current section
prefix(top of a section prefixes stack) is replaced with SECT\_NAME. If a
section is defined with `SECT_NAME {` syntax, then SECT\_NAME section
prefix is pushed to a section prefixes stack and becomes a current section
prefix until we reach corresponding "}", in which case SECT\_NAME is poped
from a section prefixes stack and previous value becomes a top of a stack
and a current section prefix. E.g. conf example above can be written as:

```
sect1.sect2 {
	key1 = val1
	key2 = val2
	sect3 {
		key3 = val3
	}
	key4 = val4
}
```

This 2 method of section definition can be used together in one conf, if you
are bored.

Examples
========
Simple conf
-----------
```
k1=v1
k2="val
with
many
lines"
k3 =
	"val with \" inside"
k4 = [
	[many values]
	[inside list]
	[for one key]]
```
loaded with `load_from_file my.conf` returns:

```
k1 v1 k2 {val
with
many
lines} k3 {val with " inside} k4 {{many values} {inside list} {for one key}}
```

Conf with sections
------------------
```
k1 = v1
[g1]
k2 = v2
[g2]
k3 = v3
```
loaded with `load_from_file my.conf` returns:

k1 v1 g1 {k2 v2} g2 {k3 v3}

Conf with nested sections
-------------------------
```
k1 = v1
g1 {
  k2 = v2
  g2 {
    k3 = v3
  }
}
```
loaded with `load_from_file my.conf` returns:

k1 v1 g1 {k2 v2 g2 {k3 v3}}

Conf with hierarchy delimiter specified
---------------------------------------
```
g1.k1 = {1 2 3 {4 5}}
g2.k2 = v2
```
loaded with `load_from_file -hd . my.conf` returns:

g1 {k1 {1 2 3 {4 5}}} g2 {k2 v2}

Conf monster
------------
```
g1.k1 = [1 2 3 [4 5]]
[g2]
k2 = v2
k3.k4 = v3
[g2.g3]
k4 = v4
g4.g5 {
  k5.k6 = v6
  [g7.g8]
  k7.k8 = v7
}
```
loaded with `load_from_file -hd . my.conf` returns:

g1 {k1 {1 2 3 {4 5}}} g2 {k2 v2 k3 {k4 v3} g3 {k4 v4}} g4 {g5 {k5 {k6 v6} g7 {g8 {k7 {k8 v7}}}}}


Conf with comments
------------------
```
# here is some comments
k = v
k1 = v1 # another comments
k2 = v2
k3 = # this is k3
        v3 # this is k3 value
k4 = "v4 with # inside"
# end of file
```
loaded with `load_from_file -hd . my.conf` returns:

k v k1 v1 k2 v2 k3 v3 k4 {v4 with # inside}

Errors
======

* conf lines: from 3 to 3
	missing value to go with key

	You try to assign a group to a existent key with a non-group value.
	E.g.:
	```
	k1 = v1
	[k1]
	k2 = v2
	```

* parse error at 1 line: unexpected token sequence at 1 line: 'k2'#6(L1) 'v2'#6(L1)
 want: KEY = VAL or KEY = { or GROUP_NAME { or } or [GROUP_NAME]

	There is parser error at line 1 for token sequence started at line 1.
	First token is 'k2' at line 1 (6 - is a token code, you don't need it),
	second token is 'v2' at line 1. E.g.:
	```
	k2 v2
	```

* parse error at 1 line: unexpected token sequence at 1 line: 'k2'#6(L1) '='#1(L1)
 want: KEY = VAL or KEY = { or GROUP_NAME { or } or [GROUP_NAME]
possible unclosed quotes at 1 line

	Double quotes is opened, but is not closed. E.g.:
	```
	k2 = "v2
	```
