#!/bin/bash
set -e

echo "==> Enabling bootc usr-overlay..."
bootc usr-overlay || true
dnf install -y meson ninja-build vala gcc glib2-devel gobject-introspection-devel libgee-devel gtk4-devel libadwaita-devel json-glib-devel vte291-gtk4-devel libsecret-devel desktop-file-utils libappstream-glib

echo "==> Configuring build with meson..."
if [ -d "build" ]; then
    rm -rf build
fi
meson setup build --prefix=/usr

echo "==> Building stillTerminal..."
meson compile -C build

echo "==> Installing stillTerminal system-wide..."
sudo meson install -C build

echo "==> Compiling GSettings schemas..."
sudo /usr/bin/glib-compile-schemas /usr/share/glib-2.0/schemas || true

echo "==> Installation complete!"
echo "==> You can now run: still-terminal"
