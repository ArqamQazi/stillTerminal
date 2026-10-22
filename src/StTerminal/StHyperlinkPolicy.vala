namespace StillTerminal {
    /**
     * Decides whether a mouse press should follow an OSC 8 hyperlink.
     *
     * Kept separate from the widget so the rules can be tested without a
     * display: a link is only followed on Ctrl+click, which leaves plain
     * clicks free for text selection.
     */
    public class StHyperlinkPolicy : GLib.Object {
        public static bool should_open (
            uint button,
            Gdk.ModifierType state,
            string? uri
        ) {
            if (uri == null) {
                return false;
            }
            if ((state & Gdk.ModifierType.CONTROL_MASK) == 0) {
                return false;
            }
            if (button != Gdk.BUTTON_PRIMARY && button != Gdk.BUTTON_MIDDLE) {
                return false;
            }
            return StHyperlink.is_openable (uri);
        }
    }
}
