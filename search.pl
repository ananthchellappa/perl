#!/usr/bin/perl -w

# usage : search.pl <filename> string1 [-[wW] word1] [-[aAbBC] N_context] [-t[ype]] pl] [-t[ype]] py] [-c]

# A,B,C - same as grep - after, before, context - print N_context lines before,after or both.. :)
# if multiple -A,B,C specified, C will override. Note that C has to be uppercase for context
# because -c is for case sensitivity (i.e., if -c is specified, the match is case sensitive)
# -type or -t, is collective - more -types specified will just add on.. and only search files of that extension..

# MO : read one file at a time.. build grepout intelligently using the context option

use strict;
use Term::ANSIColor qw(:constants);

my $file; my @regex = (); my $buf; my $context; my $N; my @lines;
my $good; # boolean
my $word;	# for iterating through regex match items
my $type_regex = ''; my $N_after = 0; my $N_before = 0; my $count; my $grepout; my $case = '(?i)';
my $state = 'before';	# used by the context-string-builder state-machine. 'before', 'matched', 'after'
my @before = ();
my $home = `echo \$HOME`; chomp($home);

$file = shift or die "Arg1 must be filename (which contains list of full pathnames)\n";
die "Can't find the file specified\n" unless -e $file;

while (@ARGV) {
	$_ = shift;
	if( /-w$/i ){
		$buf = shift or die "-w specified, but no word\n";
		push @regex ,  '\b' . $buf . '\b';
	} elsif( /-a$/i ){
		$N_after = shift or die "-$_ specified, but not number of lines\n";
	} elsif( /-b$/i ){
		$N_before = shift or die "-$_ specified, but not number of lines\n";
	} elsif( /-C$/ ){
		$N_after = shift or die "-$_ specified, but not number of lines\n";
		$N_before = $N_after;
	} elsif( /-t(ype)?/i ){
		if( $type_regex eq '' ){
			$type_regex = shift or die "-$_ specified, but not file-extension\n";
		} else {
			$type_regex .= '|' . shift or die "-$_ specified, but not file-extension\n";
		}
	} elsif( /-c$/ ){
		$case = '';
	}
	else {
		push @regex , $_;
	}
}

$count = $N_before;
$type_regex = '\.(' . $type_regex . ')$' unless $type_regex eq '';
open( INFO, $file );

while( $file = <INFO>){
    next unless $file =~ /\S/;
	$grepout = '';
	$file =~ s/~/$home/;
	if( $type_regex ne '' ){
		next unless $file =~ /$type_regex/;
	}
    chomp $file;

    open( DATA, $file);
    while( <DATA> ){
        $good = 1;
        foreach $word ( @regex ){
            if( !(/$case$word/) ){
                $good = 0;
                last;
            }
        }
		if( $good ){	# you got a match - that's one event we look for (!match is also an event..)
			$count = $N_after;	# always reset this if you get a match
			if( 'before' eq $state ){
				$grepout .= join( "", @before);	# dump $before into the output
				@before = ();	# reset
				$state = 'matched';
			} elsif ( 'after' eq $state ) {
				$state = 'matched';
			}
			$buf = $_;
			foreach $word ( @regex ){
 			    $buf =~ /$case^(.*?)($word)(.*?)$/;
				$buf = $1 . GREEN . BOLD . $2 . RESET . $3;
 			}
			$grepout .= $buf . "\n";
		} else {
			if( 'before' eq $state ){
				if( $N_before ){ # user wants this
					if( @before and 0==$count ){ # if we're at length-max, then swap out..
						shift @before;
					}
					push @before, $_ ;
					$count-- if $count;
				}
			} elsif( 'matched' eq $state ){
				if( $N_after ){
					$state = 'after';
					$grepout .= $_ and $count-- if $count;
				} else {
					$state = 'before';
					$count = $N_before;
				}
			} else { #'after'
				$grepout .= $_ and $count-- if $count;
				unless( $count ){
					$state = 'before';
					$count = $N_before;
					push @before, $_ ;		# violating DRY :(
					$count-- if $count;
				}
			}
		} # else
    }	# while <DATA>
    close DATA;
	
    unless ($grepout eq ''){
		print UNDERLINE, "\n$file\n", RESET;
		print "\n$grepout" unless length($grepout) > 2000;
    }
}

print "\nDONE!\n";
