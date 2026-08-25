project(
    'stillTerminal',
    'vala',
    'c',
    version: '10.2.0',
    default_options: ['warning_level=2'],
)

gettext_package = 'io.stillhq.terminal'
i18n = import('i18n')

add_project_arguments(['--enable-experimental'], language: 'vala')
add_project_arguments('-DGETTEXT_PACKAGE="@0@"'.format(gettext_package), language: 'c')

subdir('src')
subdir('st-distrobox')
subdir('compat')
subdir('po')
subdir('tests')
