#!/usr/bin/perl -w

# usage : $> perl -w to_eng.pl infile.csv > infile_eng.csv

use strict;
use Number::FormatEng qw(:all);
use File::Spec::Functions qw(rel2abs);
use Scalar::Util qw( looks_like_number ); 

my @fields; my $field; my $i; # counter
while( <> ){
	@fields = split /,/;
	$i = 0;
	foreach $field ( @fields ) {
		if( looks_like_number( $field ) ) {
			$field = format_pref( $field );
		}
		print $field;
		unless( $i == $#fields ){	# last one
			print ",";
		}
		$i++;
	}
}
