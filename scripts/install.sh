#!/bin/bash
# For Linux:
# Links sc4pac-gui binary into path, configures it as desktop application and sets up handler for `sc4pac://` URLs.
set -e
if [ $(id -u) -eq 0 ]; then
    echo "Do not run this script as root."
    exit 1
fi

echo "Linking binary into PATH:"
sudo ln --force --verbose --symbolic "$(realpath ./sc4pac-gui)" /usr/local/bin/sc4pac-gui

echo "Installing sc4pac-gui.desktop file:"
mkdir -p ~/.local/share/applications/
ln --force --verbose --symbolic "$(realpath ./sc4pac-gui.desktop)" ~/.local/share/applications/

echo "Installing icon:"
mkdir -p ~/.local/share/icons/
cp -p --force --verbose ./sc4pac-gui.png ~/.local/share/icons/

echo "Registing new sc4pac MIME type."
xdg-mime default sc4pac-gui.desktop x-scheme-handler/sc4pac

echo 'Installation complete. You can test it by running:'
echo ''
echo '  xdg-open "sc4pac:///package?pkg=memo:submenus-dll"'
echo ''
