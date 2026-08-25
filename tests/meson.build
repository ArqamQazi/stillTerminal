launch_request_source = configure_file(
  input: '../src/LaunchRequest.vala',
  output: 'LaunchRequest.vala',
  copy: true,
)

launch_request_test = executable(
  'launch-request-test',
  [
    launch_request_source,
    'LaunchRequestTest.vala',
  ],
  dependencies: [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
  ],
)

test('launch request parsing', launch_request_test)
test(
  'gnome-terminal compatibility translation',
  find_program('test-gnome-terminal-compat.sh'),
)
test(
  'RPM gnome-terminal compatibility subpackage',
  find_program('test-spec-gnome-terminal-compat.sh'),
)
