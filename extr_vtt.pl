#!/usr/bin/perl
#usage ./script.pl 1:06:1 1

package Chunk;

use strict;
use warnings;


sub toSeconds {
	my ($date) = shift;

	my ($h, $m, $s, $ms) = $date =~ /(\d{1,2}):(\d{1,2}):(\d{1,2})\.(\d+)/;

	return (int($h) * 3600 + int($m) * 60 + int($s) + int($ms) * 0.001);
}

sub parse {
	my ($dates) = shift;

	my ($startDate, $endDate) = $dates =~ /(\S+) --> (\S+)/;

	return (
		startDate => $startDate,
		endDate => $endDate,
		minSeconds => toSeconds($startDate),
		maxSeconds => toSeconds($endDate)
	);
}

sub new {
	my ($class, @lines) = @_;
	my ($dates) = shift @lines;

	my $self = {
		dates => $dates,
		lines => \@lines,
		parse($dates)
	};

	return bless $self, $class;
}

1;

package Chunks;
use strict;
use warnings;

sub new {
	my ($class, $minSeconds, $maxSeconds) = @_;

	return bless {
		chunks => [],
		minSeconds => $minSeconds,
		maxSeconds => $maxSeconds
	 }, $class;
}

sub add {
	my ($self, $chunk) = @_;

	if ($chunk->{minSeconds} < $self->{minSeconds} || $chunk->{maxSeconds} > $self->{maxSeconds}) {
		return;
	}

	push(@{$self->{chunks}}, $chunk);

	return 1;
};

sub clear {
	my ($self) = @_;
	$self->{chunks} = [];
}

sub lines {
	my ($self) = @_;
	my $len = scalar(@{$self->{chunks}});

	return "" if ($len == 0);

	my (@lines) = ();
	for my $chunk (@{$self->{chunks}}) {
		push(@lines, $chunk->{dates});
		push(@lines, @{$chunk->{lines}});
	}

	return join("", @lines);
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

my $fileName = shift;
my $time = shift;
my $duration = shift;

sub parseArguments {
	if ($time !~ /^\d{1,2}:\d{1,2}:\d{1,2}$/) {
		die("Invalid time $time; valid format  Hour:Min:Sec");
	}

	my ($sign, $interval) = $duration =~ /^([+-]?)(.*)$/;
	$interval = int(60 * $interval);

	my $timeSec = Chunk::toSeconds("00:${time}.000");

	my $minSeconds = $timeSec;
	my $maxSeconds = $timeSec;

	if ($sign eq "+") {
		$maxSeconds = $timeSec + $interval;
	}
	elsif ($sign eq "-") {
		$minSeconds = $timeSec > $interval ? ($timeSec - $interval) : 0;
	}
	else {
		$minSeconds = $timeSec > $interval ? ($timeSec - $interval) : 0;
		$maxSeconds = $timeSec + $interval;	
	}

	debug("time: $timeSec; interval: $interval; min $minSeconds; max $maxSeconds");
	
	return ($minSeconds, $maxSeconds);
}

sub main  {
	my ($minSeconds, $maxSeconds) = parseArguments();

	open(my $fh, "<", $fileName) || die("Could not read $fileName $!");
	
	my @chunkLines = ();
	my $chunks = Chunks->new($minSeconds, $maxSeconds);
	my $start = 0;

	while (my $line = <$fh>) {
		if ($line =~ /^\d\d:\d\d:\d\d/) {
			$start = 1;
			if (scalar(@chunkLines) > 0) {
				my $chunk = Chunk->new(@chunkLines);
				@chunkLines = ();

				$chunks->add($chunk);
			}
		}

		if (!$start) {
			next;
		}

		push(@chunkLines, $line);
	}

	if (scalar(@chunkLines) > 0) {
		my $chunk = Chunk->new(@chunkLines);
		$chunks->add($chunk);
	}

	close($fh);

	print $chunks->lines();

	# print Dumper $chunks;
}

eval {
	main();
};
