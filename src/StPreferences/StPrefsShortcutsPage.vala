namespace StillTerminal {
    public class StPrefsShortcutsPage : Adw.PreferencesPage {
        // Removed unused terminal_group to avoid warnings
        private StPrefsShortcutGroup window_group;
        private StPrefsShortcutGroup editing_group;

        public StPrefsShortcutsPage () {
            this.window_group = new StPrefsShortcutGroup (_ ("Window"), _ ("Window and tab management"));
            this.editing_group = new StPrefsShortcutGroup (_ ("Editing"), _ ("Text editing and selection"));

            this.set_title (_ ("Shortcuts"));
            this.set_icon_name ("preferences-desktop-keyboard-symbolic");

            this.setup_shortcuts ();

            this.add (this.window_group);
            this.add (this.editing_group);
        }

        private void setup_shortcuts () {
            // Window management
            this.window_group.add_shortcut_row ("new-tab", _ ("New Tab"), _ ("Create a new terminal tab"));
            this.window_group.add_shortcut_row ("reopen-last-tab", _ ("Reopen Last Tab"), _ ("Open a new tab using the most recently used profile"));
            this.window_group.add_shortcut_row ("close-tab", _ ("Close Tab"), _ ("Close the current tab"));
            this.window_group.add_shortcut_row ("next-tab", _ ("Next Tab"), _ ("Switch to next tab"));
            this.window_group.add_shortcut_row ("previous-tab", _ ("Previous Tab"), _ ("Switch to previous tab"));
            this.window_group.add_shortcut_row ("new-window", _ ("New Window"), _ ("Open a new terminal window"));
            this.window_group.add_shortcut_row ("fullscreen", _ ("Toggle Fullscreen"), _ ("Toggle fullscreen mode"));
            this.window_group.add_shortcut_row ("preferences", _ ("Preferences"), _ ("Open preferences dialog"));
            this.window_group.add_shortcut_row ("zoom-in", _ ("Zoom In"), _ ("Increase font size"));
            this.window_group.add_shortcut_row ("zoom-out", _ ("Zoom Out"), _ ("Decrease font size"));

            // Editing actions
            this.editing_group.add_shortcut_row ("copy", _ ("Copy"), _ ("Copy selected text"));
            this.editing_group.add_shortcut_row ("paste", _ ("Paste"), _ ("Paste from clipboard"));
            this.editing_group.add_shortcut_row ("select-all", _ ("Select All"), _ ("Select all terminal content"));
        }
    }

    public class StPrefsShortcutGroup : Adw.PreferencesGroup {
        private string group_id;

        public StPrefsShortcutGroup (string title, string description) {
            this.group_id = title.down ().replace (" ", "_");
            this.set_title (title);
            this.set_description (description);
        }

        public void add_shortcut_row (string action_id, string title, string description) {
            var row = new StShortcutRow (action_id, title, description);
            this.add (row);
        }
    }

    public class StShortcutRow : Adw.ActionRow {
        private string action_id;
        private Gtk.ShortcutLabel shortcut_label;
        private Gtk.Button edit_button;
        private Gtk.Button default_button;
        private bool is_editing = false;

        public StShortcutRow (string action_id, string title, string description) {
            this.action_id = action_id;
            this.set_title (title);
            this.set_subtitle (description);
            this.set_activatable (true);

            this.setup_ui ();
        }

        private void setup_ui () {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            this.shortcut_label = new Gtk.ShortcutLabel ("");
            this.shortcut_label.set_valign (Gtk.Align.CENTER);
            this.shortcut_label.set_margin_end (10);

            // Create edit button with pencil icon
            this.edit_button = new Gtk.Button ();
            this.edit_button.set_valign (Gtk.Align.CENTER);
            this.edit_button.add_css_class ("flat");
            this.edit_button.add_css_class ("circular");
            this.edit_button.set_tooltip_text (_ ("Edit shortcut"));
            this.edit_button.set_icon_name ("document-edit-symbolic");

            // Create default button with reset icon
            this.default_button = new Gtk.Button ();
            this.default_button.set_valign (Gtk.Align.CENTER);
            this.default_button.add_css_class ("flat");
            this.default_button.add_css_class ("circular");
            this.default_button.set_tooltip_text (_ ("Reset to default"));
            this.default_button.set_icon_name ("arrow-hook-left-horizontal2-symbolic");

            box.append (this.shortcut_label);
            box.append (this.default_button);
            box.append (this.edit_button);

            this.add_suffix (box);

            // Connect signals
            this.edit_button.clicked.connect (this.on_edit_clicked);
            this.default_button.clicked.connect (this.on_default_clicked);
            this.activated.connect (this.on_edit_clicked);

            // Load current shortcut
            this.load_current_shortcut ();
        }

        private void load_current_shortcut () {
            var settings = new GLib.Settings ("io.stillhq.terminal");
            string[] shortcuts = settings.get_strv ("shortcut-" + this.action_id);

            if (shortcuts.length > 0) {
                this.shortcut_label.set_accelerator (shortcuts[0]);
            }
        }

        private void on_edit_clicked () {
            if (this.is_editing) {
                return;
            }

            this.is_editing = true;

            // Change to question icon and set tooltip
            this.edit_button.set_icon_name ("question-round-outline-symbolic");
            this.edit_button.set_tooltip_text (_ ("Press keys..."));
            this.edit_button.set_sensitive (false);

            // Create a key event controller for capturing key presses
            var key_controller = new Gtk.EventControllerKey ();
            this.add_controller (key_controller);

            // Make sure the row can receive focus for key events
            this.set_can_focus (true);
            this.grab_focus ();

            key_controller.key_pressed.connect ((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Escape) {
                    this.cancel_edit (key_controller);
                    return true;
                }

                // Filter out modifier-only keys
                if (keyval == Gdk.Key.Control_L || keyval == Gdk.Key.Control_R ||
                    keyval == Gdk.Key.Shift_L || keyval == Gdk.Key.Shift_R ||
                    keyval == Gdk.Key.Alt_L || keyval == Gdk.Key.Alt_R ||
                    keyval == Gdk.Key.Super_L || keyval == Gdk.Key.Super_R ||
                    keyval == Gdk.Key.Meta_L || keyval == Gdk.Key.Meta_R) {
                    return false; // Continue processing, don't save yet
                }

                // Build accelerator string
                string accelerator = "";

                if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    accelerator += "<Control>";
                }
                if ((state & Gdk.ModifierType.SHIFT_MASK) != 0) {
                    accelerator += "<Shift>";
                }
                if ((state & Gdk.ModifierType.ALT_MASK) != 0) {
                    accelerator += "<Alt>";
                }
                if ((state & Gdk.ModifierType.SUPER_MASK) != 0) {
                    accelerator += "<Super>";
                }

                string key_name = Gdk.keyval_name (keyval);
                if (key_name != null) {
                    accelerator += key_name;
                } else {
                    // If we can't get a key name, cancel
                    this.cancel_edit (key_controller);
                    return true;
                }

                this.save_shortcut (accelerator);
                this.finish_edit (key_controller);

                return true;
            });
        }

        private void cancel_edit (Gtk.EventControllerKey controller) {
            this.remove_controller (controller);
            this.is_editing = false;

            // Restore pencil icon and tooltip
            this.edit_button.set_icon_name ("document-edit-symbolic");
            this.edit_button.set_tooltip_text (_ ("Edit shortcut"));
            this.edit_button.set_sensitive (true);
        }

        private void finish_edit (Gtk.EventControllerKey controller) {
            this.remove_controller (controller);
            this.is_editing = false;

            // Restore pencil icon and tooltip
            this.edit_button.set_icon_name ("document-edit-symbolic");
            this.edit_button.set_tooltip_text (_ ("Edit shortcut"));
            this.edit_button.set_sensitive (true);
        }

        private void on_default_clicked () {
            // Reset to default value using GSettings
            var settings = new GLib.Settings ("io.stillhq.terminal");
            settings.reset ("shortcut-" + this.action_id);

            // Reload the current shortcut to display the default
            this.load_current_shortcut ();

            // Refresh shortcuts in the application
            var app = GLib.Application.get_default () as Gtk.Application;
            if (app != null) {
                var main_window = app.get_active_window () as MainWindow;
                if (main_window != null) {
                    main_window.settings.refresh_accelerators (app);
                    main_window.shortcuts.refresh_shortcuts ();
                }
            }
        }

        private void save_shortcut (string accelerator) {
            var settings = new GLib.Settings ("io.stillhq.terminal");
            string[] shortcuts = { accelerator };
            settings.set_strv ("shortcut-" + this.action_id, shortcuts);

            this.shortcut_label.set_accelerator (accelerator);

            // Refresh shortcuts in the application
            var app = GLib.Application.get_default () as Gtk.Application;
            if (app != null) {
                var main_window = app.get_active_window () as MainWindow;
                if (main_window != null) {
                    main_window.settings.refresh_accelerators (app);
                    main_window.shortcuts.refresh_shortcuts ();
                }
            }
        }
    }
}
