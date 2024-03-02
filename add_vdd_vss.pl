#/usr/bin/perl -w

$fil = shift or die "Must give filename as arg1\n";
$vdd = shift or $vdd = 'vdd_3p6';
$vss = shift or $vss = 'vss';
$sub = shift or $sub = '';

open( INFO, "<$fil" ) or die "Can't open $fil for read\n";

while( <INFO> ){
	if( /^\s*\S+\s+\S+\s*\(\s*$/ ){	# something like : nand2_3p3od_1 _35_ (
		print;
		print "\t.$vdd($vdd),\n";
		print "\t.$vss($vss),\n";
		print "\t.$sub($sub),\n" if $sub;
	} else {
		$ports_to_add = ", $vdd, $vss";
		$ports_to_add .= ", $sub" if $sub;
		if( m?^\s*module? ){
			s/\);/$ports_to_add);/;
			print;
			print "\tinput $vdd;\n";
			print "\tinput $vss;\n";
			print "\tinput $sub;\n" if $sub;
		} else {
			s/\(\s*1'h1\s*\)/($vdd)/;
			s/\(\s*1'h0\s*\)/($vss)/;
			print;
		}
	}
}
