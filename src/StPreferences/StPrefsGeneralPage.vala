namespace StillTerminal {
    public class StPrefsGeneralPage : Adw.PreferencesPage {
        public StPrefsDialog dialog;
        public StPrefsWindowGroup window_group;
        public StPrefsCellSpacingGroup cell_spacing_group;
        public StPrefsAppearanceGroup appearance_group;
        
        public StPrefsGeneralPage (StPrefsDialog dialog) {
            this.dialog = dialog;
            this.window_group = new StPrefsWindowGroup ();
            this.cell_spacing_group = new StPrefsCellSpacingGroup ();
            this.appearance_group = new StPrefsAppearanceGroup ();

            this.set_title ("General");
            this.set_icon_name ("utilities-terminal-symbolic");

            this.add (this.window_group);
            this.add (this.cell_spacing_group);
            this.add (this.appearance_group);
        }
    }

    public class StPrefsWindowGroup : Adw.PreferencesGroup {
        public Adw.SpinRow window_width;
        public Adw.SpinRow window_height;
        public Adw.SwitchRow save_window_size;

        public StPrefsWindowGroup () {
            this.set_title("Window Size");
            double max_width;
            double max_height;
            this.get_max_size (out max_width, out max_height);

            this.window_width = new Adw.SpinRow.with_range (400, max_width, 5);
            this.window_width.set_title ("Default Window Width");
            this.window_width.set_subtitle("Default: 600");
            this.window_width.set_digits(0);

            this.window_height = new Adw.SpinRow.with_range (300, max_height, 5);
            this.window_height.set_title ("Default Window Height");
            this.window_height.set_subtitle("Default: 400");
            this.window_height.set_digits(0);

            this.save_window_size = new Adw.SwitchRow ();
            this.save_window_size.set_title ("Save Window Size");

            this.add (this.window_width);
            this.add (this.window_height);
            this.add (this.save_window_size);
        }

        public void get_max_size (out double width, out double height) {
            var display = Gdk.Display.get_default ();
            var monitors = display.get_monitors ();
            var n_monitors = monitors.get_n_items();
            var monitor_index = 0;
            width = 0;
            height = 0;

            while (monitor_index < n_monitors) {
                var monitor = monitors.get_item (monitor_index) as Gdk.Monitor;
                if (monitor != null) {
                    var rect = monitor.get_geometry ();
                    var monitor_width = rect.width;
                    var monitor_height = rect.height;
                    width = Math.fmax (monitor_width, width);
                    height = Math.fmax (monitor_height, height);
                }
                monitor_index++;
            }
        }
    }

    public class StPrefsCellSpacingGroup : Adw.PreferencesGroup {
        public Adw.SpinRow cell_width;
        public Adw.SpinRow cell_height;

        public StPrefsCellSpacingGroup () {
            this.set_title("Cell Spacing");

            this.cell_width = new Adw.SpinRow.with_range (1, 2, 0.05);
            this.cell_width.set_title ("Terminal Cell Width");

            this.cell_height = new Adw.SpinRow.with_range (1, 2, 0.05);
            this.cell_height.set_title ("Terminal Cell Height");

            this.add (this.cell_width);
            this.add (this.cell_height);
        }
    }

    public class StPrefsAppearanceGroup : Adw.PreferencesGroup {
        public bool change_settings = false;
        public Adw.ActionRow system_color_row;
        // Removed: global container theme matching toggle (now per-profile)
        // removed: available_scheme_strings

        public Adw.SpinRow padding;
        public Adw.SpinRow opacity_setting; // different name to avoid conflict with opacity property
        public Adw.SwitchRow use_custom_font;
        public Adw.ActionRow custom_font;
        public Adw.SwitchRow bold_is_bright;
        public Adw.SwitchRow show_scrollbars;
        public Gtk.FontDialogButton font_button;
        public Gtk.FontDialog font_dialog;

        public StPrefsAppearanceGroup () {
            this.set_title ("Appearance");

            // Replace dropdown with a row + button that opens the theme picker page
            this.system_color_row = new Adw.ActionRow ();
            this.system_color_row.set_title ("System Color Scheme");
            var open_button = new Gtk.Button.with_label ("Choose…");
            open_button.add_css_class ("flat");
            open_button.valign = Gtk.Align.CENTER;
            open_button.clicked.connect (() => {
                var picker = new StThemePickerPage ("System Theme", false, null);
                picker.scheme_selected.connect ((id) => {
                    var s = new GLib.Settings ("io.stillhq.terminal");
                    s.set_string ("system-color", id);
                    string subtitle = id;
                    var scheme = StColorScheme.new_from_id(id);
                    if (scheme != null && scheme.name != null && scheme.name != "") subtitle = scheme.name;
                    this.system_color_row.set_subtitle (subtitle);
                    var dlg = this.get_ancestor(typeof(Adw.PreferencesDialog)) as Adw.PreferencesDialog;
                    if (dlg != null) dlg.pop_subpage ();
                });
                var dlg = this.get_ancestor(typeof(Adw.PreferencesDialog)) as Adw.PreferencesDialog;
                if (dlg != null) dlg.push_subpage (picker);
            });
            this.system_color_row.add_suffix (open_button);
            this.system_color_row.set_activatable_widget (open_button);


            this.padding = new Adw.SpinRow.with_range (0, 10, 1);
            this.padding.set_title ("Padding");

            this.opacity_setting = new Adw.SpinRow.with_range (0, 100, 1);
            this.opacity_setting.set_title ("Opacity");

            this.bold_is_bright = new Adw.SwitchRow ();
            this.bold_is_bright.set_title ("Bold is Bright");

            this.show_scrollbars = new Adw.SwitchRow ();
            this.show_scrollbars.set_title ("Hide Scrollbars");

            this.use_custom_font = new Adw.SwitchRow ();
            this.use_custom_font.set_title ("Use Custom Font");

            this.custom_font = new Adw.ActionRow ();
            this.custom_font.set_title ("Custom Font");
            this.font_dialog = new Gtk.FontDialog ();
            this.font_button = new Gtk.FontDialogButton (this.font_dialog);
            this.font_button.add_css_class("flat");
            this.font_button.valign = Gtk.Align.CENTER;
            this.custom_font.add_suffix (this.font_button);
            this.custom_font.set_activatable_widget (this.font_button);

            this.add (this.system_color_row);
            this.add (this.padding);
            this.add (this.opacity_setting);
            this.add (this.bold_is_bright);
            this.add (this.show_scrollbars);
            this.add (this.use_custom_font);
            this.add (this.custom_font);
        }

        public void scheme_setting_changed (GLib.Settings settings, string key) {
            if (key != "system-color") {
                return;
            }

            var id = settings.get_string (key);
            string subtitle = id;
            var scheme = StColorScheme.new_from_id(id);
            if (scheme != null && scheme.name != null && scheme.name != "") {
                subtitle = scheme.name;
            }
            this.system_color_row.set_subtitle (subtitle);
        }

        public void font_button_changed (Settings settings) {
            string selected_font = this.font_button.get_font_desc ().to_string();
            if (settings.get_string("custom-font") == selected_font) {
                return;
            }
    
            settings.set_string("custom-font", selected_font);
        }
    
        public void font_setting_changed (GLib.Settings settings, string key) {
            if (key != "custom-font") {
                return;
            }
    
            var font = settings.get_string(key);
            if (font == this.font_button.get_font_desc ().to_string ()) {
                return;
            }
            this.font_button.set_font_desc(Pango.FontDescription.from_string(font));
        }
    }
}