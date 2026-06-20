namespace StillTerminal {
    public class StHeaderBar : Adw.Bin {
        public Adw.WindowTitle window_title;
        MainWindow main_window;
        Adw.TabBar tab_bar;
        Gtk.Button tab_overview_button;
        Gtk.Button new_tab_button;
        Gtk.MenuButton menu_button;
        Gtk.Box box;

        private Gtk.CssProvider theme_provider;
        private string unique_class;
        private static int instance_counter = 0;

        static construct {
            // Adopt the native "headerbar" CSS name so libadwaita's default
            // headerbar rules (windowcontrols, backdrop, button states, ...)
            // apply to this Adw.Bin. This is the same trick Black Box uses
            // and it's what keeps the native window buttons working.
            set_css_name ("headerbar");
        }

        public StHeaderBar (MainWindow main_window) {
            this.main_window = main_window;

            // Per-instance CSS provider so each window can paint its header
            // to match its currently-selected tab's terminal background.
            instance_counter++;
            this.unique_class = "st-headerbar-%d".printf (instance_counter);

            this.theme_provider = new Gtk.CssProvider ();
            var display = Gdk.Display.get_default ();
            if (display != null) {
                Gtk.StyleContext.add_provider_for_display (
                    display,
                    this.theme_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1
                );
            }

            // Only the outer headerbar widget gets these classes. Children
            // inherit styling through the native "headerbar" css name above
            // so windowcontrols, buttons, and the window handle keep their
            // stock libadwaita appearance and behavior.
            this.add_css_class ("custom-headerbar");
            this.add_css_class ("flat");
            this.add_css_class (this.unique_class);

            // Connect to fullscreen state changes to update menu text
            var fullscreen_action = main_window.get_application ().lookup_action ("fullscreen") as SimpleAction;
            if (fullscreen_action != null) {
                fullscreen_action.change_state.connect ((state) => {
                    update_fullscreen_menu_item_label ();
                });
            }
            var window_handle = new Gtk.WindowHandle ();
            this.child = window_handle;

            this.box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            window_handle.child = this.box;

            var start_controls = new Gtk.WindowControls (Gtk.PackType.START);
            this.box.append (start_controls);

            // Tab overview button on the left side of the title bar
            this.tab_overview_button = new Gtk.Button ();
            this.tab_overview_button.add_css_class ("flat");
            this.tab_overview_button.remove_css_class ("circular");
            this.tab_overview_button.set_valign (Gtk.Align.CENTER);
            this.tab_overview_button.set_icon_name ("multitasking-symbolic");
            this.tab_overview_button.clicked.connect (() => {
                if (this.main_window.tab_overview != null) {
                    bool is_open = this.main_window.tab_overview.get_open ();
                    this.main_window.tab_overview.set_open (!is_open);
                }
            });
            this.box.append (this.tab_overview_button);

            var tab_overlay = new Gtk.Overlay ();
            tab_overlay.hexpand = true;
            tab_overlay.halign = Gtk.Align.FILL;
            this.box.append (tab_overlay);

            this.window_title = new Adw.WindowTitle (_ ("stillTerminal"), "");
            this.window_title.set_halign (Gtk.Align.CENTER);
            this.window_title.set_margin_top (20);
            this.window_title.set_margin_bottom (19);
            tab_overlay.set_child (this.window_title);

            this.tab_bar = new Adw.TabBar ();
            this.tab_bar.set_hexpand (true);
            this.tab_bar.set_halign (Gtk.Align.FILL);
            this.tab_bar.set_view (this.main_window.tab_view);
            // Black Box's tab bar pattern: the `.inline` style makes the
            // tab bar background transparent so the headerbar paints through.
            this.tab_bar.add_css_class ("inline");
            tab_overlay.add_overlay (this.tab_bar);

            // Only show the centered window title when a single tab is open.
            // Otherwise the tab bar covers the same area and the title bleeds
            // through behind the tabs.
            this.update_title_visibility ();
            this.main_window.tab_view.notify["n-pages"].connect (() => {
                this.update_title_visibility ();
            });

            this.new_tab_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            this.new_tab_button.valign = Gtk.Align.CENTER;
            this.new_tab_button.halign = Gtk.Align.CENTER;
            this.new_tab_button.add_css_class ("flat");
            this.new_tab_button.remove_css_class ("circular");
            this.new_tab_button.vexpand = true;
            this.new_tab_button.valign = Gtk.Align.CENTER;
            // Use a gesture controller to detect modifiers reliably on release
            var new_tab_click = new Gtk.GestureClick ();
            new_tab_click.set_button (Gdk.BUTTON_PRIMARY);
            new_tab_click.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            new_tab_click.released.connect ((n_press, x, y) => {
                var state = new_tab_click.get_current_event_state ();
                bool open_recent = ((state & Gdk.ModifierType.SHIFT_MASK) != 0) || ((state & Gdk.ModifierType.CONTROL_MASK) != 0);
                if (open_recent) {
                    var profile = this.main_window.get_last_or_default_profile ();
                    this.main_window.add_tab (profile);
                } else {
                    var dialog = new StNewTabDialog (this.main_window);
                    dialog.present (this.main_window);
                }
            });
            this.new_tab_button.add_controller (new_tab_click);
            this.box.append (this.new_tab_button);

            // Menu button replacing the settings button
            this.menu_button = new Gtk.MenuButton ();
            this.menu_button.set_icon_name ("menu-large-symbolic");
            this.menu_button.add_css_class ("flat");
            this.menu_button.vexpand = true;
            this.menu_button.set_valign (Gtk.Align.CENTER);

            // Build a standard menu model like other Libadwaita apps
            var root = new GLib.Menu ();

            // Appearance radio group (System/Light/Dark) using a single stateful action
            var appearance = new GLib.Menu ();
            var item_system = new GLib.MenuItem (_ ("System"), "app.color-scheme");
            item_system.set_attribute_value ("target", new GLib.Variant.string ("system"));
            appearance.append_item (item_system);

            var item_light = new GLib.MenuItem (_ ("Light"), "app.color-scheme");
            item_light.set_attribute_value ("target", new GLib.Variant.string ("light"));
            appearance.append_item (item_light);

            var item_dark = new GLib.MenuItem (_ ("Dark"), "app.color-scheme");
            item_dark.set_attribute_value ("target", new GLib.Variant.string ("dark"));
            appearance.append_item (item_dark);

            root.append_section (null, appearance);

            // Zoom controls
            var zoom = new GLib.Menu ();
            zoom.append (_ ("Zoom In"), "app.zoom-in");
            zoom.append (_ ("Zoom Out"), "app.zoom-out");
            zoom.append (_ ("Reset Zoom"), "app.zoom-reset");
            root.append_section (null, zoom);

            // Window
            var window = new GLib.Menu ();
            window.append (_ ("New Window"), "app.new-window");
            var fullscreen_item = new GLib.MenuItem (_ ("Fullscreen"), "win.fullscreen");
            fullscreen_item.set_attribute_value ("toggle-type", new GLib.Variant.string ("checkmark"));
            window.append_item (fullscreen_item);
            root.append_section (null, window);

            // App
            var app_menu = new GLib.Menu ();
            app_menu.append (_ ("Preferences…"), "win.preferences");
            app_menu.append (_ ("About stillTerminal"), "app.about");
            root.append_section (null, app_menu);

            this.menu_button.set_menu_model (root as GLib.MenuModel);
            this.box.append (this.menu_button);

            var end_controls = new Gtk.WindowControls (Gtk.PackType.END);
            this.box.append (end_controls);
        }

        private void update_title_visibility () {
            if (this.main_window == null || this.window_title == null) {
                return;
            }
            this.window_title.visible = (this.main_window.tab_view.n_pages <= 1);
        }

        public void add_button_to_box (Gtk.Button button) {
            button.add_css_class ("flat");
            button.remove_css_class ("circular");
            button.set_margin_end (5);
            button.vexpand = true;
            button.valign = Gtk.Align.CENTER;
            this.box.append (button);
        }

        /**
         * Paint the header bar with the terminal's background and
         * foreground colors. Because this widget's css name is "headerbar",
         * libadwaita's native headerbar styling handles windowcontrols,
         * buttons, and the tab bar. We only override the background/foreground
         * (in both focused and :backdrop states, with matching 200ms timings
         * to line up with Adwaita's own backdrop transition) and disable
         * Adwaita's :backdrop opacity filter so the title bar keeps the
         * same colors when the window loses focus.
         */
        public void set_theme_colors (Gdk.RGBA background, Gdk.RGBA foreground) {
            string bg_css = StTerminal.rgba_to_css (background);
            string fg_css = StTerminal.rgba_to_css (foreground);
            string cls = this.unique_class;

            string css = (
                ".%1$s,\n" +
                ".%1$s:backdrop {\n" +
                "  background-color: %2$s;\n" +
                "  color: %3$s;\n" +
                "  transition: background-color 200ms ease-out, color 200ms ease-out;\n" +
                "}\n" +
                ".%1$s:backdrop > windowhandle {\n" +
                "  filter: none;\n" +
                "  transition: filter 200ms ease-out;\n" +
                "}\n"
            ).printf (cls, bg_css, fg_css);

            this.theme_provider.load_from_string (css);
        }

        /**
         * Remove the per-window CSS provider from the display. Call this
         * when the owning window is being destroyed so rules referring to
         * its unique class do not accumulate.
         */
        public void cleanup () {
            var display = Gdk.Display.get_default ();
            if (display != null && this.theme_provider != null) {
                Gtk.StyleContext.remove_provider_for_display (
                    display, this.theme_provider
                );
            }
        }

        private void update_fullscreen_menu_item_label () {
            var fullscreen_action = this.main_window.lookup_action ("fullscreen") as SimpleAction;
            if (fullscreen_action == null) {
                return;
            }

            bool is_fullscreen = fullscreen_action.get_state ().get_boolean ();
            string label = is_fullscreen ? _ ("Leave Fullscreen") : _ ("Fullscreen");

            // For a more robust solution, we could create a custom menu model
            // that supports dynamic labels, but for now we'll rebuild the menu
            // This is acceptable since menu rebuilding is not performance-critical
            var root = new GLib.Menu ();

            // Appearance radio group (preserve current state if possible)
            var appearance = new GLib.Menu ();
            var item_system = new GLib.MenuItem (_ ("System"), "app.color-scheme");
            item_system.set_attribute_value ("target", new GLib.Variant.string ("system"));
            appearance.append_item (item_system);

            var item_light = new GLib.MenuItem (_ ("Light"), "app.color-scheme");
            item_light.set_attribute_value ("target", new GLib.Variant.string ("light"));
            appearance.append_item (item_light);

            var item_dark = new GLib.MenuItem (_ ("Dark"), "app.color-scheme");
            item_dark.set_attribute_value ("target", new GLib.Variant.string ("dark"));
            appearance.append_item (item_dark);

            root.append_section (null, appearance);

            // Zoom controls
            var zoom = new GLib.Menu ();
            zoom.append (_ ("Zoom In"), "app.zoom-in");
            zoom.append (_ ("Zoom Out"), "app.zoom-out");
            zoom.append (_ ("Reset Zoom"), "app.zoom-reset");
            root.append_section (null, zoom);

            // Window section with updated fullscreen item
            var window = new GLib.Menu ();
            window.append (_ ("New Window"), "app.new-window");
            var fullscreen_item = new GLib.MenuItem (label, "win.fullscreen");
            fullscreen_item.set_attribute_value ("toggle-type", new GLib.Variant.string ("checkmark"));
            window.append_item (fullscreen_item);
            root.append_section (null, window);

            // App
            var app_menu = new GLib.Menu ();
            app_menu.append (_ ("Preferences…"), "win.preferences");
            app_menu.append (_ ("About stillTerminal"), "app.about");
            root.append_section (null, app_menu);

            this.menu_button.set_menu_model (root as GLib.MenuModel);
        }
    }
}
