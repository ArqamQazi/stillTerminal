namespace StillTerminal.Tests {
    private void assert_argv (string[] expected, string[] actual) {
        assert (actual != null);
        assert (actual.length == expected.length);
        for (int i = 0; i < expected.length; i++) {
            assert_cmpstr (actual[i], CompareOperator.EQ, expected[i]);
        }
    }

    private void test_tmux_without_session () {
        assert_argv ({ "tmux" }, MultiplexerCommand.build ("tmux", ""));
    }

    private void test_tmux_named_session () {
        assert_argv (
            { "tmux", "new-session", "-A", "-s", "work" },
            MultiplexerCommand.build ("tmux", "work")
        );
    }

    private void test_screen_without_session () {
        assert_argv ({ "screen" }, MultiplexerCommand.build ("screen", ""));
    }

    private void test_screen_named_session () {
        assert_argv (
            { "screen", "-D", "-RR", "-S", "work" },
            MultiplexerCommand.build ("screen", "work")
        );
    }

    private void test_zellij_without_session () {
        assert_argv ({ "zellij" }, MultiplexerCommand.build ("zellij", ""));
    }

    private void test_zellij_named_session () {
        assert_argv (
            { "zellij", "attach", "--create", "work" },
            MultiplexerCommand.build ("zellij", "work")
        );
    }

    private void test_unknown_multiplexer_is_rejected () {
        assert (MultiplexerCommand.build ("other", "work") == null);
    }

    private void test_unsafe_session_names_are_rejected () {
        assert (!MultiplexerCommand.is_valid_session_name ("-work"));
        assert (!MultiplexerCommand.is_valid_session_name ("work space"));
        assert (!MultiplexerCommand.is_valid_session_name ("work;touch-pwned"));
        assert (MultiplexerCommand.build ("tmux", "work;touch-pwned") == null);
    }

    private void test_safe_session_names_are_accepted () {
        assert (MultiplexerCommand.is_valid_session_name (""));
        assert (MultiplexerCommand.is_valid_session_name ("work-2_test"));
    }

    public static int main (string[] args) {
        Test.init (ref args);
        Test.add_func ("/multiplexer/tmux-without-session", test_tmux_without_session);
        Test.add_func ("/multiplexer/tmux-named-session", test_tmux_named_session);
        Test.add_func ("/multiplexer/screen-without-session", test_screen_without_session);
        Test.add_func ("/multiplexer/screen-named-session", test_screen_named_session);
        Test.add_func ("/multiplexer/zellij-without-session", test_zellij_without_session);
        Test.add_func ("/multiplexer/zellij-named-session", test_zellij_named_session);
        Test.add_func ("/multiplexer/unknown-is-rejected", test_unknown_multiplexer_is_rejected);
        Test.add_func ("/multiplexer/unsafe-session-names-are-rejected", test_unsafe_session_names_are_rejected);
        Test.add_func ("/multiplexer/safe-session-names-are-accepted", test_safe_session_names_are_accepted);
        return Test.run ();
    }
}
