namespace StillTerminal {
    public class MultiplexerCommand {
        public static bool is_valid_session_name (string session_name) {
            string name = session_name.strip ();
            if (name == "") {
                return true;
            }
            if (name[0] == '-') {
                return false;
            }

            for (int i = 0; i < name.length; i++) {
                char c = name[i];
                bool valid = (
                    (c >= 'a' && c <= 'z')
                    || (c >= 'A' && c <= 'Z')
                    || (c >= '0' && c <= '9')
                    || c == '_'
                    || c == '-'
                );
                if (!valid) {
                    return false;
                }
            }
            return true;
        }

        public static string[]? build (
            string multiplexer,
            string session_name
        ) {
            string program = multiplexer.strip ().ascii_down ();
            string session = session_name.strip ();
            if (!is_valid_session_name (session)) {
                return null;
            }

            switch (program) {
                case "screen":
                    return session == ""
                        ? new string[] { "screen" }
                        : new string[] {
                            "screen", "-D", "-RR", "-S", session
                        };
                case "tmux":
                    return session == ""
                        ? new string[] { "tmux" }
                        : new string[] {
                            "tmux", "new-session", "-A", "-s", session
                        };
                case "zellij":
                    return session == ""
                        ? new string[] { "zellij" }
                        : new string[] {
                            "zellij", "attach", "--create", session
                        };
                default:
                    return null;
            }
        }
    }
}
