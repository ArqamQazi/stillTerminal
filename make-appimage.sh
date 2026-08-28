#!/bin/sh
set -eux

ARCH="$(uname -m)"
SHARUN_URL="https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/refs/heads/main/useful-tools/quick-sharun.sh"

echo "Building still-terminal..."
echo "---------------------------------------------------------------"
rm -rf build-anyimage
meson setup build-anyimage --prefix=/usr
meson compile -C build-anyimage
meson install -C build-anyimage

# ── Get version ──────────────────────────────────────────────────────
VERSION=$(meson introspect build-anyimage --projectinfo 2>/dev/null \
    | awk -F'"' '/"version"/{print $4}')

# ── Configure AppImage ───────────────────────────────────────────────
export ARCH VERSION
export APPDIR=./build-anyimage/AppDir
export OUTPATH=./dist
export OUTNAME="stillTerminal-${VERSION}-anylinux-${ARCH}.AppImage"
export UPINFO="gh-releases-zsync|stillhq|stillterminal|latest|*anylinux*${ARCH}.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/scalable/apps/io.stillhq.terminal.svg
export DESKTOP=/usr/share/applications/io.stillhq.terminal.desktop
export ANYLINUX_LIB=1

# ── Download quick-sharun if not already available ───────────────────
if command -v quick-sharun >/dev/null 2>&1; then
    QS=quick-sharun
else
    wget --retry-connrefused --tries=30 "$SHARUN_URL" -O /tmp/quick-sharun
    chmod +x /tmp/quick-sharun
    QS=/tmp/quick-sharun
fi

# ── Bundle with quick-sharun ────────────────────────────────────────
echo "Bundling AppImage..."
echo "---------------------------------------------------------------"
"$QS" \
    /usr/bin/still-terminal \
    /usr/bin/st-distrobox

# ── Bundle nautilus extension ────────────────────────────────────────
echo "Bundling nautilus extension..."
cp nautilus/still-terminal-nautilus.py "$APPDIR/bin/"
cat << 'EOF' > "$APPDIR/bin/install-nautilus-extension.hook"
#!/bin/sh

set -e

_extension_dst=$DATADIR/nautilus-python/extensions/still-terminal-nautilus.py
if [ ! -f "$_extension_dst" ]; then
  mkdir -p "${_extension_dst%/*}"
  cp -v "$APPDIR"/bin/still-terminal-nautilus.py "$_extension_dst"
fi
EOF
chmod +x "$APPDIR/bin/install-nautilus-extension.hook"

# ── Restore toolkit locale files removed by quick-sharun debloating ──
echo "Restoring toolkit locale files..."

restore_locale_domain() {
    domain=$1
    if [ -f "po/LINGUAS" ]; then
        while IFS= read -r lang; do
            case "$lang" in \#*|"") continue ;; esac
            src="/usr/share/locale/$lang/LC_MESSAGES/$domain.mo"
            dst="$APPDIR/share/locale/$lang/LC_MESSAGES"
            if [ -f "$src" ]; then
                mkdir -p "$dst"
                cp "$src" "$dst/"
            fi
        done < po/LINGUAS
    fi
}

for domain in gtk40 glib20 libadwaita; do
    restore_locale_domain "$domain"
done

# ── Create AppImage ─────────────────────────────────────────────────
"$QS" --make-appimage

# ── Clean up intermediate artifacts ─────────────────────────────────
rm -rf "$APPDIR"

echo ""
echo "=== AnyLinux AppImage created ==="
echo "Output: $OUTPATH/$OUTNAME"

