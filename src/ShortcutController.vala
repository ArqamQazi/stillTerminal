namespace StillTerminal {
    public class ShortcutController : GLib.Object {
        public bool shortcuts_added = false;

        public string[] new_tab { get; set; default = { "<Control>t" }; }
        public string[] reopen_last_tab { get; set; default = { "<Control><Shift>t" }; }
        public string[] close_tab { get; set; default = { "<Control><Shift>w" }; }
        public string[] next_tab { get; set; default = { "<Control>Tab" }; }
        public string[] previous_tab { get; set; default = { "<Control><Shift>Tab" }; }
        public string[] copy { get; set; default = { "<Control><Shift>c" }; }
        public string[] paste { get; set; default = { "<Control><Shift>v" }; }
        public string[] fullscreen { get; set; default = { "F11" }; }
        public string[] new_window { get; set; default = { "<Control>n" }; }
        public string[] preferences { get; set; default = { "<Control>comma" }; }
        public string[] zoom_in { get; set; default = { "<Control><Shift>plus" }; }
        public string[] zoom_out { get; set; default = { "<Control>minus" }; }
        public string[] select_all { get; set; default = { "<Control>a" }; }
        public string[] tab_overview_toggle { get; set; default = { "<Control><Shift>o" }; }
        public string[] tab_overview_open { get; set; default = { "<Control><Shift>p" }; }
        public string[] tab_overview_close { get; set; default = { "Escape" }; }

        public Gtk.Shortcut new_tab_shortcut;
        public Gtk.Shortcut close_tab_shortcut;
        public Gtk.Shortcut reopen_last_tab_shortcut;
        public Gtk.Shortcut next_tab_shortcut;
        public Gtk.Shortcut previous_tab_shortcut;
        public Gtk.Shortcut copy_shortcut;
        public Gtk.Shortcut paste_shortcut;
        public Gtk.Shortcut fullscreen_shortcut;
        public Gtk.Shortcut new_window_shortcut;
        public Gtk.Shortcut preferences_shortcut;
        public Gtk.Shortcut zoom_in_shortcut;
        public Gtk.Shortcut zoom_out_shortcut;
        public Gtk.Shortcut select_all_shortcut;
        public Gtk.Shortcut tab_overview_toggle_shortcut;
        public Gtk.Shortcut tab_overview_open_shortcut;
        public Gtk.Shortcut tab_overview_close_shortcut;

        public Gtk.ShortcutController controller = new Gtk.ShortcutController();

        public void refresh_shortcuts () {
            // Update each shortcut individually
            update_shortcut (new_tab_shortcut, new_tab);
            update_shortcut (close_tab_shortcut, close_tab);
            update_shortcut (reopen_last_tab_shortcut, reopen_last_tab);
            update_shortcut (next_tab_shortcut, next_tab);
            update_shortcut (previous_tab_shortcut, previous_tab);
            update_shortcut (copy_shortcut, copy);
            update_shortcut (paste_shortcut, paste);
            update_shortcut (fullscreen_shortcut, fullscreen);
            update_shortcut (new_window_shortcut, new_window);
            update_shortcut (preferences_shortcut, preferences);
            update_shortcut (zoom_in_shortcut, zoom_in);
            update_shortcut (zoom_out_shortcut, zoom_out);
            update_shortcut (select_all_shortcut, select_all);
            update_shortcut (tab_overview_toggle_shortcut, tab_overview_toggle);
            update_shortcut (tab_overview_open_shortcut, tab_overview_open);
            update_shortcut (tab_overview_close_shortcut, tab_overview_close);

            // Add all shortcuts to controller
            add_all_shortcuts ();
        }

        private void update_shortcut (Gtk.Shortcut shortcut, string[] actions) {
            if (actions.length > 0) {
                string action = actions[0]; // Use first shortcut from array
                Gtk.ShortcutTrigger? trigger = Gtk.ShortcutTrigger.parse_string (action);
                if (trigger != null) {
                    shortcut.set_trigger (trigger);
                }
            }
        }

        private void add_all_shortcuts () {
            Gtk.Shortcut[] shortcuts = {
                new_tab_shortcut, reopen_last_tab_shortcut, close_tab_shortcut, next_tab_shortcut, previous_tab_shortcut,
                copy_shortcut, paste_shortcut, fullscreen_shortcut, new_window_shortcut,
                preferences_shortcut, zoom_in_shortcut, zoom_out_shortcut,
                select_all_shortcut,
                tab_overview_toggle_shortcut, tab_overview_open_shortcut, tab_overview_close_shortcut
            };
            foreach (Gtk.Shortcut shortcut in shortcuts) {
                if (this.shortcuts_added) {
                    this.controller.remove_shortcut (shortcut);
                }
                this.controller.add_shortcut (shortcut);
            }
            this.shortcuts_added = true;
        }

        public ShortcutController() {
            new_tab_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.new-tab"));
            reopen_last_tab_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.reopen-last-tab"));
            close_tab_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.close-tab"));
            next_tab_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.next-tab"));
            previous_tab_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.previous-tab"));
            copy_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.copy"));
            paste_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.paste"));
            fullscreen_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.fullscreen"));
            new_window_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.new-window"));
            preferences_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.preferences"));
            zoom_in_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.zoom-in"));
            zoom_out_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.zoom-out"));
            select_all_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.select-all"));
            tab_overview_toggle_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.tab-overview-toggle"));
            tab_overview_open_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.tab-overview-open"));
            tab_overview_close_shortcut = new Gtk.Shortcut (null, Gtk.ShortcutAction.parse_string ("app.tab-overview-close"));

            refresh_shortcuts ();
        }
    }
}