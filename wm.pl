#!/usr/bin/perl -w

# we use ~/.wmdb and anything older than 7 days is purged using cron job
# for the cron-job, $ crontab -e  # and then
# 0 5 * * * ~/perl/wmdb_flush.pl ~/.wmdb 
# every day at 5 AM, run that script

# we assume display width must be > 2000 to qualify as a dual-monitor system
$cmd = shift or $cmd = 'toggle';
if( $cmd ne 'throw' ){
	$cmd = 'toggle';
}

# if not dual monitor, then concept of throwing doesn't arise, so just exit..
# telling wmctrl to do the job of toggling..
$_ = `xdotool getdisplaygeometry`; chomp;
# system( "echo $_ >> /tmp/wm.log");
exit(1) if $_ eq '';

($diswid,$dishei) = split;
$swid = $diswid >> 1; # screen width
$date = `date +%D`; chomp $date;
if( $diswid < 2000 ){
	# system( "echo $diswid >> /tmp/wm.log");
	system( "wmctrl -r :ACTIVE: -b toggle,maximized_vert;wmctrl -r :ACTIVE: -b toggle,maximized_horz" );
	exit(0);
}
$wid = `xdotool getactivewindow`; chomp($Wid);

$sys_cmd = "xwininfo -id $wid " . q{ | perl -n -e 'print if s/^.+?left [XY]:\s+(\d+)\s*\n/$1 / || s/(Height:|Width:)\s*(\d+)\s*\n/$2/;'};
$_ = `$sys_cmd`;
($abx,$aby,$rx,$ry,$W,$H) = split( /\s+/ );
$x = $abx - $rx;
$y = $aby - $ry;

if( $cmd eq 'toggle' ){
	# is it maximized already?
	$screen = &maxcheck( $diswid,$dishei,$x,$y,$W,$H);
	if( $screen ){
		# restore
			# ~/.wmdb will have ID,time-stamp,x,y,w,H
			$_ = `grep $wid ~/.wmdb`; # since we used xdotool, no need to worry about hex
			if( /^\d+,[^.]+,(\d+),(\d+),(\d+),(\d+)/ ){
			system("wmctrl -r :ACTIVE: -e 0,$1,$2,$3,$4");
			system("perl -ni -e 'print unless /^$wid,/;' ~/.wmdb");
			system("echo $wid,$date,$1,$2,$3,$4 >> ~/.wmdb");
		} else {
			$x = ($screen - 1)*$swid;
			$y = 0;
			$W = $diswid >> 2;
			$H = $dishei >> 1;
			system("wmctrl -r :ACTIVE: -e 0,$x,$y,$w,$H");
			system("echo $wid,$date,$x,$y,$w,$H >> ~/.wmdb");
		}
	} else {
	# maximize
		if( $x - $swid > 0 || ($x << 1) + $W > $diswid ){
			system("wmctrl -r :ACTIVE: -e 0,$swid,0,$swid,$dishei");
		} else {
			system("wmctrl -r :ACTIVE: -e 0,0,0,$swid,$dishei");
		}
		system("perl -ni -e 'print unless /^$wid,/;' ~/.wmdb");
		system("echo $wid,$date,$x,$y,$w,$H >> ~/.wmdb");
	}
}

if( $cmd eq 'throw' ){
	# maximize
	$screen = &maxcheck( $diswid,$dishei,$x,$y,$W,$H);
	if( $x - $swid >= 0 || ($x << 1) + $W >= $diswid ){
		$screen = 2;
		system("wmctrl -r :ACTIVE: -e 0,0,0,$swid,$dishei");
	} else {
		$screen = 1;
		system("wmctrl -r :ACTIVE: -e 0,$swid,0,$swid,$dishei");
	}
	# ~/.wmdb will have ID,time-stamp,x,y,w,H
	$_ = `grep $wid ~/.wmdb`; # since we used xdotool, no need to worry about hex
	if( /"\d+.[",]+.(\d+).(\d+).(\d+).(\d+)/ ){
		system("perl -ni -e 'print unless /^$wid,/;' ~/.wmdb");
		$x = $1 + $swid*(3-2*$screen);
		system("echo $wid,$date,$x,$2,$3,$4 >> ~/.wmdb");
	} else {
		system("perl -ni -e 'print unless /^$wid,/;' ~/.wmdb");
		$x += $swid*(3-2*$screen);
		system("echo $wid,$date,$x,$y,$W,$H >> ~/.wmdb");
	}
}

sub maxcheck( ){
# int, int, int, int, int, int -> 0,1,2
	if( $y < 100 && ($dishei - $H) < 120 && abs($W - $swid ) < 20){
		if( $x < 20 ){
			return 1; # that's screen 1 - the left guy
		} elsif( abs($x - $swid ) < 20 ){
			return 2;
		} else {
			return 0;
		}
	} else {
		return 0;
	}
}
