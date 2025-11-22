namespace StillTerminal {
    public class StPrefsDialog {
        public static StPrefsDialog? active_instance = null;
        public Adw.PreferencesDialog preferences_dialog;
        public MainWindow window;

        public StPrefsDialog (MainWindow window) {
            this.preferences_dialog = new Adw.PreferencesDialog ();
            this.window = window;

            active_instance = this;
            this.preferences_dialog.closed.connect (() => {
                if (StPrefsDialog.active_instance == this) {
                    StPrefsDialog.active_instance = null;
                }
            });

            var general_page = new StPrefsGeneralPage (this);
            var profile_page = new StPrefsProfilePage (this);
            var shortcuts_page = new StPrefsShortcutsPage ();
            this.window.settings.bind_to_general (general_page);
            this.preferences_dialog.add (general_page);
            this.preferences_dialog.add (profile_page);
            this.preferences_dialog.add (shortcuts_page);
        }

        public void present (Gtk.Widget parent) {
            this.preferences_dialog.present (parent);
        }
    }
}