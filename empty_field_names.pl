#!/usr/bin/perl -w

# usage : script.pl filename [separator] (default is comma)

# just uses 2nd line of the file to report the names of the empty fields

use List::MoreUtils qw( indexes first_index );

$file = shift or die "Must specify filename as arg 1\n";
die "Can't read $file\n" unless -e $file;
$sep = shift or $sep = ',';

open( INFO, "$file" );

$_ = <INFO>;
@fields = split( /$sep/ );

$_ = <INFO>;
@values = split( /$sep/ );

@empties = indexes { $_ eq '' } @values;

$i = 0;
for $field ( @fields ) {
	print "$field " unless -1 == first_index {$_ == $i } @empties;
	$i++;
}
