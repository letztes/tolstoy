tolstoy
=======

Converts a website from bad desktop html layout to good, mobile device friendly html layout.

The layout is optimized for Samsung Galaxy S2.

The website in question is a digitalized version of volume 10 from L.N.Tolstoys complete works in 22 volumes. Before conversion the website has to be fetched for instance via wget -rl1 http://rvb.ru/tolstoy/tocvol_10.htm

tolstoy.pl and tolstoy.tt then have to be placed into the resulting top directory tolstoy. I recommend to install a webserver for purposes of local testing, but it is not necessary. Anyhow, the user that executes the script has to have write access to the directory /var/www/ where the converted files are written to.

The directories and filenames are hardcoded in the script, but with few changes the script may be applicable for the other volumes too.
