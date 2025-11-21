#!/bin/bash

conf_get()
{
	echo $1 >&${CGET[1]}
	read line <&${CGET[0]}
	echo $line
}

coproc CGET { ./conf_get.tcl ex2.conf; }
K5=`conf_get sect1.sect2.k1`
echo $K5
