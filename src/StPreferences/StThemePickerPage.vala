namespace StillTerminal {
    public class StThemePickerPage : Adw.NavigationPage {
        public signal void scheme_selected (string scheme_id);

        private Gtk.FlowBox flow;
        private string? selected_id;
        private bool include_system;
        private Gee.HashMap<string, Gtk.Image> id_to_check = new Gee.HashMap<string, Gtk.Image>();
        private Gee.HashMap<string, Gtk.Box> id_to_preview = new Gee.HashMap<string, Gtk.Box>();

        public StThemePickerPage(string title, bool include_system, string? initially_selected_id) {
            this.title = title;
            this.include_system = include_system;
            this.selected_id = initially_selected_id;

            var header = new Adw.HeaderBar ();
            header.set_show_start_title_buttons (false);
            header.set_show_end_title_buttons (false);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.append (header);

            var scrolled = new Gtk.ScrolledWindow ();
            scrolled.vexpand = true;
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
            content.append (scrolled);

            this.flow = new Gtk.FlowBox ();
            this.flow.valign = Gtk.Align.START;
            this.flow.homogeneous = true;
            this.flow.min_children_per_line = 1;
            this.flow.max_children_per_line = 6; // responsive; wraps based on available width
            this.flow.column_spacing = 12;
            this.flow.row_spacing = 12;
            this.flow.selection_mode = Gtk.SelectionMode.NONE;
            this.flow.margin_top = 12;
            this.flow.margin_bottom = 12;
            this.flow.margin_start = 12;
            this.flow.margin_end = 12;
            scrolled.set_child (this.flow);

            this.populate ();

            this.set_child (content);

            // Re-color previews when light/dark mode changes
            var sm = Adw.StyleManager.get_default ();
            if (sm != null) {
                sm.notify["dark"].connect (() => { this.refresh_previews (); });
                sm.notify["color-scheme"].connect (() => { this.refresh_previews (); });
            }
        }

        private void populate () {
            if (this.include_system) {
                this.add_theme_tile ("system", _ ("System Theme"), null);
            }

            var schemes = get_available_schemes ();
            foreach (var entry in schemes.entries) {
                var scheme = StColorScheme.new_from_json (entry.value);
                if (scheme == null) {
                    continue;
                }
                this.add_theme_tile (entry.key, scheme.name, scheme);
            }
        }

        private void add_theme_tile (string id, string title, StColorScheme? scheme) {
            var button = new Gtk.Button ();
            button.add_css_class ("theme-card");
            button.set_can_focus (true);
            button.set_hexpand (false);
            button.set_vexpand (false);
            button.set_halign (Gtk.Align.FILL);
            button.set_size_request (180, -1);

            var overlay = new Gtk.Overlay ();
            button.set_child (overlay);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            box.margin_top = 8;
            box.margin_bottom = 8;
            box.margin_start = 8;
            box.margin_end = 8;
            overlay.set_child (box);

            // Preview
            var preview = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            preview.add_css_class ("theme-preview");
            preview.set_size_request (140, 78);
            box.append (preview);
            this.id_to_preview[id] = preview;

            // Title label (resolve name for System)
            string display_title = title;
            //  if (id == "system") {
            //      var s = new GLib.Settings ("io.stillhq.terminal");
            //      string sys_id = s.get_string ("system-color");
            //      var sys_scheme = (sys_id != null && sys_id.strip () != "" && sys_id != "default") ? StColorScheme.new_from_id (sys_id) : null;
            //      if (sys_scheme != null && sys_scheme.name != null && sys_scheme.name != "") {
            //          display_title = sys_scheme.name;
            //      }
            //  }
            var label = new Gtk.Label (display_title);
            label.add_css_class ("caption-heading");
            label.set_xalign (0.0f);
            label.set_wrap (true);
            label.set_max_width_chars (18);
            label.set_ellipsize (Pango.EllipsizeMode.END);
            label.set_justify (Gtk.Justification.CENTER);
            label.set_hexpand (true);
            box.append (label);

            // Check overlay icon
            var check = new Gtk.Image.from_icon_name ("object-select-symbolic");
            check.add_css_class ("selection-badge");
            check.set_valign (Gtk.Align.START);
            check.set_halign (Gtk.Align.START);
            check.margin_top = 6;
            check.margin_start = 6;
            overlay.add_overlay (check);

            // Configure preview colors from theme (respect light/dark)
            var resolved = this.resolve_scheme_for_id (id, scheme);
            bool is_dark = false; var sm2 = Adw.StyleManager.get_default (); if (sm2 != null) {
                is_dark = sm2.get_dark ();
            }
            string bg = is_dark ? resolved.dark_background_color : resolved.light_background_color;
            string fg = is_dark ? resolved.dark_foreground_color : resolved.light_foreground_color;
            string[] accents;
            if (is_dark) {
                accents = new string[] { resolved.dark_red, resolved.dark_green, resolved.dark_yellow, resolved.dark_blue, resolved.dark_magenta, resolved.dark_cyan };
            } else {
                accents = new string[] { resolved.light_red, resolved.light_green, resolved.light_yellow, resolved.light_blue, resolved.light_magenta, resolved.light_cyan };
            }
            this.build_preview (preview, bg, fg, accents);

            bool is_selected = (this.selected_id == id);
            check.set_visible (is_selected);
            this.id_to_check[id] = check;

            button.clicked.connect (() => {
                this.selected_id = id;
                this.scheme_selected (id);
                this.refresh_selection ();
            });

            // Wrap button in a FlowBoxChild to keep consistent tile sizing
            var tile = new Gtk.FlowBoxChild ();
            tile.set_hexpand (false);
            tile.set_halign (Gtk.Align.FILL);
            tile.set_child (button);
            this.flow.append (tile);
        }

        private StColorScheme resolve_scheme_for_id (string id, StColorScheme? provided) {
            if (id == "system" || provided == null) {
                var s = new GLib.Settings ("io.stillhq.terminal");
                string sys_id = s.get_string ("system-color");
                var scheme = (sys_id != null && sys_id.strip () != "" && sys_id != "default") ? StColorScheme.new_from_id (sys_id) : null;
                if (scheme != null) {
                    return scheme;
                }
                var fallback = get_default_scheme ();
                if (fallback != null) {
                    return fallback;
                }
                // As an ultimate fallback, return provided if not null, otherwise Adwaita by id
                if (provided != null) {
                    return provided;
                }
                var adw = StColorScheme.new_from_id ("adwaita");
                if (adw != null) {
                    return adw;
                }
                // Create a minimal one if everything fails
                return create_basic_fallback_scheme ();
            }
            return provided;
        }

        private void build_preview (Gtk.Box preview, string bg, string fg, string[] accents) {
            // Clear previous children
            Gtk.Widget? child = preview.get_first_child ();
            while (child != null) {
                preview.remove (child);
                child = preview.get_first_child ();
            }

            var area = new Gtk.DrawingArea ();
            area.set_content_width (140);
            area.set_content_height (78);
            preview.append (area);

            // Capture colors
            string c_bg = bg;
            string c_fg = fg;
            string[] c_accents = accents;

            area.set_draw_func ((da, cr, width, height) => {
                Gdk.RGBA rgba;
                // Background
                rgba = Gdk.RGBA (); rgba.parse (c_bg);
                cr.set_source_rgba (rgba.red, rgba.green, rgba.blue, rgba.alpha);
                cr.rectangle (0, 0, width, height);
                cr.fill ();

                int pad = 8;
                int gap = 4;
                int inner_w = width - pad * 2;
                int y = pad;

                // Helper to draw a bar
                void draw_bar (string color, double w_percent, int h) {
                    Gdk.RGBA col = Gdk.RGBA (); col.parse (color);
                    cr.set_source_rgba (col.red, col.green, col.blue, col.alpha);
                    int bar_w = (int)(inner_w * (w_percent / 100.0));
                    cr.rectangle (pad, y, bar_w, h);
                    cr.fill ();
                }

                // Helper to draw a second bar to the right
                void draw_bar_right (string color, double w_percent, int h) {
                    Gdk.RGBA col = Gdk.RGBA (); col.parse (color);
                    cr.set_source_rgba (col.red, col.green, col.blue, col.alpha);
                    int bar_w = (int)(inner_w * (w_percent / 100.0));
                    int x = pad + (int)(inner_w * 0.75) + gap; // start near right side
                    cr.rectangle (x, y, bar_w, h);
                    cr.fill ();
                }

                // Top status line
                draw_bar (c_fg, 70, 6);
                draw_bar_right (c_accents.length > 3 ? c_accents[3] : c_fg, 20, 6);
                y += 6 + gap;

                // Code-like lines
                for (int i = 0; i < 4; i++) {
                    draw_bar (c_fg, 80 - i * 10, 6);
                    draw_bar_right (c_accents[i % c_accents.length], 20 + ((i % 2) * 10), 6);
                    y += 6 + gap;
                }
            });
        }

        private void refresh_selection () {
            foreach (var entry in this.id_to_check.entries) {
                entry.value.set_visible (entry.key == this.selected_id);
            }
        }

        private void refresh_previews () {
            foreach (var entry in this.id_to_preview.entries) {
                string id = entry.key;
                var widget = entry.value;
                var scheme = (id == "system") ? null : StColorScheme.new_from_id (id);
                if (scheme == null && id != "system") {
                    continue;
                }
                bool is_dark = false; var sm3 = Adw.StyleManager.get_default (); if (sm3 != null) {
                    is_dark = sm3.get_dark ();
                }
                var resolved = this.resolve_scheme_for_id (id, scheme);
                string bg = is_dark ? resolved.dark_background_color : resolved.light_background_color;
                string fg = is_dark ? resolved.dark_foreground_color : resolved.light_foreground_color;
                string[] accents;
                if (is_dark) {
                    accents = new string[] { resolved.dark_red, resolved.dark_green, resolved.dark_yellow, resolved.dark_blue, resolved.dark_magenta, resolved.dark_cyan };
                } else {
                    accents = new string[] { resolved.light_red, resolved.light_green, resolved.light_yellow, resolved.light_blue, resolved.light_magenta, resolved.light_cyan };
                }
                this.build_preview (widget, bg, fg, accents);
            }
        }
    }
}

