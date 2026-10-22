namespace StillTerminal.Tests {
    private void assert_openable (string? uri) {
        if (!StillTerminal.StHyperlink.is_openable (uri)) {
            GLib.error ("expected \"%s\" to be openable", uri ?? "(null)");
        }
    }

    private void assert_not_openable (string? uri) {
        if (StillTerminal.StHyperlink.is_openable (uri)) {
            GLib.error ("expected \"%s\" to be rejected", uri ?? "(null)");
        }
    }

    private void test_accepts_web_schemes () {
        assert_openable ("https://stillhq.io");
        assert_openable ("http://stillhq.io/terminal");
        assert_openable ("ftp://ftp.gnome.org/vte");
        assert_openable ("mailto:hello@stillhq.io");
    }

    private void test_rejects_unknown_schemes () {
        assert_not_openable ("javascript:alert(1)");
        assert_not_openable ("data:text/html,<script>alert(1)</script>");
        assert_not_openable ("ssh://user@example.com");
        assert_not_openable ("stillhq");
        assert_not_openable ("");
        assert_not_openable ("   ");
        assert_not_openable (null);
    }

    private void test_accepts_local_file_uris () {
        assert_openable ("file:///home/user/notes.txt");
        assert_openable ("file://localhost/home/user/notes.txt");
    }

    private void test_rejects_remote_file_uris () {
        assert_not_openable ("file://elsewhere.example.com/etc/passwd");
    }

    private void test_label_decodes_escapes () {
        string? label = StillTerminal.StHyperlink.label_for ("https://example.com/a%20b");
        assert (label == "https://example.com/a b");
    }

    private void test_label_renders_file_paths () {
        string? label = StillTerminal.StHyperlink.label_for ("file:///home/user/my%20notes.txt");
        assert (label == "/home/user/my notes.txt");
    }

    private void test_label_of_remote_file_uri_is_the_uri () {
        string? label = StillTerminal.StHyperlink.label_for ("file://otherhost/etc/passwd");
        assert (label == "file://otherhost/etc/passwd");
    }

    // ls --hyperlink emits file://<localhost>/path; the hostname has to go,
    // because GIO would otherwise drop it silently and open the local path.
    private void test_normalize_strips_local_hostname () {
        string? normalized = StillTerminal.StHyperlink.normalize (
            "file://%s/tmp/a%%20b".printf (GLib.Environment.get_host_name ())
        );
        assert (normalized == "file:///tmp/a%20b");
    }

    private void test_normalize_strips_localhost () {
        assert (StillTerminal.StHyperlink.normalize ("file://localhost/etc/hosts") == "file:///etc/hosts");
    }

    private void test_normalize_keeps_remote_file_uri () {
        assert (StillTerminal.StHyperlink.normalize ("file://otherhost/etc/passwd")
                == "file://otherhost/etc/passwd");
    }

    private void test_normalize_leaves_web_uris_alone () {
        assert (StillTerminal.StHyperlink.normalize ("https://stillhq.io/a%20b")
                == "https://stillhq.io/a%20b");
        assert (StillTerminal.StHyperlink.normalize (null) == null);
    }

    private void test_local_path_resolution () {
        assert (StillTerminal.StHyperlink.local_path_of ("file:///tmp/x") == "/tmp/x");
        assert (StillTerminal.StHyperlink.local_path_of ("file://localhost/tmp/x") == "/tmp/x");
        assert (StillTerminal.StHyperlink.local_path_of ("file://otherhost/tmp/x") == null);
        assert (StillTerminal.StHyperlink.local_path_of ("https://stillhq.io") == null);
    }

    private void test_label_of_missing_uri () {
        assert (StillTerminal.StHyperlink.label_for (null) == null);
        assert (StillTerminal.StHyperlink.label_for ("  ") == null);
    }

    private void test_ctrl_click_opens_link () {
        assert (StillTerminal.StHyperlinkPolicy.should_open (
            Gdk.BUTTON_PRIMARY,
            Gdk.ModifierType.CONTROL_MASK,
            "https://stillhq.io"
        ));
    }

    private void test_plain_click_is_left_for_selection () {
        assert (!StillTerminal.StHyperlinkPolicy.should_open (
            Gdk.BUTTON_PRIMARY,
            (Gdk.ModifierType) 0,
            "https://stillhq.io"
        ));
    }

    private void test_other_modifiers_do_not_open () {
        assert (!StillTerminal.StHyperlinkPolicy.should_open (
            Gdk.BUTTON_PRIMARY,
            Gdk.ModifierType.SHIFT_MASK,
            "https://stillhq.io"
        ));
    }

    private void test_secondary_click_is_not_a_link_click () {
        assert (!StillTerminal.StHyperlinkPolicy.should_open (
            Gdk.BUTTON_SECONDARY,
            Gdk.ModifierType.CONTROL_MASK,
            "https://stillhq.io"
        ));
    }

    private void test_ctrl_click_without_link_does_nothing () {
        assert (!StillTerminal.StHyperlinkPolicy.should_open (
            Gdk.BUTTON_PRIMARY,
            Gdk.ModifierType.CONTROL_MASK,
            null
        ));
    }

    private void test_ctrl_click_on_unsupported_scheme_is_refused () {
        assert (!StillTerminal.StHyperlinkPolicy.should_open (
            Gdk.BUTTON_PRIMARY,
            Gdk.ModifierType.CONTROL_MASK,
            "javascript:alert(1)"
        ));
    }

    public static int main (string[] args) {
        Test.init (ref args);
        Test.add_func ("/hyperlink/accepts-web-schemes", test_accepts_web_schemes);
        Test.add_func ("/hyperlink/rejects-unknown-schemes", test_rejects_unknown_schemes);
        Test.add_func ("/hyperlink/accepts-local-file-uris", test_accepts_local_file_uris);
        Test.add_func ("/hyperlink/rejects-remote-file-uris", test_rejects_remote_file_uris);
        Test.add_func ("/hyperlink/label-decodes-escapes", test_label_decodes_escapes);
        Test.add_func ("/hyperlink/label-renders-file-paths", test_label_renders_file_paths);
        Test.add_func ("/hyperlink/label-of-remote-file-uri-is-the-uri", test_label_of_remote_file_uri_is_the_uri);
        Test.add_func ("/hyperlink/normalize-strips-local-hostname", test_normalize_strips_local_hostname);
        Test.add_func ("/hyperlink/normalize-strips-localhost", test_normalize_strips_localhost);
        Test.add_func ("/hyperlink/normalize-keeps-remote-file-uri", test_normalize_keeps_remote_file_uri);
        Test.add_func ("/hyperlink/normalize-leaves-web-uris-alone", test_normalize_leaves_web_uris_alone);
        Test.add_func ("/hyperlink/local-path-resolution", test_local_path_resolution);
        Test.add_func ("/hyperlink/label-of-missing-uri", test_label_of_missing_uri);
        Test.add_func ("/hyperlink/ctrl-click-opens-link", test_ctrl_click_opens_link);
        Test.add_func ("/hyperlink/plain-click-is-left-for-selection", test_plain_click_is_left_for_selection);
        Test.add_func ("/hyperlink/other-modifiers-do-not-open", test_other_modifiers_do_not_open);
        Test.add_func ("/hyperlink/secondary-click-is-not-a-link-click", test_secondary_click_is_not_a_link_click);
        Test.add_func ("/hyperlink/ctrl-click-without-link-does-nothing", test_ctrl_click_without_link_does_nothing);
        Test.add_func ("/hyperlink/ctrl-click-on-unsupported-scheme-is-refused", test_ctrl_click_on_unsupported_scheme_is_refused);
        return Test.run ();
    }
}
