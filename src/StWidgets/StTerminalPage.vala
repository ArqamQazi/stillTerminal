namespace StillTerminal {

    public class StTerminalPage : Adw.Bin {
        public Adw.StyleManager style_manager;
        public StTerminal terminal;
        public Gtk.ScrolledWindow scrolled_window;
        private Gtk.GestureClick right_click_gesture;
        private Gtk.PopoverMenu context_menu;
        private GLib.SimpleActionGroup page_action_group;
        private SimpleAction paste_action;
        private SimpleAction select_none_action;
        private SimpleAction toggle_read_only_action;

        public StTerminalPage (StSettings settings, StProfile profile) {
            this.terminal = new StTerminal (settings, profile);
            scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.add_css_class ("terminal-scrolled-window");
            scrolled_window.set_overlay_scrolling (true);
            this.set_scrollbar_visibility (settings.show_scrollbar);
            scrolled_window.set_child (this.terminal);

            this.style_manager = Adw.StyleManager.get_default ();

            settings.settings.changed.connect ((key) => {
                if (key == "show-scrollbar") {
                    this.set_scrollbar_visibility (settings.show_scrollbar);
                }
            });
            this.set_child (scrolled_window);

            // Context menu
            create_page_actions ();
            build_context_menu ();
            attach_secondary_click_handler ();
        }

        public void modify_zoom (double zoom) {
            var new_scale = this.terminal.font_scale + zoom;
            if (new_scale < 0.20) {
                new_scale = 0.20;
            } else if (new_scale > 5.0) {
                new_scale = 5.0;
            }
            this.terminal.font_scale = new_scale;
        }

        // Background is handled directly via VTE color configuration

        public void set_scrollbar_visibility (bool visible) {
            var policy = Gtk.PolicyType.AUTOMATIC;
            if (!visible) {
                policy = Gtk.PolicyType.NEVER;
            }
            scrolled_window.set_policy (policy, policy);
        }

        private void build_context_menu () {
            // Create popover menu from model
            context_menu = new Gtk.PopoverMenu.from_model (build_menu_model ());
            context_menu.set_autohide (true);
            context_menu.set_parent (this.terminal);
            // Ensure the popover is tall enough to avoid internal scrolling
            context_menu.set_size_request (-1, 232);
            context_menu.set_has_arrow (false);
        }

        private void attach_secondary_click_handler () {
            right_click_gesture = new Gtk.GestureClick ();
            right_click_gesture.set_button (Gdk.BUTTON_SECONDARY);
            right_click_gesture.released.connect ((n_press, x, y) => {
                // Refresh action sensitivity and rebuild menu so labels reflect current state
                update_context_actions ();
                var model = build_menu_model ();
                context_menu.set_menu_model (model);

                // Position the popover near the click location

                // Position the context menu near the click using current size API
                int width = this.context_menu.get_width ();
                int height = this.context_menu.get_height ();
                var anchor_rect = Gdk.Rectangle () {
                    x = (int) x + width / 2,
                    y = (int) y + height / 2,
                    width = 1, height = 1
                };
                context_menu.set_pointing_to (anchor_rect);

                context_menu.popup ();
            });
            this.terminal.add_controller (right_click_gesture);
        }

        private GLib.MenuModel build_menu_model () {
            var root = new GLib.Menu ();

            // Clipboard section
            var section_clip = new GLib.Menu ();
            section_clip.append ("Copy", "app.copy");
            section_clip.append ("Paste", "app.paste");
            root.append_section (null, section_clip);

            // Selection section
            var section_select = new GLib.Menu ();
            section_select.append ("Select All", "app.select-all");
            section_select.append ("Select None", "page.select-none");
            root.append_section (null, section_select);

            // Misc section
            var section_misc = new GLib.Menu ();
            string ro_label = this.terminal.get_input_enabled () ? "Enable Read-Only" : "Disable Read-Only";
            section_misc.append (ro_label, "page.toggle-read-only");
            section_misc.append ("Preferences…", "app.preferences");
            root.append_section (null, section_misc);

            return root as GLib.MenuModel;
        }

        private void create_page_actions () {
            page_action_group = new GLib.SimpleActionGroup ();

            // Paste action (enabled only when input is allowed)
            paste_action = new SimpleAction ("paste", null);
            paste_action.activate.connect ((parameter) => {
                this.terminal.paste_clipboard ();
            });
            page_action_group.add_action (paste_action);

            // Select None action
            select_none_action = new SimpleAction ("select-none", null);
            select_none_action.activate.connect ((parameter) => {
                this.terminal.unselect_all ();
            });
            page_action_group.add_action (select_none_action);

            // Read-only toggle (non-stateful; label changes dynamically)
            toggle_read_only_action = new SimpleAction ("toggle-read-only", null);
            toggle_read_only_action.activate.connect ((parameter) => {
                bool currently_enabled = this.terminal.get_input_enabled ();
                this.terminal.set_input_enabled (!currently_enabled);
                // Update paste action sensitivity after toggling
                update_context_actions ();
            });
            page_action_group.add_action (toggle_read_only_action);

            // Attach action group to terminal so the popover can resolve actions with prefix "page"
            this.terminal.insert_action_group ("page", page_action_group);
        }

        private void update_context_actions () {
            bool input_enabled = this.terminal.get_input_enabled ();
            if (paste_action != null) {
                paste_action.set_enabled (input_enabled);
            }
        }
    }
}