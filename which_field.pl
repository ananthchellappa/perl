#!/usr/bin/perl -w

# usage : script.pl filename string  --> assumes separator is space
# usage : script.pl filename string , --> specifies separator is comma
# usage : script.pl '-' string  --> specifies STDIN as the input file - use for pipes
# NOTE that string only needs to be CONTAINED in the field - not match it completely
# note first field returns 1, not 0 :)
# 0 indicates that no field contains specified string

use List::MoreUtils qw( first_index );

$inp = shift or die "must specify input source as arg 1\n";
$string = shift or die "2nd arg must be the string of interest\n";
$sep = shift or $sep = ' '; # space is default

open( INFO , "$inp") or die "Can't open $inp. Please check\n";

$_ = <INFO>; # gets it into $_

@fields = split( /$sep/ );

print 1 + first_index { -1 != index $_ , $string } @fields;
print "\n";
