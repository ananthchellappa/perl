#!/usr/bin/perl -w

use POSIX qw(strftime);
use Time::HiRes qw(time);

# we use ~/.wmdb and anything older than 7 days is purged using cron job
# for the cron-job, $ crontab -e  # and then
# 0 5 * * * ~/perl/wmdb_flush.pl ~/.wmdb 
# every day at 5 AM, run that script

$left_display_width = 1920; # width of single display. used to check if there are more than one display
$db = $ENV{HOME} . "/.wmdb";

# we assume display width must be > $left_display_width to qualify as a dual-monitor system
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

if( $diswid < $left_display_width ){
    # system( "echo $diswid >> /tmp/wm.log");
    system( "wmctrl -r :ACTIVE: -b toggle,maximized_vert;wmctrl -r :ACTIVE: -b toggle,maximized_horz" );
    exit(0);
}

$wid = `xdotool getactivewindow`; chomp($wid);

foreach(split "\n", `xwininfo -id $wid`) {
    if(/^\s*(.+?):\s*(.+?)\s*$/){
        if    ($1 eq "Absolute upper-left X") { $x = $2 }
        elsif ($1 eq "Absolute upper-left Y") { $y = $2 }
        elsif ($1 eq "Width") { $W = $2 }
        elsif ($1 eq "Height") { $H = $2 }
    }
}

$sx = 0; $sy = 0; $sw = 0; $sh = 0; $saved = 0;

if (open(DB, "<$db")) {
    @db = <DB>;
    close DB;

    foreach my $line (@db) {
        chomp $line;
        my ($swid, $dt, $x, $y, $w, $h) = split ',', $line;

        next if $wid != $swid;

        $sx = $x; $sy = $y; $sw = $w; $sh = $h;
        $saved = 1;
    }
}
else {
    @db = ();
}

sub set_dimensions($$$$) {
    my ($x, $y, $w, $h) = @_;
    system("wmctrl -r :ACTIVE: -e 0,$x,$y,$w,$h");
}

sub store_dimensions($$$$) {
    my ($x,$y,$W,$H) = @_;
    my $date = strftime "%D",localtime;

    $mid = $x + ($W / 2);
    $x -= $swid if $mid >= $swid;

    if (open(DB, ">$db")) {
        foreach (@db) {
            print DB "$_\n" unless /^$wid,/;
        }
        print DB "$wid,$date,$x,$y,$W,$H\n";
        close DB;
    }
}

sub maxcheck( ){
# int, int, int, int, int, int -> 0,1,2
    if( $y < 100 && abs($dishei - $H) < 120 && abs($W - $swid ) < 120){
        if( $x < 30 ){
            return 1; # that's screen 1 - the left guy
        } elsif( abs($x - $swid ) < 30 ){
            return 2;
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

if( $cmd eq 'toggle' ){
    # is it maximized already?
    $screen = &maxcheck( $diswid,$dishei,$x,$y,$W,$H);
    if( $screen ){
        # restore
        $mid = $x + ($W / 2);
        $screen = $mid >= $swid ? 2 : 1;

        if( $saved ){
            $x = ($screen - 1)*$swid + $sx;
            set_dimensions($x,$sy,$sw,$sh);
        } else {
            $x = ($screen - 1)*$swid;
            $y = 0;
            $W = $diswid / 4;
            $H = $dishei / 2;
            set_dimensions($x,$y,$W,$H);
        }
    } else {
        # maximize
        if( $x + ($W / 2) > $swid ){
            set_dimensions($swid,0,$swid,$dishei);
        } else {
            set_dimensions(0,0,$swid,$dishei);
        }
        store_dimensions($x,$y,$W,$H);
    }
}

if( $cmd eq 'throw' ){
    # maximize
    $mid = $x + ($W / 2);
    if( $mid >= $swid ){
        set_dimensions(0, 0, $swid, $dishei);
    } else {
        set_dimensions($swid,0,$swid,$dishei);
    }

    if( !$saved ){
        store_dimensions($x,$y,$W,$H);
    }
}
