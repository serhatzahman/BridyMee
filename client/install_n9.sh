#!/bin/sh
# BridyMee Installer for Nokia N9 (MeeGo 1.2 Harmattan)
set -e

echo "=== Installing BridyMee on Nokia N9 ==="
APP_DIR="/home/user/apps/wp"
mkdir -p "$APP_DIR/icons"

cp wp.py main.qml "$APP_DIR/"
cp icons/*.png "$APP_DIR/icons/"

# Copy system icon to Harmattan theme and hicolor directories
mkdir -p /usr/share/icons/hicolor/80x80/apps/
mkdir -p /usr/share/icons/hicolor/64x64/apps/
mkdir -p /usr/share/themes/blanco/meegotouch/icons/
mkdir -p /usr/share/themes/base/meegotouch/icons/

cp icons/bridymee.png /usr/share/icons/hicolor/80x80/apps/bridymee.png
cp icons/bridymee.png /usr/share/icons/hicolor/64x64/apps/bridymee.png
cp icons/bridymee.png /usr/share/themes/blanco/meegotouch/icons/bridymee.png
cp icons/bridymee.png /usr/share/themes/base/meegotouch/icons/bridymee.png

# Set permissions for unprivileged 'user' account
chown -R user:users "$APP_DIR"
chmod -R a+rX "$APP_DIR"

# Install Desktop file
cp bridymee.desktop /usr/share/applications/bridymee.desktop
chmod 644 /usr/share/applications/bridymee.desktop
touch /usr/share/applications/

# Refresh MeeGo Home grid
killall -9 mhome 2>/dev/null || true

echo "=== Installation Finished Successfully! ==="
echo "You can now launch BridyMee from the N9 Application Menu."
