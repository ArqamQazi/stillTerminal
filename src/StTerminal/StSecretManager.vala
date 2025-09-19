namespace StillTerminal {
    /**
     * Minimal helper around GNOME Keyring (libsecret) to store SSH passwords per profile.
     * Passwords are never written to disk; only stored/retrieved/cleared via libsecret.
     */
    public class StSecretManager : GLib.Object {
        // Secret schema for storing passwords
        private static Secret.Schema SCHEMA = new Secret.Schema(
            "io.stillhq.terminal.ssh",
            Secret.SchemaFlags.NONE,
            "profile_id", Secret.SchemaAttributeType.STRING,
            null
        );

        private static string build_label(string profile_id) {
            return "stillTerminal SSH password (" + profile_id + ")";
        }

        public static bool store_password(string profile_id, string password) {
            try {
                var attrs = new GLib.HashTable<string,string>(GLib.str_hash, GLib.str_equal);
                attrs.insert("profile_id", profile_id);
                Secret.password_storev_sync(
                    SCHEMA,
                    attrs,
                    Secret.COLLECTION_DEFAULT,
                    build_label(profile_id),
                    password,
                    null
                );
                return true;
            } catch (Error e) {
                warning("Failed to store password: %s", e.message);
                return false;
            }
        }

        public static string? lookup_password(string profile_id) {
            try {
                var attrs = new GLib.HashTable<string,string>(GLib.str_hash, GLib.str_equal);
                attrs.insert("profile_id", profile_id);
                return Secret.password_lookupv_sync(
                    SCHEMA,
                    attrs,
                    null
                );
            } catch (Error e) {
                warning("Failed to lookup password: %s", e.message);
                return null;
            }
        }

        public static bool clear_password(string profile_id) {
            try {
                var attrs = new GLib.HashTable<string,string>(GLib.str_hash, GLib.str_equal);
                attrs.insert("profile_id", profile_id);
                return Secret.password_clearv_sync(
                    SCHEMA,
                    attrs,
                    null
                );
            } catch (Error e) {
                warning("Failed to clear password: %s", e.message);
                return false;
            }
        }

        public static bool has_password(string profile_id) {
            var pw = lookup_password(profile_id);
            return pw != null && pw.length > 0;
        }
    }
}


