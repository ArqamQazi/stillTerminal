gnome = import('gnome')

sources += gnome.compile_resources('resources',
  'io.stillhq.terminal.gresource.xml',
  c_name: 'resources'
)

# Install built-in color schemes to themes directory
install_data([
  '../../data/schemes/Adwaita.json',
  '../../data/schemes/AlmaLinux.json',
  '../../data/schemes/Alpine.json',
  '../../data/schemes/Arch.json',
  '../../data/schemes/CentOS.json',
  '../../data/schemes/Debian.json',
  '../../data/schemes/Fedora.json',
  '../../data/schemes/OpenSUSE.json',
  '../../data/schemes/RedHat.json',
  '../../data/schemes/Rocky.json',
  '../../data/schemes/Ubuntu.json'
], install_dir: get_option('datadir') / 'stillTerminal' / 'themes')
