namespace StillTerminal {
    public errordomain LaunchRequestError {
        CONFLICTING_COMMANDS
    }

    public class LaunchRequest : Object {
        public static string[]? parse_command (
            string? legacy_command,
            string[] arguments
        ) throws Error {
            bool has_legacy_command = legacy_command != null
                && legacy_command.strip () != "";
            bool has_positional_command = arguments.length > 1;

            if (has_legacy_command && has_positional_command) {
                throw new LaunchRequestError.CONFLICTING_COMMANDS (
                    "Cannot combine --command with a command after --"
                );
            }

            if (has_legacy_command) {
                string[] parsed;
                Shell.parse_argv (legacy_command, out parsed);
                return parsed;
            }

            if (has_positional_command) {
                string[] parsed = new string[arguments.length - 1];
                for (int i = 1; i < arguments.length; i++) {
                    parsed[i - 1] = arguments[i];
                }
                return parsed;
            }

            return null;
        }

        public static string? resolve_working_directory (
            string? requested_directory,
            string? invocation_cwd
        ) {
            if (requested_directory == null || requested_directory.strip () == "") {
                return null;
            }

            if (Path.is_absolute (requested_directory) || invocation_cwd == null
                || invocation_cwd == "") {
                return requested_directory;
            }

            return Path.build_filename (invocation_cwd, requested_directory);
        }

        public static bool use_profile_environment (string[]? command_override) {
            return command_override == null || command_override.length == 0;
        }
    }
}
