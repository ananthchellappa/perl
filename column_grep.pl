#!/usr/bin/perl -w

# by Tymur Kladko
# 
#usage  script.pl file [options] [criterion1 [options] criterion2 criterion3 ..]
# ./column_grep.pl -noh test_mk_xlsm.csv  -i corner "=~" "/ff.*1$/i" D ">=" "781" Point ">=" 1
# ./column_grep.pl -l "<" 0 test_mk_xlsm.csv
# ./column_grep.pl -l "=" "NaN"  test_mk_xlsm.csv
# ./column_grep.pl -noh test_mk_xlsm.csv  -i corner "=~" "/ff.*1$/i" D ">=" "781" Point ">=" 1 Point "=~" "s/T/F/gk" Corner "=~" 's/.*/| $& |/' Point "=~" 's/0+/Zero/'

package Criteria;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

my @operands = qw(= == < > <= >= != =~ !~);

my $matchSubs = {
	"=" => sub {
		my ($val, $match) = @_;

		return looks_like_number($val) if ($match eq "NaN");

		return $val == $match if (looks_like_number($val) && looks_like_number($match));
		return $val eq $match;
	},
	">" => sub {
		my ($val, $match) = @_;
		return $val > $match if (looks_like_number($val) && looks_like_number($match));
		return $val gt $match;
	},
	">=" => sub {
		my ($val, $match) = @_;
		return $val >= $match if (looks_like_number($val) && looks_like_number($match));
		return $val ge $match;
	},
	"=~" => sub {
		my ($val, $pattern, $flags) = @_;

		my $regex = eval { qr/(?$flags)$pattern/ };
		return $val =~ m/$regex/ ? 1 : undef;
	}
};
$matchSubs->{"=="} = sub { return   $matchSubs->{"="}->(@_);  };
$matchSubs->{"!="} = sub { return ! $matchSubs->{"="}->(@_);  };
$matchSubs->{"<"}  = sub { return ! $matchSubs->{">="}->(@_); };
$matchSubs->{"<="} = sub { return ! $matchSubs->{">"}->(@_);  };
$matchSubs->{"!~"} = sub { return ! $matchSubs->{"=~"}->(@_); };

sub new {
	my ($class, $criteria) = @_;

	if ($criteria->{op} =~ /~/) {
		if ($criteria->{operand} =~ /^s\//) {
			my ($s, $search, $replace, $flags) = split("/", $criteria->{operand});
			$criteria->{search} = $search || "";
			$criteria->{replace} = $replace || "";
			$criteria->{isReplace} = 1;
			$flags = $flags || "";
			$criteria->{keep} = $flags =~ s/k//g;
			$criteria->{flags} = $flags;
		}
		else {
			$criteria->{pattern} = $criteria->{operand};
			$criteria->{flags} = "";
			if ($criteria->{operand} =~ /^([\/#]).*\1/) {
				my ($ch, $pattern, $flags) = $criteria->{operand} =~ /^([\/#])(.*)\1(\w+)?$/;
				$criteria->{pattern} = $pattern if ($pattern);
				$criteria->{flags} = $flags if ($flags);
			}
		}
	}

	return bless $criteria, $class;
}

sub setColumn {
	my ($self, $column) = @_;
	$self->{column} = $column;

	return $self;
}

sub isReplace {
	my $self = shift;
	return $self->{isReplace} || undef;
}

sub isKeep {
	my $self = shift;
	return $self->{keep} || undef;
}

sub validate {
	my ($self, @columns) = @_;

	if (! grep { $self->{op} eq $_ } @operands ) {
		return (undef, "Invalid operand $self->{op}; valid: @operands");
	}

	my $isI = $self->{"-i"} || undef;
	my @match = $isI ?
		grep { lc($_) eq lc($self->{column}) } @columns :
		grep { $_ eq $self->{column} } @columns;
	return (undef, "Column \"$self->{column}\" does not exist (would -i help out? ;-)\n") if (!@match);	
	return (undef, "Column $self->{column} is matched with columns: "
		. join(",", @match)) if (scalar(@match) > 1);	

	return (1, "") if ($self->isReplace());

	if ($self->{op} =~ /~/) {
		my $pattern = $self->{pattern};
		my $flags = $self->{flags};
		eval { qr/(?$flags)$pattern/ };
		return (undef, "Pattern $self->{operand} error: $@") if $@;
	}

	return (1, "");
}

sub replace {
	my ($self, $row) = @_;

	my $column = lc($self->{column});
	my $val = $row->{ lc($self->{column}) };

	my $replace = $self->{replace};
	my $search = $self->{search};
	my $flags = $self->{flags};

	local $_ = $val;
	my $sub = eval " sub { s/$search/$replace/$flags } ";
	my $res;
	eval { $res = $sub->() };

	$row->{ lc($self->{column}) } = $_;
	return $res;
}

sub isMatch {
	my ($self, $row) = @_;
	my $column = lc($self->{column});
	return undef if (!exists($row->{$column}));

	if ($self->{op} =~ /~/) {
		return $matchSubs->{$self->{op}}->($row->{$column}, $self->{pattern}, $self->{flags});
	}
	return $matchSubs->{$self->{op}}->($row->{$column}, $self->{operand});
}

1;

package main;

use strict;
use warnings;

use Data::Dumper;
use constant DEBUG => 0;

sub debug {
	print STDERR "DEBUG: @_\n" if DEBUG;
}

sub readArguments {

	my %args = ();
	my $fileName = "";
	my @criterions = ();

	my ($endArguments, $foundFile, %criteria, $startGlob);
	foreach my $arg (@ARGV) {
		if (!$startGlob && $arg eq "-l") {
			$args{$arg} = 1;
			$criteria{column} = "*";
			$startGlob = 1;
			next;
		}

		if ($startGlob && !exists($criteria{op})) {
			$criteria{op} = $arg;
			next;
		}	

		if ($startGlob && !exists($criteria{operand})) {
			$criteria{operand} = $arg;
			push(@criterions, Criteria->new({ %criteria }));
			next;
		}	

		if (!$endArguments && $arg =~ /^-/) {
			$args{$arg} = 1;
			next;
		}
		$endArguments = 1;

		if (!$foundFile) {
			$fileName = $arg;
			$foundFile = 1;
			next;
		}

		if (!$startGlob && $endArguments && $foundFile) {
			if ($arg =~ /^-/) {
				$criteria{$arg} = 1;
				next;
			}

			if (!exists($criteria{column})) {
				$criteria{column} = $arg;
				next;
			}
			if (!exists($criteria{op})) {
				$criteria{op} = $arg;
				next;
			}
			if (!exists($criteria{operand})) {
				$criteria{operand} = $arg;

				push(@criterions, Criteria->new({ %criteria }));
				%criteria = ();
			}
		}
	}

	return (\%args, $fileName, \@criterions);
}

sub readHeader {
	my $fh = shift;

	my @preHeader = ();
	my $header;

	while (my $line = <$fh>) {
		chomp($line);

		my @columns = split(",", $line);
		my @numColumns = grep(/^\d+$/, @columns);
		my @nonEmpty = grep { length($_) > 0 } @columns;	

		if (scalar(@columns) == scalar(@nonEmpty)
			&& scalar(@numColumns) <= 1)
		{
			$header = $line;
			last;
		}
		push(@preHeader, $line);
	}

	return (join("\n", @preHeader), $header);
}

sub showHelp {
	my $error = shift;

	print "ERROR: $error\n" if ($error);
	print "Usage: ./script.pl [-l operator operand] [-noh] [-v] [-help] file [ [option] column-name operator operand ...]\n";
	print "\t-help - show this help (optional)\n";
	print "\t-noh - hide prehader (optional)\n";
	print "\t-v - similar to grep's -v - omit rows that matched (optional)\n";
	print "\t-l - show only matched columns (similar to grep's -l)\n";
	print "\t-i - the next supplied column-name will be used in case-insensitive fashion\n";
	print "\tfile - file name (required)\n";
	print "\t operators supported (use quotes to hide from shell) : = (or ==), !=, =~, !~, <,>\n";
	print "\t operands supported (use quotes) : regular expression (when operator is =~ or !~, (PCRE)\n";
	print "\t\t /regex/opts -- if options are supplied (else no need for / / )\n";
	print "\t\t #regex#opts -- if it is desirable the the regex contain /\n";
	print "\t\t s/regex/substituion/opts -- full fledged perl compatible subsitution\n";
	print "\t\t\t note that for subsitution, /k is supported - that is \"keep\" - normally, the operator\n";
	print "\t\t\t (just like Perl) will return non-zero only if a match occurred. With /k you always return 1\n";
	print "\t\t NaN -- non-numeric -- not the traditional NaN, but similar :)\n";
	print "\t\t\t Eg. -l = NaN    will list the names of columns that contain ANY numeric data\n";
	print "\t\t\t Eg. -l '!=' NaN   will list the names of columns that contain ANY non-numeric data\n";
	

	exit;
}

sub showGlobReport {
	my ($fileName, $criterions) = @_;

	open(my $fh, "<", $fileName) || showHelp("Open $fileName error: $!");

	my $criteriaObj = shift(@$criterions) || undef;
	showHelp("Invalid header match arguments") if (!$criteriaObj);

	my ($isValid, $error) = $criteriaObj->validate("*");
	showHelp($error) if (!$isValid);

	my ($preHeader, $header) = readHeader($fh);
	debug("Header: \n", $header);

	my (@columns) = split(",", $header);
	my (%matchedColumns) = ();

	while (my $line = <$fh>) {
		chomp($line);
		next if (! $line);

		my %row = ();
		@row{ map(lc, @columns) } = split(",", $line);

		foreach my $column (@columns) {
			next if (exists($matchedColumns{$column}));
			if ($criteriaObj->setColumn($column)->isMatch(\%row)) {
				$matchedColumns{$column} = 1;
			}
		}
	}
	close($fh);

	print join(" ", keys(%matchedColumns)) || "No matched columns";
	print "\n";
}

sub main {
	my ($args, $fileName, $criterions) = readArguments();
	debug("Arguments: " . Dumper $args);
	debug("FileName: $fileName");
	debug("Criterions: ", Dumper $criterions);

	my $isHelp   = $args->{"-help"} || "";
	my $isInvert = $args->{"-v"}    || "";
	my $isNoh    = $args->{"-noh"}  || "";
	my $isGlob   = $args->{"-l"}    || "";

	showHelp if $isHelp;
	return showGlobReport($fileName, $criterions) if $isGlob;	

	open(my $fh, "<", $fileName) || showHelp("Open $fileName error: $!");

	my ($preHeader, $header) = readHeader($fh);
	debug("PreHeader: \n", $preHeader);
	debug("Header: \n", $header);

	my (@columns) = split(",", $header);

	# validate
	my @errors = ();
	foreach my $criteriaObj (@$criterions) {
		my ($isValid, $error) = $criteriaObj->validate(@columns);
		push(@errors, $error) if (! $isValid);
	}
	showHelp(join("\n", @errors)) if (@errors);

	debug("\nStart report\n");
	print "$preHeader\n" if (! $isNoh);
	print "$header\n";

	if (scalar(@$criterions) == 0) {
		close($fh);
		return;
	};

	while (my $line = <$fh>) {
		chomp($line);
		next if (! $line);

		my %row = ();
		@row{ map(lc, @columns) } = split(",", $line);

		# filter lines
		my $isShow = 1;
		foreach my $criteriaObj (@$criterions) {
			next if $criteriaObj->isReplace();
			my $isMatch = $criteriaObj->isMatch(\%row);
			if (! $isMatch) {
				$isShow = undef;
				last;
			}
		}

		next unless ($isShow || ($isInvert && !$isShow));

		# replace lines
		$isShow = 1;
		foreach my $criteriaObj (@$criterions) {
			next if (! $criteriaObj->isReplace());
			my ($replaced) = $criteriaObj->replace(\%row);

			if (!$replaced && !$criteriaObj->isKeep()) {
				$isShow = undef;
				last;
			}
		}

		if ($isShow) {
			my @newLine = ();
			push(@newLine, $row{$_}) for (map(lc, @columns));
			print join(",", @newLine) . "\n";
		}
		# print "$line\n" if $isShow;
	}

	close($fh);
}

eval {
	main();
};

print "Fatal: $@\n" if $@;

1;
