# perl

WIP collection of useful utilities. The column-grep (CSV) is the best. Check it out!

bash $ search word1 word2 etc # is enabled through : function search() { /path/to/search.pl /path/to/textfiles.txt $@ ; } # in your ~/.bashrc

The wm.pl and wmdb_flush.pl also are indispensible at my end - giving true dual-monitor experience when you're on VNC with two monitors. VNC doesn't understand dual monitors - it thinks there is just one large display, so, if you use the native shortcuts to maximize windows, they'll blow up to take up the entire (both monitors) display.

Once you have these scripts, just `wm.pl` without arguments (that is, bind this to a keyboard shortcut on GNOME such as ALT+1) will maximize/restore (i.e. toggle) the window to use one monitor (assuming both monitors are equal size :) and `wm.pl throw` can be used to throw (and maximize simultaneously) to the other monitor. VERY HANDY!
