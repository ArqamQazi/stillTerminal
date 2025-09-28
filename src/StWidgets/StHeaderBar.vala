namespace StillTerminal {
    public class StHeaderBar : Adw.Bin {
        public Adw.WindowTitle window_title;
        MainWindow main_window;
        Adw.TabBar tab_bar;
        Gtk.Button tab_overview_button;
        Gtk.Button new_tab_button;
        Gtk.MenuButton menu_button;
        Gtk.Box box;

        public StHeaderBar (MainWindow main_window) {
            this.main_window = main_window;

            // Connect to fullscreen state changes to update menu text
            var fullscreen_action = main_window.get_application ().lookup_action ("fullscreen") as SimpleAction;
            if (fullscreen_action != null) {
                fullscreen_action.change_state.connect ((state) => {
                    update_fullscreen_menu_item_label ();
                });
            }
            var window_handle = new Gtk.WindowHandle();
            this.add_css_class ("custom-headerbar");
            window_handle.add_css_class ("custom-headerbar");
            this.child = window_handle;

            this.box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            window_handle.child = this.box;

            var start_controls = new Gtk.WindowControls(Gtk.PackType.START);
            start_controls.add_css_class("custom-headerbar");
            start_controls.set_margin_start(5);
            this.box.append(start_controls);

            // Tab overview button on the left side of the title bar
            this.tab_overview_button = new Gtk.Button ();
            this.tab_overview_button.add_css_class ("flat");
            this.tab_overview_button.remove_css_class ("circular");
            this.tab_overview_button.set_valign (Gtk.Align.CENTER);
            this.tab_overview_button.set_halign (Gtk.Align.START);
            this.tab_overview_button.set_icon_name ("multitasking-symbolic");
            this.tab_overview_button.clicked.connect (() => {
                if (this.main_window.tab_overview != null) {
                    bool is_open = this.main_window.tab_overview.get_open ();
                    this.main_window.tab_overview.set_open (!is_open);
                }
            });
            this.box.append (this.tab_overview_button);

            //  var tab_button = new Gtk.Button.from_icon_name ("view-grid-symbolic");
            //  tab_button.set_valign(Gtk.Align.CENTER);
            //  tab_button.clicked.connect (() => {
            //      this.main_window.tab_view.set_visible (!this.main_window.tab_view.get_visible ());
            //  });
            //  add_button_to_box (tab_button);

            var tab_overlay = new Gtk.Overlay();
            tab_overlay.hexpand = true;
            tab_overlay.halign = Gtk.Align.FILL;
            this.box.append (tab_overlay);

            this.window_title = new Adw.WindowTitle("stillTerminal", "");
            this.window_title.set_halign (Gtk.Align.CENTER);
            this.window_title.set_margin_top(20);
            this.window_title.set_margin_bottom(19);
            tab_overlay.set_child(this.window_title);

            this.tab_bar = new Adw.TabBar ();
            this.tab_bar.set_hexpand (true);
            this.tab_bar.set_halign (Gtk.Align.FILL);
            this.tab_bar.set_view(this.main_window.tab_view);
            this.tab_bar.set_margin_end(5);
            tab_overlay.add_overlay(this.tab_bar);

            this.new_tab_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            this.new_tab_button.valign = Gtk.Align.CENTER;
            this.new_tab_button.halign = Gtk.Align.CENTER;
            this.new_tab_button.add_css_class ("flat");
            this.new_tab_button.remove_css_class ("circular");
            //  this.new_tab_button.set_margin_end(5);
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
            this.menu_button.set_margin_end (5);
            this.menu_button.vexpand = true;
            this.menu_button.set_valign (Gtk.Align.CENTER);

            // Build a standard menu model like other Libadwaita apps
            var root = new GLib.Menu ();

            // Appearance radio group (System/Light/Dark) using a single stateful action
            var appearance = new GLib.Menu ();
            var item_system = new GLib.MenuItem ("System", "app.color-scheme");
            item_system.set_attribute_value ("target", new GLib.Variant.string ("system"));
            appearance.append_item (item_system);

            var item_light = new GLib.MenuItem ("Light", "app.color-scheme");
            item_light.set_attribute_value ("target", new GLib.Variant.string ("light"));
            appearance.append_item (item_light);

            var item_dark = new GLib.MenuItem ("Dark", "app.color-scheme");
            item_dark.set_attribute_value ("target", new GLib.Variant.string ("dark"));
            appearance.append_item (item_dark);

            root.append_section (null, appearance);

            // Zoom controls
            var zoom = new GLib.Menu ();
            zoom.append ("Zoom In", "app.zoom-in");
            zoom.append ("Zoom Out", "app.zoom-out");
            zoom.append ("Reset Zoom", "app.zoom-reset");
            root.append_section (null, zoom);

            // Window
            var window = new GLib.Menu ();
            var fullscreen_item = new GLib.MenuItem ("Fullscreen", "app.fullscreen");
            fullscreen_item.set_attribute_value ("toggle-type", new GLib.Variant.string ("checkmark"));
            window.append_item (fullscreen_item);
            root.append_section (null, window);

            // App
            var app_menu = new GLib.Menu ();
            app_menu.append ("Preferences…", "app.preferences");
            app_menu.append ("About stillTerminal", "app.about");
            root.append_section (null, app_menu);

            this.menu_button.set_menu_model (root as GLib.MenuModel);
            this.box.append (this.menu_button);
            
            var end_controls = new Gtk.WindowControls (Gtk.PackType.END);
            end_controls.set_margin_end (5);
            end_controls.add_css_class ("custom-headerbar");
            this.box.append (end_controls);
        }

        public void add_button_to_box(Gtk.Button button) {
            button.add_css_class ("flat");
            button.remove_css_class ("circular");
            button.set_margin_end(5);
            button.vexpand = true;
            button.valign = Gtk.Align.CENTER;
            this.box.append (button);
        }

        private void update_fullscreen_menu_item_label () {
            var fullscreen_action = this.main_window.get_application ().lookup_action ("fullscreen") as SimpleAction;
            if (fullscreen_action == null) return;

            bool is_fullscreen = fullscreen_action.get_state ().get_boolean ();
            string label = is_fullscreen ? "Leave Fullscreen" : "Fullscreen";

            // For a more robust solution, we could create a custom menu model
            // that supports dynamic labels, but for now we'll rebuild the menu
            // This is acceptable since menu rebuilding is not performance-critical
            var root = new GLib.Menu ();

            // Appearance radio group (preserve current state if possible)
            var appearance = new GLib.Menu ();
            var item_system = new GLib.MenuItem ("System", "app.color-scheme");
            item_system.set_attribute_value ("target", new GLib.Variant.string ("system"));
            appearance.append_item (item_system);

            var item_light = new GLib.MenuItem ("Light", "app.color-scheme");
            item_light.set_attribute_value ("target", new GLib.Variant.string ("light"));
            appearance.append_item (item_light);

            var item_dark = new GLib.MenuItem ("Dark", "app.color-scheme");
            item_dark.set_attribute_value ("target", new GLib.Variant.string ("dark"));
            appearance.append_item (item_dark);

            root.append_section (null, appearance);

            // Zoom controls
            var zoom = new GLib.Menu ();
            zoom.append ("Zoom In", "app.zoom-in");
            zoom.append ("Zoom Out", "app.zoom-out");
            zoom.append ("Reset Zoom", "app.zoom-reset");
            root.append_section (null, zoom);

            // Window section with updated fullscreen item
            var window = new GLib.Menu ();
            var fullscreen_item = new GLib.MenuItem (label, "app.fullscreen");
            fullscreen_item.set_attribute_value ("toggle-type", new GLib.Variant.string ("checkmark"));
            window.append_item (fullscreen_item);
            root.append_section (null, window);

            // App
            var app_menu = new GLib.Menu ();
            app_menu.append ("Preferences…", "app.preferences");
            app_menu.append ("About stillTerminal", "app.about");
            root.append_section (null, app_menu);

            this.menu_button.set_menu_model (root as GLib.MenuModel);
        }
    }
}
