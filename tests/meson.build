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

multiplexer_command_source = configure_file(
  input: '../src/MultiplexerCommand.vala',
  output: 'MultiplexerCommand.vala',
  copy: true,
)

multiplexer_command_test = executable(
  'multiplexer-command-test',
  [
    multiplexer_command_source,
    'MultiplexerCommandTest.vala',
  ],
  dependencies: [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
  ],
)

test('multiplexer command construction', multiplexer_command_test)

profile_source = configure_file(
  input: '../src/StTerminal/StProfile.vala',
  output: 'StProfile.vala',
  copy: true,
)

multiplexer_profile_test = executable(
  'multiplexer-profile-test',
  [
    multiplexer_command_source,
    profile_source,
    'MultiplexerProfileTest.vala',
  ],
  dependencies: [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
)

test('multiplexer profile integration', multiplexer_profile_test)

new_tab_button_policy_source = configure_file(
  input: '../src/NewTabButtonPolicy.vala',
  output: 'NewTabButtonPolicy.vala',
  copy: true,
)

new_tab_button_policy_test = executable(
  'new-tab-button-policy-test',
  [
    new_tab_button_policy_source,
    'NewTabButtonPolicyTest.vala',
  ],
  dependencies: [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
  ],
)

test('new tab button policy', new_tab_button_policy_test)
