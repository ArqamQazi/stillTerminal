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
