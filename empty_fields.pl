#!/usr/bin/perl -w

# usage : script.pl filename [separator] (default is comma)

# just uses 2nd line of the file to report the indexes (yes, first is 0) of the empty fields

use List::MoreUtils qw( indexes );

$file = shift or die "Must specify filename as arg 1\n";
die "Can't read $file\n" unless -e $file;
$sep = shift or $sep = ',';

open( INFO, "$file" );

<INFO>;
$_ = <INFO>;

@fields = split( /$sep/ );

@empties = indexes { $_ eq '' } @fields;

print "@empties\n";
