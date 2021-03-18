#!/usr/bin/perl -w -ni.bak
BEGIN{
$date = ‘date +%s‘;
}
if( /"\d+. (\d+) ./ ){
print if $date - $1 < 7*86400;
} else {
print;
}
