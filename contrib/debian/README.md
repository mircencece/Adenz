
Debian
====================
This directory contains files used to package dnzd/dnz-qt
for Debian-based Linux systems. If you compile dnzd/dnz-qt yourself, there are some useful files here.

## dnz: URI support ##


dnz-qt.desktop  (Gnome / Open Desktop)
To install:

	sudo desktop-file-install dnz-qt.desktop
	sudo update-desktop-database

If you build yourself, you will either need to modify the paths in
the .desktop file or copy or symlink your dnzqt binary to `/usr/bin`
and the `../../share/pixmaps/dnz128.png` to `/usr/share/pixmaps`

dnz-qt.protocol (KDE)

