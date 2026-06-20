Name:           still-terminal
Version:        10.2.0
Release:        1%{?dist}
Summary:        A tabbed terminal emulator for stillOS

License:        GPL-3.0-or-later
URL:            https://gitlab.com/stillhq/stillTerminal/
Source0:        https://gitlab.com/stillhq/stillTerminal/-/archive/main/stillTerminal-main.tar.gz

BuildRequires:  meson >= 0.56.0
BuildRequires:  ninja-build
BuildRequires:  vala
BuildRequires:  gcc
BuildRequires:  pkgconfig(glib-2.0)
BuildRequires:  pkgconfig(gobject-2.0)
BuildRequires:  pkgconfig(gee-0.8)
BuildRequires:  pkgconfig(gtk4)
BuildRequires:  pkgconfig(libadwaita-1)
BuildRequires:  pkgconfig(json-glib-1.0)
BuildRequires:  pkgconfig(vte-2.91-gtk4) >= 0.69.0
BuildRequires:  pkgconfig(libsecret-1)
BuildRequires:  desktop-file-utils
BuildRequires:  libappstream-glib

Requires:       gtk4
Requires:       libadwaita
Requires:       vte291-gtk4 >= 0.69.0
Requires:       libsecret
Requires:       libgee
Requires:       json-glib
Requires:       sshpass

%description
stillTerminal is a modern tabbed terminal emulator built for stillOS.
It features custom themes and profiles, with support for SSH
and distrobox container integration.

%prep
%autosetup -n stillTerminal-main

%build
%meson
%meson_build

%install
%meson_install
# Nautilus extension (for still-terminal-nautilus subpackage)
install -Dm644 nautilus/still-terminal-nautilus.py %{buildroot}%{_datadir}/nautilus-python/extensions/still-terminal-nautilus.py

%files
%doc README.md
%{_bindir}/still-terminal
%{_bindir}/st-distrobox
%{_datadir}/stillTerminal/
%{_datadir}/applications/io.stillhq.terminal.desktop
%{_datadir}/glib-2.0/schemas/io.stillhq.terminal.gschema.xml
%{_datadir}/icons/hicolor/scalable/apps/io.stillhq.terminal.svg

%post
/usr/bin/glib-compile-schemas %{_datadir}/glib-2.0/schemas &> /dev/null || :

%postun
/usr/bin/glib-compile-schemas %{_datadir}/glib-2.0/schemas &> /dev/null || :

%package nautilus
Summary:        Nautilus extension for stillTerminal
BuildArch:      noarch
Requires:       still-terminal = %{version}-%{release}
Requires:       nautilus-python

%description nautilus
Nautilus extension that adds "Open in stillTerminal" to the context menu
when right-clicking on a folder or the background of a folder.

%files nautilus
%{_datadir}/nautilus-python/extensions/still-terminal-nautilus.py

%changelog
* Sun Oct 04 2025 Cameron <cameron@stillhq.io> - 0.0.1-1
- Initial RPM release
