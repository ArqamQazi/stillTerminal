config_data = configuration_data()
config_data.set('GETTEXT_PACKAGE', gettext_package)
config_data.set('LOCALEDIR', get_option('prefix') / get_option('localedir'))

config_vala = configure_file(
  input: 'Config.vala.in',
  output: 'Config.vala',
  configuration: config_data
)

sources = files(
  'Constants.vala',
  'Main.vala',
  'MainWindow.vala',
  'ShortcutController.vala',
)

subdir('data')
subdir('StTerminal')
subdir('StWidgets')
subdir('StPreferences')

sources += config_vala

dependencies = [
  dependency('glib-2.0'),
  dependency('gee-0.8'),
  dependency('gobject-2.0'),
  dependency('gtk4'),
  dependency('libadwaita-1'),
  dependency('json-glib-1.0'),
  dependency('vte-2.91-gtk4', version: '>= 0.69.0'),
  dependency('libsecret-1'),

  # This is a hack to get the math library linked in
  meson.get_compiler('c').find_library('m', required : false)
]

executable(
  'still-terminal',
  sources,
  dependencies: dependencies,
  install: true
)
