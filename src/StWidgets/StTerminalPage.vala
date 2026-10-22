namespace StillTerminal {

    public class StTerminalPage : Adw.Bin {
        public Adw.StyleManager style_manager;
        public StTerminal terminal;
        public Gtk.ScrolledWindow scrolled_window;
        private Gtk.GestureClick right_click_gesture;
        private Gtk.GestureClick hyperlink_click_gesture;
        private Gtk.PopoverMenu context_menu;
        private GLib.SimpleActionGroup page_action_group;
        private SimpleAction paste_action;
        private SimpleAction select_none_action;
        private SimpleAction toggle_read_only_action;
        private SimpleAction open_in_file_manager_action;
        private SimpleAction open_link_action;
        private SimpleAction copy_link_action;
        private string? context_hyperlink = null;

        public StTerminalPage (
            StSettings settings,
            StProfile profile,
            string[]? command_override = null
        ) {
            this.terminal = new StTerminal (settings, profile, command_override);
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
            attach_hyperlink_click_handler ();
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
            context_menu.set_size_request (-1, get_context_menu_height ());
            context_menu.set_has_arrow (false);
        }

        private void attach_secondary_click_handler () {
            right_click_gesture = new Gtk.GestureClick ();
            right_click_gesture.set_button (Gdk.BUTTON_SECONDARY);
            right_click_gesture.released.connect ((n_press, x, y) => {
                // Remember the OSC 8 link under the pointer, if any, so the
                // menu can offer actions for it.
                this.context_hyperlink = this.terminal.get_hyperlink_at (x, y);

                // Refresh action sensitivity and rebuild menu so labels reflect current state
                update_context_actions ();
                var model = build_menu_model ();
                context_menu.set_menu_model (model);
                context_menu.set_size_request (-1, get_context_menu_height ());

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

        /**
         * Open OSC 8 hyperlinks the way GNOME Terminal does: Ctrl+click on
         * the link. Plain clicks are left alone so text selection keeps
         * working.
         */
        private void attach_hyperlink_click_handler () {
            hyperlink_click_gesture = new Gtk.GestureClick ();
            hyperlink_click_gesture.set_button (0);
            hyperlink_click_gesture.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            hyperlink_click_gesture.pressed.connect ((n_press, x, y) => {
                if (n_press != 1) {
                    return;
                }

                string? uri = this.terminal.get_hyperlink_at (x, y);
                var button = hyperlink_click_gesture.get_current_button ();
                var state = hyperlink_click_gesture.get_current_event_state ();

                if (!StHyperlinkPolicy.should_open (button, state, uri)) {
                    return;
                }

                if (open_hyperlink (uri)) {
                    hyperlink_click_gesture.set_state (Gtk.EventSequenceState.CLAIMED);
                }
            });
            this.terminal.add_controller (hyperlink_click_gesture);
        }

        private bool open_hyperlink (string uri) {
            if (!StHyperlink.is_openable (uri)) {
                warning ("Refusing to open unsupported hyperlink target: %s", uri);
                return false;
            }

            string? target = StHyperlink.normalize (uri);
            if (target == null) {
                return false;
            }

            string? path = StHyperlink.local_path_of (target);
            if (path != null) {
                open_local_path (path);
            } else {
                launch_uri (target);
            }
            return true;
        }

        /**
         * Open a local file or directory.
         *
         * This deliberately goes through GIO rather than Gtk.UriLauncher.
         * When a desktop portal is running, Gtk.UriLauncher hands the URI to
         * the portal's OpenURI interface, which rejects file: URIs outright
         * (its scheme handler only knows about x-scheme-handler/*), and the
         * user just sees "The application launch failed". GIO talks to the
         * default handler for the file directly, which is what GNOME Terminal
         * does too.
         */
        private void open_local_path (string path) {
            string uri;
            try {
                uri = GLib.Filename.to_uri (path, null);
            } catch (GLib.ConvertError e) {
                warning ("Cannot build a URI for %s: %s", path, e.message);
                return;
            }

            try {
                GLib.AppInfo.launch_default_for_uri (uri, make_launch_context ());
                return;
            } catch (Error e) {
                // Falls through: a sandboxed build has no direct access to the
                // host's handlers and needs the portal instead.
                debug ("GIO could not open %s (%s), trying the portal", uri, e.message);
            }

            var launcher = new Gtk.FileLauncher (GLib.File.new_for_path (path));
            launcher.launch.begin (this.get_root () as Gtk.Window, null, (obj, res) => {
                try {
                    launcher.launch.end (res);
                } catch (Error e) {
                    warning ("Failed to open %s: %s", path, e.message);
                }
            });
        }

        private void launch_uri (string uri) {
            var launcher = new Gtk.UriLauncher (uri);
            launcher.launch.begin (this.get_root () as Gtk.Window, null, (obj, res) => {
                try {
                    launcher.launch.end (res);
                } catch (Error e) {
                    warning ("Failed to open hyperlink: %s", e.message);
                }
            });
        }

        private GLib.AppLaunchContext? make_launch_context () {
            var display = Gdk.Display.get_default ();
            if (display == null) {
                return null;
            }
            var context = display.get_app_launch_context ();
            context.set_timestamp (hyperlink_click_gesture.get_current_event_time ());
            return context;
        }

        private GLib.MenuModel build_menu_model () {
            var root = new GLib.Menu ();

            // Clipboard section
            var section_clip = new GLib.Menu ();
            section_clip.append (_ ("Copy"), "win.copy");
            section_clip.append (_ ("Paste"), "win.paste");
            root.append_section (null, section_clip);

            // Selection section
            var section_select = new GLib.Menu ();
            section_select.append (_ ("Select All"), "app.select-all");
            section_select.append (_ ("Select None"), "page.select-none");
            root.append_section (null, section_select);

            // Hyperlink section (only when the pointer is over an OSC 8 link)
            if (this.context_hyperlink != null) {
                var section_link = new GLib.Menu ();
                section_link.append (_ ("Open Link"), "page.open-link");
                section_link.append (_ ("Copy Link"), "page.copy-link");
                root.append_section (null, section_link);
            }

            // File manager section (only for system profiles)
            if (this.terminal.profile.type == StProfileType.SYSTEM) {
                var section_file_manager = new GLib.Menu ();
                section_file_manager.append (_ ("Open Current Directory in Files"), "page.open-in-file-manager");
                root.append_section (null, section_file_manager);
            }

            // Misc section
            var section_misc = new GLib.Menu ();
            string ro_label = this.terminal.get_input_enabled () ? _ ("Enable Read-Only") : _ ("Disable Read-Only");
            section_misc.append (ro_label, "page.toggle-read-only");
            section_misc.append (_ ("Preferences…"), "win.preferences");
            root.append_section (null, section_misc);

            return root as GLib.MenuModel;
        }

        private int get_context_menu_height () {
            int height = this.terminal.profile.type == StProfileType.SYSTEM ? 277 : 239;
            if (this.context_hyperlink != null) {
                // Room for the "Open Link" and "Copy Link" rows and their separator.
                height += 76;
            }
            return height;
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

            // Open current directory in file manager
            open_in_file_manager_action = new SimpleAction ("open-in-file-manager", null);
            open_in_file_manager_action.activate.connect ((parameter) => {
                string? uri = this.terminal.get_file_manager_uri ();
                if (uri != null) {
                    try {
                        GLib.AppInfo.launch_default_for_uri (uri, null);
                    } catch (Error e) {
                        warning (_ ("Failed to open file manager: %s"), e.message);
                    }
                }
            });
            page_action_group.add_action (open_in_file_manager_action);

            // Open the OSC 8 link captured when the context menu was opened
            open_link_action = new SimpleAction ("open-link", null);
            open_link_action.activate.connect ((parameter) => {
                if (this.context_hyperlink != null) {
                    open_hyperlink (this.context_hyperlink);
                }
            });
            page_action_group.add_action (open_link_action);

            // Copy the OSC 8 link target to the clipboard
            copy_link_action = new SimpleAction ("copy-link", null);
            copy_link_action.activate.connect ((parameter) => {
                if (this.context_hyperlink != null) {
                    this.terminal.get_clipboard ().set_text (this.context_hyperlink);
                }
            });
            page_action_group.add_action (copy_link_action);

            // Attach action group to terminal so the popover can resolve actions with prefix "page"
            this.terminal.insert_action_group ("page", page_action_group);
        }

        private void update_context_actions () {
            bool input_enabled = this.terminal.get_input_enabled ();
            if (paste_action != null) {
                paste_action.set_enabled (input_enabled);
            }
            if (open_link_action != null) {
                open_link_action.set_enabled (StHyperlink.is_openable (this.context_hyperlink));
            }
            if (copy_link_action != null) {
                copy_link_action.set_enabled (this.context_hyperlink != null);
            }
        }
    }
}
