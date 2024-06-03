#/usr/bin/perl -w

# usage : perl -w /path/to/this/script variable_name new_value
# will update all files containing space,var_name,= with space,var_name=new_val

use strict;

my $name = shift or die "Must provide a variable name as first argument\n";
my $val = shift or die "Must provide new value as second arg\n";

my $sys_cmd = q{grep -l -E '\s} . $name . q{\s*=' * | grep -v -E '\.bak'};
my $fil_list = `$sys_cmd`;
$fil_list =~ s/\s+/ /g;

$sys_cmd = q{perl -p -i.bak -e 's/\s} . $name . q{\s*=\s*\S+/ } . $name.'='.$val.q{/;' } . $fil_list;
system($sys_cmd);

