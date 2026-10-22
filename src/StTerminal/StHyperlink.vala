namespace StillTerminal {
    /**
     * Helpers for OSC 8 hyperlinks.
     *
     * VTE hands back the raw target of an OSC 8 escape sequence without
     * validating it, so every string coming out of the terminal has to be
     * treated as untrusted until it is checked here.
     */
    public class StHyperlink : GLib.Object {
        /**
         * Check whether @uri is something we are willing to hand to the
         * desktop.
         *
         * Only a small allowlist of schemes is accepted, and file: URIs are
         * rejected when they point at another host: GIO silently drops the
         * hostname and opens the local counterpart instead, which is
         * misleading (the link usually comes from a remote shell).
         */
        public static bool is_openable (string? uri) {
            if (uri == null) {
                return false;
            }
            string trimmed = uri.strip ();
            if (trimmed == "") {
                return false;
            }

            GLib.Uri parsed;
            try {
                parsed = GLib.Uri.parse (trimmed, GLib.UriFlags.NONE);
            } catch (GLib.UriError e) {
                return false;
            }

            string? scheme = parsed.get_scheme ();
            if (scheme == null) {
                return false;
            }

            switch (scheme.down ()) {
            case "http":
            case "https":
            case "ftp":
            case "ftps":
            case "mailto":
                return true;
            case "file":
                string? host = parsed.get_host ();
                if (host == null || host == "") {
                    return true;
                }
                return host.down () == "localhost" || host.down () == GLib.Environment.get_host_name ().down ();
            default:
                return false;
            }
        }

        /**
         * Rewrite @uri into the form the desktop should receive.
         *
         * `ls --hyperlink` and friends emit file: URIs that carry the local
         * hostname (`file://myhost/path`). GIO accepts those but quietly drops
         * the host, so they are rewritten to plain `file:///path` up front
         * instead of relying on that.
         */
        public static string? normalize (string? uri) {
            if (uri == null) {
                return null;
            }
            string trimmed = uri.strip ();
            if (trimmed == "") {
                return null;
            }

            string? path = local_path_of (trimmed);
            if (path == null) {
                return trimmed;
            }

            try {
                return GLib.Filename.to_uri (path, null);
            } catch (GLib.ConvertError e) {
                return trimmed;
            }
        }

        /**
         * Return the filesystem path behind @uri when it is a file: URI on
         * this machine, or null for anything else.
         */
        public static string? local_path_of (string? uri) {
            if (uri == null) {
                return null;
            }
            string? hostname = null;
            string? path;
            try {
                path = GLib.Filename.from_uri (uri, out hostname);
            } catch (GLib.ConvertError e) {
                return null;
            }
            if (path == null) {
                return null;
            }
            if (hostname != null && hostname != "" &&
                hostname.down () != "localhost" &&
                hostname.down () != GLib.Environment.get_host_name ().down ()) {
                // Another machine: the path is meaningless locally.
                return null;
            }
            return path;
        }

        /**
         * Build a human readable label for @uri, used as the hover tooltip.
         * Percent escapes are decoded so the tooltip shows the target the way
         * a person would write it, and local file: URIs are shown as paths.
         */
        public static string? label_for (string? uri) {
            if (uri == null) {
                return null;
            }
            string trimmed = uri.strip ();
            if (trimmed == "") {
                return null;
            }

            string? path = local_path_of (trimmed);
            if (path != null) {
                return path;
            }

            return GLib.Uri.unescape_string (trimmed, null) ?? trimmed;
        }
    }
}
