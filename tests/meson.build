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
