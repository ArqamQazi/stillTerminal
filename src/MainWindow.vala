namespace StillTerminal {
    public class MainWindow : Adw.ApplicationWindow {
        public Adw.TabBar tab_bar;
        public Adw.TabView tab_view;
        public Adw.TabOverview tab_overview;
        public StillTerminal.StSettings settings;
        public StHeaderBar header;
        public ShortcutController shortcuts = new ShortcutController ();
        private bool new_tab_dialog_showing = false;
        private StTerminal? tracked_terminal = null;
        private ulong tracked_appearance_handler = 0;


        public MainWindow (
            Adw.Application app,
            bool create_initial_tab = true,
            string? working_directory_override = null,
            string[]? command_override = null,
            string? title_override = null,
            double zoom = 1.0,
            bool start_fullscreen = false
        ) {
            Object (application: app);
            this.set_title (_ ("stillTerminal"));

            this.settings = new StillTerminal.StSettings ();
            this.default_height = this.settings.window_height;
            this.default_width = this.settings.window_width;
            if (this.settings.start_maximized) {
                this.maximize ();
            }
            this.add_css_class ("transparent-window");

            // Load the CSS file
            // Adw.Application automatically loads styles from the resource base path
            // (style.css, style-dark.css, etc.). No explicit provider needed here.

            this.tab_view = new Adw.TabView ();
            this.tab_view.page_attached.connect (this.on_page_attached);
            this.header = new StHeaderBar (this);

            // Handle tab closing via tab view (X button, etc.)
            this.tab_view.close_page.connect (on_close_page_request);
            this.tab_view.create_window.connect ((view) => {
                var new_window = new MainWindow (this.get_application () as Adw.Application, false);
                new_window.present ();
                return new_window.tab_view;
            });

            this.tab_view.notify["selected-page"].connect (() => {
                if (this.tab_view.selected_page != null) {
                    set_window_title (this.tab_view.selected_page);
                    var page = this.tab_view.selected_page.get_child () as StTerminalPage;
                    if (page != null) {
                        track_terminal_theme (page.terminal);
                        GLib.Idle.add (() => {
                            page.terminal.grab_focus ();
                            return GLib.Source.REMOVE;
                        });
                    }
                }
            });

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.append (this.header);
            box.append (this.tab_view);

            if (create_initial_tab) {
                var profile = get_default_profile ();
                if (working_directory_override != null && working_directory_override.strip () != "") {
                    profile.working_directory = working_directory_override;
                }
                this.add_tab (profile, command_override, title_override, zoom);
            }

            if (start_fullscreen) {
                this.fullscreen ();
            }

            // Wrap content in a TabOverview so the overview can take over the
            // entire window without the custom header being visible
            this.tab_overview = new Adw.TabOverview ();
            this.tab_overview.set_view (this.tab_view);
            this.tab_overview.set_child (box);
            this.tab_overview.set_open (false);
            // Show window controls in the overview so users can move/close the window
            this.tab_overview.set_show_start_title_buttons (true);
            this.tab_overview.set_show_end_title_buttons (true);

            this.content = this.tab_overview;

            // ACTIONS (Window-level)
            var new_tab_action = new SimpleAction ("new-tab", null);
            new_tab_action.activate.connect (() => {
                this.present_new_tab_dialog ();
            });
            this.add_action (new_tab_action);

            var reopen_last_tab_action = new SimpleAction ("reopen-last-tab", null);
            reopen_last_tab_action.activate.connect (() => {
                var profile = get_last_or_default_profile ();
                this.add_tab (profile);
            });
            this.add_action (reopen_last_tab_action);

            var close_tab_action = new SimpleAction ("close-tab", null);
            close_tab_action.activate.connect (() => {
                var current_page = this.tab_view.get_selected_page ();
                var terminal_page = current_page.get_child () as StTerminalPage;

                if (this.tab_view.get_n_pages () > 1) {
                    // Check if this tab has running processes
                    if (terminal_page != null && terminal_page.terminal.has_running_process ()) {
                        show_close_tab_confirmation_dialog (current_page);
                    } else {
                        this.tab_view.close_page (current_page);
                    }
                } else {
                    // Last tab - use window close which already has process checking
                    this.close ();
                }
            });
            this.add_action (close_tab_action);

            var next_tab_action = new SimpleAction ("next-tab", null);
            next_tab_action.activate.connect (() => {
                var current_page = this.tab_view.get_selected_page ();
                var next_page = this.tab_view.get_nth_page (
                    (this.tab_view.get_page_position (current_page) + 1) % this.tab_view.get_n_pages ()
                    );
                this.tab_view.set_selected_page (next_page);
            });
            this.add_action (next_tab_action);

            var previous_tab_action = new SimpleAction ("previous-tab", null);
            previous_tab_action.activate.connect (() => {
                var current_page = this.tab_view.get_selected_page ();
                var previous_page = this.tab_view.get_nth_page (
                    (this.tab_view.get_page_position (current_page) - 1 + this.tab_view.get_n_pages ()) % this.tab_view.get_n_pages ()
                    );
                this.tab_view.set_selected_page (previous_page);
            });
            this.add_action (previous_tab_action);

            // Window-level copy action (so each window operates on its own terminal)
            var copy_action = new SimpleAction ("copy", null);
            copy_action.activate.connect (() => {
                // Prefer format-aware copy when available
                this.get_current_terminal_page ().terminal.copy_clipboard_format (Vte.Format.TEXT);
            });
            this.add_action (copy_action);

            // Window-level paste action with optional warning dialog
            var paste_action = new SimpleAction ("paste", null);
            paste_action.activate.connect (() => {
                if (this.settings.warn_on_paste) {
                    this.show_paste_warning_dialog ();
                } else {
                    this.get_current_terminal_page ().terminal.paste_clipboard ();
                }
            });
            this.add_action (paste_action);

            var fullscreen_action = new SimpleAction.stateful ("fullscreen", null, new Variant.boolean (false));
            fullscreen_action.activate.connect (() => {
                bool is_fullscreen = fullscreen_action.get_state ().get_boolean ();
                if (is_fullscreen) {
                    this.unfullscreen ();
                    fullscreen_action.set_state (new Variant.boolean (false));
                } else {
                    this.fullscreen ();
                    fullscreen_action.set_state (new Variant.boolean (true));
                }
            });
            this.add_action (fullscreen_action);

            // Listen for window fullscreen state changes to keep action in sync
            // This handles cases where the window is unfullscreened by dragging the headerbar
            this.notify["fullscreened"].connect (() => {
                bool window_is_fullscreen = this.fullscreened;
                bool action_state = fullscreen_action.get_state ().get_boolean ();
                if (window_is_fullscreen != action_state) {
                    fullscreen_action.set_state (new Variant.boolean (window_is_fullscreen));
                }
            });

            var new_window_action = new SimpleAction ("new-window", null);
            new_window_action.activate.connect (() => {
                var win = new MainWindow (this.get_application () as Adw.Application);
                win.present ();
            });
            app.add_action (new_window_action);

            var preferences_action = new SimpleAction ("preferences", null);
            preferences_action.activate.connect (() => {
                if (StPrefsDialog.active_instance != null) {
                    StPrefsDialog.active_instance.window.present ();
                    StPrefsDialog.active_instance.present (StPrefsDialog.active_instance.window);
                } else {
                    var dialog = new StPrefsDialog (this);
                    dialog.present (this);
                }
            });
            this.add_action (preferences_action);

            var zoom_in_action = new SimpleAction ("zoom-in", null);
            zoom_in_action.activate.connect (() => {
                this.get_current_terminal_page ().modify_zoom (0.1);
            });
            app.add_action (zoom_in_action);

            var zoom_out_action = new SimpleAction ("zoom-out", null);
            zoom_out_action.activate.connect (() => {
                this.get_current_terminal_page ().modify_zoom (-0.1);
            });
            app.add_action (zoom_out_action);

            // Zoom reset
            var zoom_reset_action = new SimpleAction ("zoom-reset", null);
            zoom_reset_action.activate.connect (() => {
                var page = this.get_current_terminal_page ();
                if (page != null) {
                    page.terminal.font_scale = 1.0;
                }
            });
            app.add_action (zoom_reset_action);

            // Color scheme as a single stateful string action (system/light/dark)
            var color_scheme_action = new SimpleAction.stateful ("color-scheme", VariantType.STRING, new Variant.string ("system"));
            color_scheme_action.activate.connect ((parameter) => {
                // Menu items pass target as parameter for activate
                if (parameter == null) {
                    return;
                }
                var target = parameter.get_string ();
                color_scheme_action.change_state (new Variant.string (target));
            });
            color_scheme_action.change_state.connect ((parameter) => {
                if (parameter == null) {
                    return;
                }
                var choice = parameter.get_string ();
                var sm = Adw.StyleManager.get_default ();
                switch (choice) {
                        case "light":
                            sm.set_color_scheme (Adw.ColorScheme.FORCE_LIGHT);
                            break;
                        case "dark":
                            sm.set_color_scheme (Adw.ColorScheme.FORCE_DARK);
                            break;
                        default:
                            sm.set_color_scheme (Adw.ColorScheme.DEFAULT);
                            break;
                }
                color_scheme_action.set_state (new Variant.string (choice));
            });
            app.add_action (color_scheme_action);

            // About dialog (non-deprecated)
            var about_action = new SimpleAction ("about", null);
            about_action.activate.connect (() => {
                var about = new Adw.AboutDialog ();
                about.set_application_name (_ ("stillTerminal"));
                about.set_application_icon ("io.stillhq.terminal");
                about.set_developer_name (_ ("stillHQ, LLC"));
                about.set_website ("https://stillhq.io");
                about.set_issue_url ("https://gitlab.com/stillhq/stillTerminal");
                about.set_version (StillTerminal.APP_VERSION);
                about.set_copyright (_ ("© 2026 stillHQ, LLC"));
                string[] credits = { "VTE", "Libadwaita", "GTK" };
                about.add_acknowledgement_section (_ ("Credits"), credits);
                about.present (this);
            });
            app.add_action (about_action);

            // Tab overview actions and shortcuts (Window-level)
            var tab_overview_toggle_action = new SimpleAction ("tab-overview-toggle", null);
            tab_overview_toggle_action.activate.connect (() => {
                this.tab_overview.set_open (!this.tab_overview.get_open ());
            });
            this.add_action (tab_overview_toggle_action);

            var tab_overview_open_action = new SimpleAction ("tab-overview-open", null);
            tab_overview_open_action.activate.connect (() => {
                this.tab_overview.set_open (true);
            });
            this.add_action (tab_overview_open_action);

            // Handle Escape key to close tab overview when it's open
            // This is done with an event controller to avoid capturing Escape when overview is closed
            var tab_overview_key_controller = new Gtk.EventControllerKey ();
            this.tab_overview.add_controller (tab_overview_key_controller);
            tab_overview_key_controller.key_pressed.connect ((keyval, keycode, state) => {
                // Only handle Escape when tab overview is open
                if (this.tab_overview.get_open () && keyval == Gdk.Key.Escape) {
                    this.tab_overview.set_open (false);
                    return true; // Event handled
                }
                return false; // Let event propagate
            });

            var select_all_action = new SimpleAction ("select-all", null);
            select_all_action.activate.connect (() => {
                this.get_current_terminal_page ().terminal.select_all ();
            });
            app.add_action (select_all_action);

            this.settings.refresh_accelerators (app);

            // When the last tab is closed, close the application
            this.tab_view.page_detached.connect ((p) => {
                // If the terminal we were tracking is closed, disconnect our
                // signal handler so we don't leave a reference to a widget
                // that has been detached from the view.
                var detached = p.get_child () as StTerminalPage;
                if (detached != null && detached.terminal == this.tracked_terminal
                    && this.tracked_appearance_handler != 0) {
                    this.tracked_terminal.disconnect (this.tracked_appearance_handler);
                    this.tracked_appearance_handler = 0;
                    this.tracked_terminal = null;
                }

                if (this.tab_view.get_n_pages () == 0) {
                    this.close ();
                }
            });

            // SHORTCUTS
            this.add_controller (shortcuts.controller);
            this.settings.bind_to_shortcut_controller (shortcuts);
            this.shortcuts.refresh_shortcuts ();

            // Handle window close request for process confirmation
            this.close_request.connect (on_close_request);
        }

        public Adw.TabPage add_tab (
            StProfile profile,
            string[]? command_override = null,
            string? title_override = null,
            double zoom = 1.0
        ) {
            bool was_empty = (this.tab_view.get_n_pages () == 0);
            var page = new StTerminalPage (this.settings, profile, command_override);
            Adw.TabPage tab_page = this.tab_view.append (page);

            tab_page.title = title_override != null && title_override.strip () != ""
                ? title_override
                : profile.name;
            page.terminal.font_scale = zoom;
            this.tab_view.set_selected_page (tab_page);
            if (was_empty && this.tab_overview != null) {
                this.tab_overview.set_open (false);
            }

            // Remember this as the most recently opened profile
            this.settings.last_profile_id = profile.id;

            return tab_page;
        }

        private void on_page_attached (Adw.TabPage tab_page, int position) {
            var page = tab_page.get_child () as StTerminalPage;
            if (page == null) {
                return;
            }

            // Connect title listener immediately to catch initial title
            tab_page.notify["title"].connect (() => {
                if (this.tab_view.selected_page == tab_page) {
                    set_window_title (tab_page);
                }
            });

            if (this.tab_view.selected_page == tab_page) {
                set_window_title (tab_page);
            }

            page.terminal.set_tab_page (tab_page);

            // If title is empty (e.g. moved tab might need refresh), try to set it from profile
            if (tab_page.title == "") {
                tab_page.title = page.terminal.profile.name;
            }

            ulong press_any_key_handler_id = page.terminal.press_any_key_close_requested.connect (() => {
                close_terminal_page (tab_page);
            });

            // Clean up signal handlers when page is being closed
            ulong page_detached_handler = 0;
            page_detached_handler = this.tab_view.page_detached.connect ((detached_page) => {
                if (detached_page == tab_page) {
                    page.terminal.disconnect (press_any_key_handler_id);
                    this.tab_view.disconnect (page_detached_handler);
                }
            });
        }

        public StProfile get_last_or_default_profile () {
            var last_id = this.settings.last_profile_id;
            if (last_id != null && last_id.strip () != "") {
                var profiles = get_profiles ();
                foreach (var p in profiles) {
                    if (p.id == last_id) {
                        return p;
                    }
                }
            }
            return get_default_profile ();
        }

        public void set_window_title (Adw.TabPage tab_page) {
            // Set the window title to the tab title, with "stillTerminal" as fallback
            string title = tab_page.title;
            if (title == null || title.strip () == "") {
                title = _ ("stillTerminal");
            }
            this.set_title (title);
            this.header.window_title.set_title (tab_page.title);
        }

        /**
         * Track the given terminal so the header bar keeps its background
         * in sync with the terminal's color scheme. Disconnects the handler
         * from any previously tracked terminal.
         */
        private void track_terminal_theme (StTerminal terminal) {
            if (this.tracked_terminal == terminal) {
                apply_header_theme_from (terminal);
                return;
            }

            if (this.tracked_terminal != null && this.tracked_appearance_handler != 0) {
                this.tracked_terminal.disconnect (this.tracked_appearance_handler);
                this.tracked_appearance_handler = 0;
            }

            this.tracked_terminal = terminal;
            this.tracked_appearance_handler = terminal.appearance_changed.connect (() => {
                apply_header_theme_from (terminal);
            });

            apply_header_theme_from (terminal);
        }

        private void apply_header_theme_from (StTerminal terminal) {
            if (terminal == null || this.header == null) {
                return;
            }
            // set_appearance has not run yet on a freshly created terminal.
            // Skip until the terminal publishes its first set of colors.
            if (terminal.current_background_color.alpha == 0
                && terminal.current_background_color.red == 0
                && terminal.current_background_color.green == 0
                && terminal.current_background_color.blue == 0
                && terminal.current_foreground_color.alpha == 0) {
                return;
            }
            this.header.set_theme_colors (
                terminal.current_background_color,
                terminal.current_foreground_color
            );
        }

        private void present_new_tab_dialog () {
            if (this.new_tab_dialog_showing) {
                return;
            }
            this.new_tab_dialog_showing = true;
            var new_tab = new StNewTabDialog (this);
            new_tab.dialog.closed.connect (() => {
                this.new_tab_dialog_showing = false;
                // Ensure focus returns to the terminal after the dialog closes
                GLib.Idle.add (() => {
                    var page = this.get_current_terminal_page ();
                    if (page != null) {
                        page.terminal.grab_focus ();
                    }
                    return GLib.Source.REMOVE;
                });
            });
            new_tab.present (this);
        }

        public StTerminalPage get_current_terminal_page () {
            return this.tab_view.get_selected_page ().get_child () as StTerminalPage;
        }

        public override void size_allocate (int width, int height, int baseline) {
            if (this.settings.keep_window_size && !this.is_maximized ()) {
                this.settings.window_width = width;
                this.settings.window_height = height;
            }
            base.size_allocate (width, height, baseline);
        }

        /**
         * Check if any terminal tabs have running processes
         * @return true if any tab has running processes, false otherwise
         */
        private bool has_running_processes () {
            for (int i = 0; i < this.tab_view.get_n_pages (); i++) {
                var page = this.tab_view.get_nth_page (i);
                var terminal_page = page.get_child () as StTerminalPage;
                if (terminal_page != null) {
                    var terminal = terminal_page.terminal;
                    if (terminal.has_running_process ()) {
                        return true;
                    }
                }
            }
            return false;
        }

        private bool on_close_request () {
            if (has_running_processes ()) {
                show_close_confirmation_dialog ();
                return true; // Prevent close
            }
            // The window is actually about to go away: drop the per-window
            // CSS provider so its rules don't linger on the display.
            if (this.header != null) {
                this.header.cleanup ();
            }
            return false; // Allow close
        }

        private void show_close_confirmation_dialog () {
            var dialog = new Adw.AlertDialog (
                _ ("Processes are still running"),
                _ ("Closing this window will terminate all running processes. Are you sure you want to continue?")
                );

            dialog.add_response ("cancel", _ ("_Cancel"));
            dialog.add_response ("close", _ ("_Close Window"));
            dialog.set_response_appearance ("close", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response ("cancel");
            dialog.set_close_response ("cancel");

            dialog.response.connect ((response) => {
                if (response == "close") {
                    // Force close without checking processes
                    this.force_close ();
                }
            });

            dialog.present (this);
        }

        /**
         * Show a warning dialog before pasting to remind users about security
         */
        private void show_paste_warning_dialog () {
            var dialog = new Adw.AlertDialog (
                _ ("Paste from Clipboard?"),
                _ ("Only paste commands from sources you trust. Malicious commands can damage your system or compromise your data.")
                );

            dialog.add_response ("cancel", _ ("_Cancel"));
            dialog.add_response ("paste", _ ("_Paste"));
            dialog.set_response_appearance ("paste", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response ("paste");
            dialog.set_close_response ("cancel");

            // Add checkbox to disable future warnings
            var check_button = new Gtk.CheckButton.with_label (_ ("Don't show this warning again"));
            dialog.set_extra_child (check_button);

            dialog.response.connect ((response) => {
                if (check_button.active) {
                    this.settings.warn_on_paste = false;
                }
                if (response == "paste") {
                    this.get_current_terminal_page ().terminal.paste_clipboard ();
                }
            });

            dialog.present (this);
        }

        /**
         * Show confirmation dialog when closing a tab with running processes
         * @param tab_page The tab page to potentially close
         */
        private void show_close_tab_confirmation_dialog (Adw.TabPage tab_page) {
            var dialog = new Adw.AlertDialog (
                _ ("Process is still running"),
                _ ("Closing this tab will terminate the running process. Are you sure you want to continue?")
                );

            dialog.add_response ("cancel", _ ("_Cancel"));
            dialog.add_response ("close", _ ("_Close Tab"));
            dialog.set_response_appearance ("close", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response ("cancel");
            dialog.set_close_response ("cancel");

            dialog.response.connect ((response) => {
                if (response == "close") {
                    // User confirmed, close the tab
                    this.tab_view.close_page_finish (tab_page, true);
                } else {
                    // User cancelled, don't close the tab
                    this.tab_view.close_page_finish (tab_page, false);
                }
            });

            dialog.present (this);
        }

        /**
         * Force close the window without checking for running processes
         * Used when user has already confirmed they want to close despite running processes
         */
        private void force_close () {
            // Disconnect the close_request handler temporarily to avoid recursion
            this.close_request.disconnect (on_close_request);
            if (this.header != null) {
                this.header.cleanup ();
            }
            this.close ();
        }

        /**
         * Handle tab close requests, checking for running processes
         * @param page The tab page being closed
         * @return true to prevent closing, false to allow closing
         */
        private bool on_close_page_request (Adw.TabPage page) {
            var terminal_page = page.get_child () as StTerminalPage;

            if (terminal_page != null && terminal_page.terminal.has_running_process ()) {
                // If this is the last tab, use window close confirmation
                if (this.tab_view.get_n_pages () <= 1) {
                    show_close_confirmation_dialog ();
                    return true; // Prevent the close
                } else {
                    // Show tab-specific confirmation
                    show_close_tab_confirmation_dialog (page);
                    return true; // Prevent the close
                }
            }

            // No running processes, allow closing
            return false;
        }

        private void close_terminal_page (Adw.TabPage tab_page) {
            if (this.tab_view.get_n_pages () > 1) {
                this.tab_view.close_page (tab_page);
            } else {
                this.close ();
            }
        }
    }
}
