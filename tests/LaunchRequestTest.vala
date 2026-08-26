private void assert_argv (string[]? actual, string[] expected) {
    assert (actual != null);
    assert (actual.length == expected.length);
    for (int i = 0; i < expected.length; i++) {
        assert (actual[i] == expected[i]);
    }
}

private void test_modern_command_preserves_arguments () {
    string[] invocation = {
        "still-terminal", "sh", "-c", "printf '%s\\n' \"$HOME\""
    };
    try {
        var command = StillTerminal.LaunchRequest.parse_command (null, invocation);
        assert_argv (command, { "sh", "-c", "printf '%s\\n' \"$HOME\"" });
    } catch (Error e) {
        assert_not_reached ();
    }
}

private void test_legacy_command_uses_glib_shell_parser () {
    string[] invocation = { "still-terminal" };
    try {
        var command = StillTerminal.LaunchRequest.parse_command (
            "python3 -c 'print(\"hello world\")'", invocation
        );
        assert_argv (command, { "python3", "-c", "print(\"hello world\")" });
    } catch (Error e) {
        assert_not_reached ();
    }
}

private void test_command_forms_are_mutually_exclusive () {
    string[] invocation = { "still-terminal", "printf", "ok" };
    try {
        StillTerminal.LaunchRequest.parse_command ("true", invocation);
        assert_not_reached ();
    } catch (StillTerminal.LaunchRequestError e) {
        assert (e is StillTerminal.LaunchRequestError.CONFLICTING_COMMANDS);
    } catch (Error e) {
        assert_not_reached ();
    }
}

private void test_relative_working_directory_uses_invoking_cwd () {
    assert (StillTerminal.LaunchRequest.resolve_working_directory (
        "project", "/home/test"
    ) == "/home/test/project");
    assert (StillTerminal.LaunchRequest.resolve_working_directory (
        "/srv/project", "/home/test"
    ) == "/srv/project");
}

private void test_command_override_disables_profile_environment () {
    string[] command = { "env" };
    assert (!StillTerminal.LaunchRequest.use_profile_environment (command));
    assert (StillTerminal.LaunchRequest.use_profile_environment (null));
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/launch-request/modern-command", test_modern_command_preserves_arguments);
    Test.add_func ("/launch-request/legacy-command", test_legacy_command_uses_glib_shell_parser);
    Test.add_func ("/launch-request/conflicting-commands", test_command_forms_are_mutually_exclusive);
    Test.add_func ("/launch-request/relative-working-directory", test_relative_working_directory_uses_invoking_cwd);
    Test.add_func ("/launch-request/command-environment", test_command_override_disables_profile_environment);
    return Test.run ();
}
