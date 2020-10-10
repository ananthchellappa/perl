#/usr/bin/perl -w

# generate C++ getters and setters (accessors and mutators) from text

# usage : script.pl filename [className] # writes to STDOUT
# usage : script.pl '-' [className] # reads from STDIN
# to get the declarations separated, do one run and pipe through grep declare
# and one with grep -v declare

# if a line with "class" is encountered, then the className is inferred

# examples of lines in the text (be nice. this is a min viable product :)
#   char brand[] = "";
#	int horsepower{50};

use strict;

my $insrc = shift or die "Must provide an input source - filename or use '-' for STDIN\n";

my $cname;
$cname = shift or $cname = 'className';

open( INFO, "$insrc" ) or die "Can't read from $insrc\n";
my $type; my $var1, my $var; # how else to uppercase just the first letter:)?

while( <INFO> ){
	s#//.+$##;	# get rid of line comments
	$cname = $1 if /class\h+(\S+)/;
	if( /^\h*(.+?)(\w)(\w*)(\[[^\]]*\])?(?:\{[^}]*\}\h*|\h*=.*)?;$/ ){
		$type = $1;
		$var1 = $2;
		$var = uc($2) . $3;
		print "void $var( $type $var ); // declare setter\n";
		print "$type $var(); // declare getter\n";
		
		print "void $cname"."::$var( $type $var ){ // setter\n}\n";
		print "$type $cname"."::$var(){  // getter\n}\n";
		
	}
}
