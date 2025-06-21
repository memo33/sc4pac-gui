#!/bin/bash
# For Linux: Reverts installation of sc4pac-gui.
set -e
if [ $(id -u) -eq 0 ]; then
    echo "Do not run this script as root."
    exit 1
fi

echo "Deleting binary from PATH:"
sudo rm --force --verbose /usr/local/bin/sc4pac-gui

echo "Deleting sc4pac-gui.desktop file:"
rm --force --verbose ~/.local/share/applications/sc4pac-gui.desktop

echo "Deleting icon:"
rm --force --verbose ~/.local/share/icons/sc4pac-gui.png

echo 'Uninstall complete.'
