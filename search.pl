#!/usr/bin/perl

# work of Ivan Bessarabov
# do search.pl -help to list options
# put something like
# function search() { ~/perl/search.pl -l ~/logs/textfiles.txt $@ ; }
# to be able to search your logs with $ > search words to search for

use strict;
use warnings;
use feature qw(say);

use Term::ANSIColor qw(:constants colored);

my $option_descriptions = [

    { names => [qw(-f -file)], key => 'files', is_multi => 1, help => 'File to search for matches' },
    { names => [qw(-l -list)], key => 'list_files', is_multi => 1, help => 'File with file names to search' },
    { names => [qw(-t -type)], key => 'types', is_multi => 1, help => 'Only files with this extension will be searched' },

    { names => [qw(-b -B)], key => 'before', value_check => '[0-9]+', help => 'How many lines to show before matched line' },
    { names => [qw(-a -A)], key => 'after', value_check => '[0-9]+', help => 'How many lines to show after matched line' },
    { names => [qw(-C)], key => '_context', value_check => '[0-9]+', help => 'How many lines to show before and after matched line (if specified, this option will override -B and -A)' },

    { names => [qw(-c)], key => 'case_sensitive', is_bool => 1, help => 'By default the search is case insentitive. With this option the search is case sentitive'},

    { names => [qw(-w -W)], key => 'words', is_multi => 1, help => 'This is similar to word-portions except that we look for a word delimited by non-word characters' },
    { names => [qw(-e -exclude)], key => 'exclude_word_portions', is_multi => 1, help => 'Only lines that does not match this word-portion will be used' },
    { names => [qw(-ew -excludeword)], key => 'exclude_words', is_multi => 1, help => 'The same as -e, but with respect to word boundaries' },
    { names => [qw(-o -order)], key => 'ordered_word_portions', is_multi => 1, help => 'Only match lines that has this word-portions in exact same order' },

    { names => [qw(-h -help --help)], key => 'help', is_bool => 1, help => 'Show this message' },
    { names => [qw(-d -dont)], key => 'dont_suppress', is_bool => 1, help => "Don't suppress large output" },

];
# AC added -dont

sub get_options {
    my (@argv) = @_;

    my $options = {
        list_files => [],
        files => [],

        # file extensions
        types => [],

        before => 0,
        after => 0,

        # default is 'case insentitive'
        case_sensitive => 0,

        word_portions => [],
        words => [],

        exclude_word_portions => [],
        exclude_words => [],

        ordered_word_portions => [],

        help => 0,
	dont_suppress => 0,
    };

    my %option_descriptions_hash;
    foreach my $description (@{$option_descriptions}) {
        foreach my $name (@{$description->{names}}) {
            $option_descriptions_hash{$name} = $description;
        }
    }

    while (@argv) {
        my $argv = shift @argv;
        if (exists($option_descriptions_hash{$argv})) {
            my $description = $option_descriptions_hash{$argv};

            if ($description->{is_bool}) {
                $options->{$description->{key}} = 1;
            } else {
                my $value = shift(@argv);

                if (not defined $value) {
                    show_error_and_exit("Missing value for option $argv");
                }

                if (exists $description->{value_check}) {
                    if ($value !~ /$description->{value_check}/) {
                        show_error_and_exit("Invalid value for option $argv");
                    }
                }

                if ($description->{is_multi}) {
                    push (@{$options->{$description->{key}}}, $value);
                } else {
                    $options->{$description->{key}} = $value;
                }
            }

        } else {
            push (@{$options->{word_portions}}, $argv);
        }
    }

    if (exists($options->{_context})) {
        $options->{before} = $options->{_context};
        $options->{after} = $options->{_context};
    }

    foreach my $key (keys %{$options}) {
        delete $options->{$key} if $key =~ /^_/;
    }

    return $options;
}

sub get_help {
    my $help;

    $help .= "\n";
    $help .= "Usage:\n";
    $help .= "\n";
    $help .= "    $0 [ -file FILE_NAME ] [ -list LIST_FILE_NAME ] word-portion word-portion... OPTIONS";
    $help .= "\n";
    $help .= "\n";
    $help .= "Options:\n";
    $help .= "\n";

    foreach my $o (@{$option_descriptions}) {
        $help .= "  " . join(" ", @{$o->{names}}) . ' - ' . ($o->{help} // '') . "\n";
    }

    $help .= "\n";

    return $help;
}

sub get_files {
    my (%h) = @_;

    my @list_files = @{delete $h{list_files}};
    my @files = @{delete $h{files}};
    my %types = map { '.' . $_ => 1 } @{delete $h{types}};

    my @all_files;

    foreach my $f (@list_files) {

        check_is_valid_file($f);

        open(my $fh, "<", $f) or die "Can't open < $f $!";
        while (my $line = <$fh>) {
            chomp($line);

            next if $line =~ /^\s*$/;
            next if $line =~ /^\s*#/;

            # expand ~ to user $HOME
            if ($line =~ /^~/) {
                $line =~ s/^~(.*)/$ENV{HOME}$1/;
            }

            check_is_valid_file($line);

            push @all_files, $line;
        }
    }

    foreach my $f (@files) {
        check_is_valid_file($f);
        push @all_files, $f;
    }

    foreach my $f (@all_files) {
        if (!-e $f) {
            show_error_and_exit("File $f does not exist");
        }

        if (-d $f) {
            show_error_and_exit("$f is a directory");
        }
    }

    if (%types) {
        my @filtered_files;
        foreach my $f (@all_files) {
            foreach my $extension (keys %types) {
                if ($extension eq substr($f, -length($extension))) {
                    push @filtered_files, $f;
                }
            }
        }

        return @filtered_files;
    }

    return @all_files;
}

sub get_rules {
    my ($options) = @_;

    my $rules = {
        should_match => [], # this is used not only for match, but for coloring output
        should_not_match => [],
        case => ($options->{case_sensitive} ? '' : '(?i)'),
        additional_should_match => [],
    };

    foreach my $el (@{$options->{word_portions}}) {
        push @{$rules->{should_match}}, $el;
    }

    foreach my $el (@{$options->{words}}) {
        push @{$rules->{should_match}}, '\b'. $el . '\b';
    }

    foreach my $el (@{$options->{exclude_word_portions}}) {
        push @{$rules->{should_not_match}}, $el;
    }

    foreach my $el (@{$options->{exclude_words}}) {
        push @{$rules->{should_not_match}}, '\b'. $el . '\b';
    }

    foreach my $el (@{$options->{ordered_word_portions}}) {
        my @elements = split / +/, $el;

        if (@elements < 2) {
            show_error_and_exit("Invalid value for order. There should be at least 2 parts separated by space");
        }

        foreach my $el (@elements) {
            push @{$rules->{should_match}}, $el;
        }

        push @{$rules->{additional_should_match}}, join(".*", @elements);

    }

    return $rules;
}

sub is_line_needed {
    my ($line, $rules) = @_;

    my $is_line_needed = 1;
    my $formatted_line;

    foreach my $el (@{$rules->{should_match}}) {
        if ($line !~ /$rules->{case}$el/) {
            $is_line_needed = 0;
            last;
        }
    }

    if ($is_line_needed) {
        foreach my $el (@{$rules->{additional_should_match}}) {
            if ($line !~ /$rules->{case}$el/) {
                $is_line_needed = 0;
                last;
            }
        }
    }

    if ($is_line_needed) {
        foreach my $el (@{$rules->{should_not_match}}) {
            if ($line =~ /$rules->{case}$el/) {
                $is_line_needed = 0;
                last;
            }
        }
    }

    if ($is_line_needed) {
        foreach my $el (@{$rules->{should_match}}) {
            $line =~ /$rules->{case}(.*?)($el)(.*?)\z/;
            $line = $1 . GREEN . BOLD . $2 . RESET . $3;
        }
    }

    return ($is_line_needed, $line);
}

sub show_error_and_exit {
    my ($message) = @_;

    die "\n" . colored("Error. $message", 'red') . "\n\n";
}

sub check_is_valid_file {
    my ($file_name) = @_;

    if (!-e $file_name) {
        show_error_and_exit("File $file_name does not exist");
    }

    if (-d $file_name) {
        show_error_and_exit("$file_name is a directory");
    }
}

sub main {

    my $options = get_options(@_);

    if ($options->{help}) {
        print get_help();
        exit();
    }

    my @files = get_files(
        list_files => $options->{list_files},
        files => $options->{files},
        types => $options->{types},
    );

    if (@files == 0) {
        show_error_and_exit("No files specified. Use `-file FILE_NAME` or `-list LIST_FILE_NAME`");
    }

    my $rules = get_rules($options);

    foreach my $file_name (@files) {

        my @lines_before;
        my $lines_after_count;

        my $output = '';

        open(my $fh, "<", $file_name) or die "Can't open < $file_name $!";
        while (my $line = <$fh>) {
            chomp($line);
            my ($is_line_needed, $formatted_line) = is_line_needed($line, $rules);

            if ($is_line_needed) {
                foreach my $l (@lines_before) {
                    $output .= $l . "\n";
                }

                $output .= $formatted_line . "\n";

                @lines_before = ();
                $lines_after_count = 0;
            } else {
                if ($options->{before} > 0) {
                    push @lines_before, $line;
                    if (@lines_before > $options->{before}) {
                        shift @lines_before;
                    }
                }
                $lines_after_count++ if defined $lines_after_count;
            }

            if (!$is_line_needed && defined($lines_after_count) && $lines_after_count <= $options->{after}) {
                $output .= $line . "\n";
            }
        }

        if ($output ne '') {
            print UNDERLINE, "\n$file_name\n", RESET;
			if ($options->{dont_suppress} || length($output) <= 2000 || $output =~ /\h(?:the|and)\h/ ) { #AC
				print "\n$output";
			} else {
				print "\n" . colored('Skipping the output, because it is too big.', 'yellow') . "\n";
			}
        }

    }

    print "\nDONE!\n";
}

main(@ARGV) if not caller();
1;
