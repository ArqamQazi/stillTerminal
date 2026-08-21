#!/bin/bash
set -e

echo "==> Attempting to uninstall stillTerminal..."

if [ -d "build" ] && [ -f "build/build.ninja" ]; then
    echo "==> Found build directory. Using ninja to uninstall..."
    sudo ninja uninstall -C build || echo "Ninja uninstall failed, falling back to manual removal..."
else
    echo "==> Build directory not found. Removing files manually..."
    
    sudo rm -f /usr/bin/still-terminal
    sudo rm -f /usr/bin/st-distrobox
    sudo rm -rf /usr/share/stillTerminal/
    sudo rm -f /usr/share/applications/io.stillhq.terminal.desktop
    sudo rm -f /usr/share/glib-2.0/schemas/io.stillhq.terminal.gschema.xml
    sudo rm -f /usr/share/icons/hicolor/scalable/apps/io.stillhq.terminal.svg
    sudo rm -f /usr/share/nautilus-python/extensions/still-terminal-nautilus.py
fi

echo "==> Recompiling GSettings schemas..."
sudo /usr/bin/glib-compile-schemas /usr/share/glib-2.0/schemas || true

echo "==> Removing build directory..."
rm -rf build

echo "==> Uninstallation complete!"
echo "Note: The development packages installed via dnf (meson, vala, etc.) were kept intact."
echo "If you want to remove them, run:"
echo "sudo dnf remove meson ninja-build vala gcc glib2-devel gobject-introspection-devel libgee-devel gtk4-devel libadwaita-devel json-glib-devel vte291-gtk4-devel libsecret-devel desktop-file-utils libappstream-glib"
echo ""
echo "Note: The 'bootc usr-overlay' applied during installation remains active until your next reboot."
