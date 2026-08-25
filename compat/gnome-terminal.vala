namespace GnomeTerminalCompat {
    private void print_help () {
        stdout.printf ("Usage: gnome-terminal [OPTION...] [-- PROGRAM [ARG...]]\n");
        stdout.printf ("\n");
        stdout.printf ("Compatibility launcher for stillTerminal.\n");
        stdout.printf ("\n");
        stdout.printf ("Supported options:\n");
        stdout.printf ("  --window, --tab                 Open a stillTerminal window\n");
        stdout.printf ("  --working-directory=DIR, -w DIR\n");
        stdout.printf ("                                  Set the initial working directory\n");
        stdout.printf ("  --title=TITLE, -t TITLE         Set the initial terminal title\n");
        stdout.printf ("  --zoom=FACTOR                   Set the terminal zoom factor\n");
        stdout.printf ("  --full-screen                   Open the window fullscreen\n");
        stdout.printf ("  -e, --command=COMMAND           Execute a command string (deprecated)\n");
        stdout.printf ("  -x, --execute PROGRAM [ARG...]  Execute a command (deprecated)\n");
        stdout.printf ("  -- PROGRAM [ARG...]             Execute a command\n");
        stdout.printf ("  -q, --quiet                     Suppress compatibility warnings\n");
        stdout.printf ("  -h, --help                      Show this help\n");
    }

    private int missing_value (string option) {
        stderr.printf (
            "gnome-terminal compatibility: option requires a value: %s\n",
            option
        );
        return 2;
    }

    private int unsupported (string option) {
        stderr.printf (
            "gnome-terminal compatibility: option is not supported: %s\n",
            option
        );
        return 2;
    }

    private string? option_value (
        ref int index,
        string[] arguments
    ) {
        int equals_position = arguments[index].index_of_char ('=');
        if (equals_position >= 0) {
            return arguments[index].substring (equals_position + 1);
        }

        if (index + 1 >= arguments.length) {
            return null;
        }

        index++;
        return arguments[index];
    }

    public int main (string[] arguments) {
        string[] translated = { "still-terminal" };
        bool quiet = false;

        for (int index = 1; index < arguments.length; index++) {
            string argument = arguments[index];

            if (argument == "--" || argument == "-x" || argument == "--execute") {
                if (index + 1 >= arguments.length) {
                    return missing_value (argument);
                }

                translated += "--";
                while (++index < arguments.length) {
                    translated += arguments[index];
                }
                break;
            }

            if (argument == "-h" || argument == "--help"
                || argument == "--help-all" || argument == "--help-terminal"
                || argument == "--help-terminal-options"
                || argument == "--help-window-options") {
                print_help ();
                return 0;
            }

            if (argument == "-q" || argument == "--quiet") {
                quiet = true;
                continue;
            }

            if (argument == "--window" || argument == "--tab"
                || argument == "--active") {
                continue;
            }

            if (argument == "--full-screen") {
                translated += "--fullscreen";
                continue;
            }

            if (argument == "-w" || argument == "--working-directory"
                || argument.has_prefix ("--working-directory=")) {
                string? value = option_value (ref index, arguments);
                if (value == null) {
                    return missing_value (argument);
                }
                translated += "--working-directory";
                translated += value;
                continue;
            }

            if (argument == "-t" || argument == "--title"
                || argument.has_prefix ("--title=")) {
                string? value = option_value (ref index, arguments);
                if (value == null) {
                    return missing_value (argument);
                }
                translated += "--title";
                translated += value;
                continue;
            }

            if (argument == "--zoom" || argument.has_prefix ("--zoom=")) {
                string? value = option_value (ref index, arguments);
                if (value == null) {
                    return missing_value (argument);
                }
                translated += "--zoom";
                translated += value;
                continue;
            }

            if (argument == "-e" || argument == "--command"
                || argument.has_prefix ("--command=")) {
                string? value = option_value (ref index, arguments);
                if (value == null) {
                    return missing_value (argument);
                }
                translated += "--command";
                translated += value;
                continue;
            }

            if (argument == "--geometry" || argument.has_prefix ("--geometry=")
                || argument == "--class" || argument.has_prefix ("--class=")
                || argument == "--role" || argument.has_prefix ("--role=")) {
                string? value = option_value (ref index, arguments);
                if (value == null) {
                    return missing_value (argument);
                }
                if (!quiet) {
                    stderr.printf (
                        "gnome-terminal compatibility: ignoring unsupported "
                        + "presentation option: %s\n",
                        argument
                    );
                }
                continue;
            }

            return unsupported (argument);
        }

        Posix.execvp (translated[0], translated);
        int error_code = Posix.errno;
        stderr.printf (
            "gnome-terminal compatibility: failed to launch still-terminal: %s\n",
            Posix.strerror (error_code)
        );
        return 127;
    }
}
