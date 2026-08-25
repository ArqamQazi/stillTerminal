gnome = import('gnome')

sources += gnome.compile_resources('resources',
  'io.stillhq.terminal.gresource.xml',
  c_name: 'resources'
)

schema = 'io.stillhq.terminal.gschema.xml'

# Install GSchema
install_data(schema,
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

# Install desktop file
i18n.merge_file(
  input: 'io.stillhq.terminal.desktop.in',
  output: 'io.stillhq.terminal.desktop',
  type: 'desktop',
  po_dir: meson.project_source_root() / 'po',
  install: true,
  install_dir: get_option('datadir') / 'applications'
)

install_data('../../data/io.stillhq.terminal.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
)

# Install built-in color schemes to themes directory
install_data([
  '../../data/schemes/Adwaita.json',
  '../../data/schemes/AlmaLinux.json',
  '../../data/schemes/Alpine.json',
  '../../data/schemes/Arch.json',
  '../../data/schemes/Catppuccin.json',
  '../../data/schemes/CentOS.json',
  '../../data/schemes/Debian.json',
  '../../data/schemes/Fedora.json',
  '../../data/schemes/Gruvbox.json',
  '../../data/schemes/Hacker.json',
  '../../data/schemes/Nord.json',
  '../../data/schemes/OpenSUSE.json',
  '../../data/schemes/RedHat.json',
  '../../data/schemes/Rocky.json',
  '../../data/schemes/TokyoNight.json',
  '../../data/schemes/Ubuntu.json'
], install_dir: get_option('datadir') / 'stillTerminal' / 'themes')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
