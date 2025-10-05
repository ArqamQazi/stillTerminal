namespace StillTerminal {
    public class MainWindow : Adw.ApplicationWindow {
        public Adw.TabBar tab_bar;
        public Adw.TabView tab_view;
        public Adw.TabOverview tab_overview;
        public StillTerminal.StSettings settings;
        public StHeaderBar header;
        public ShortcutController shortcuts = new ShortcutController ();
        private bool new_tab_dialog_showing = false;


        public MainWindow (Adw.Application app) {
            Object (application: app);

            this.settings = new StillTerminal.StSettings ();
            this.default_height = this.settings.window_height;
            this.default_width = this.settings.window_width;
            this.add_css_class ("transparent-window");
    
            // Load the CSS file
            // Adw.Application automatically loads styles from the resource base path
            // (style.css, style-dark.css, etc.). No explicit provider needed here.
    
            this.tab_view = new Adw.TabView ();
            this.header = new StHeaderBar (this);

            // Handle tab closing via tab view (X button, etc.)
            this.tab_view.close_page.connect (on_close_page_request);
    
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.append (this.header);
            box.append (this.tab_view);
    
			this.add_tab (get_last_or_default_profile ());
    
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
    
			// ACTIONS
			var new_tab_action = new SimpleAction ("new-tab", null);
			new_tab_action.activate.connect (() => {
				this.present_new_tab_dialog ();
			});
			app.add_action (new_tab_action);

			var reopen_last_tab_action = new SimpleAction ("reopen-last-tab", null);
			reopen_last_tab_action.activate.connect (() => {
				var profile = get_last_or_default_profile ();
				this.add_tab (profile);
			});
			app.add_action (reopen_last_tab_action);
    
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
            app.add_action (close_tab_action);
            
            var next_tab_action = new SimpleAction ("next-tab", null);
            next_tab_action.activate.connect (() => {
                var current_page = this.tab_view.get_selected_page ();
                var next_page = this.tab_view.get_nth_page (
                    (this.tab_view.get_page_position (current_page) + 1) % this.tab_view.get_n_pages ()
                );
                this.tab_view.set_selected_page (next_page);
            });
            app.add_action (next_tab_action);
    
            var previous_tab_action = new SimpleAction ("previous-tab", null);
            previous_tab_action.activate.connect (() => {
                var current_page = this.tab_view.get_selected_page ();
                var previous_page = this.tab_view.get_nth_page (
                    (this.tab_view.get_page_position (current_page) - 1 + this.tab_view.get_n_pages ()) % this.tab_view.get_n_pages ()
                );
                this.tab_view.set_selected_page (previous_page);
            });
            app.add_action (previous_tab_action);
    
            var copy_action = new SimpleAction ("copy", null);
            copy_action.activate.connect (() => {
                // Prefer format-aware copy when available
                this.get_current_terminal_page ().terminal.copy_clipboard_format (Vte.Format.TEXT);
            });
            app.add_action (copy_action);
    
            var paste_action = new SimpleAction ("paste", null);
            paste_action.activate.connect (() => {
                this.get_current_terminal_page ().terminal.paste_clipboard ();
            });
            app.add_action (paste_action);
    
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
            app.add_action (fullscreen_action);
    
            var new_window_action = new SimpleAction ("new-window", null);
            new_window_action.activate.connect (() => {
                var win = new MainWindow (this.get_application () as Adw.Application);
                win.present ();
            });
            app.add_action (new_window_action);
            
            var preferences_action = new SimpleAction ("preferences", null);
            preferences_action.activate.connect (() => {
                var dialog = new StPrefsDialog (this);
                dialog.present (this);
            });
            app.add_action (preferences_action);
    
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
                if (parameter == null) return;
                var target = parameter.get_string ();
                color_scheme_action.change_state (new Variant.string (target));
            });
            color_scheme_action.change_state.connect ((parameter) => {
                if (parameter == null) return;
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
                about.set_application_name ("stillTerminal");
                about.set_application_icon ("io.stillhq.terminal");
                about.set_developer_name ("stillHQ, LLC");
                about.set_website ("https://stillhq.io");
                about.set_issue_url ("https://gitlab.com/stillhq/stillTerminal");
                about.set_version (StillTerminal.APP_VERSION);
                about.set_copyright ("© 2025 stillHQ, LLC");
                string[] credits = { "VTE", "Libadwaita", "GTK" };
                about.add_acknowledgement_section ("Credits", credits);
                about.present (this);
            });
            app.add_action (about_action);

            // Tab overview actions and shortcuts
            var tab_overview_toggle_action = new SimpleAction ("tab-overview-toggle", null);
            tab_overview_toggle_action.activate.connect (() => {
                this.tab_overview.set_open (!this.tab_overview.get_open ());
            });
            app.add_action (tab_overview_toggle_action);

            var tab_overview_open_action = new SimpleAction ("tab-overview-open", null);
            tab_overview_open_action.activate.connect (() => {
                this.tab_overview.set_open (true);
            });
            app.add_action (tab_overview_open_action);

            var tab_overview_close_action = new SimpleAction ("tab-overview-close", null);
            tab_overview_close_action.activate.connect (() => {
                this.tab_overview.set_open (false);
            });
            app.add_action (tab_overview_close_action);

            var select_all_action = new SimpleAction ("select-all", null);
            select_all_action.activate.connect (() => {
                this.get_current_terminal_page ().terminal.select_all ();
            });
            app.add_action (select_all_action);

		this.settings.refresh_accelerators(app);

		// When the last tab is closed, close the application
		this.tab_view.page_detached.connect ((p) => {
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
    
        public Adw.TabPage add_tab (StProfile profile) {
		bool was_empty = (this.tab_view.get_n_pages () == 0);
		var page = new StTerminalPage (this.settings, profile);
            Adw.TabPage tab_page = this.tab_view.append (page);
            tab_page.title = profile.name;
            page.terminal.set_tab_page (tab_page);
            this.tab_view.set_selected_page (tab_page);
	if (was_empty && this.tab_overview != null) {
		this.tab_overview.set_open (false);
	}
		// Remember this as the most recently opened profile
		this.settings.last_profile_id = profile.id;
    
            // Auto-close when the terminal's child process exits
            ulong child_exited_handler_id = page.terminal.child_exited.connect ((status) => {
                if (this.tab_view.get_n_pages () > 1) {
                    // Close just this tab
                    this.tab_view.close_page (tab_page);
                } else {
                    // Last tab: close the window/app
                    this.close ();
                }
            });

            // Disconnect signal handlers when the tab is closed to prevent use-after-free
            tab_page.notify["selected"].connect (() => {
                set_window_title (tab_page, page.terminal);
            });
            
            tab_page.notify["title"].connect (() => {
                if (this.tab_view.get_n_pages () <= 1 && this.tab_view.get_selected_page () == tab_page) {
                    set_window_title (tab_page, page.terminal);
                }
            });
            
            // Clean up signal handlers when page is being closed
            ulong page_detached_handler = 0;
            page_detached_handler = this.tab_view.page_detached.connect ((detached_page) => {
                if (detached_page == tab_page) {
                    // Disconnect the child_exited handler to prevent crashes
                    page.terminal.disconnect (child_exited_handler_id);
                    // Disconnect this cleanup handler itself
                    this.tab_view.disconnect (page_detached_handler);
                }
            });
    
            return tab_page;
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
    
        public void set_window_title (Adw.TabPage tab_page, StTerminal terminal) {
            size_t _len = 0;
            string? term_title = terminal.get_termprop_string ("xterm.title", out _len);
            this.header.window_title.set_title (
                terminal.profile.name + ": " + (term_title ?? "")
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
			});
			new_tab.present (this);
		}
    
        public StTerminalPage get_current_terminal_page () {
            return this.tab_view.get_selected_page ().get_child () as StTerminalPage;
        }
    
        public override void size_allocate (int width, int height, int baseline) {
            if (this.settings.keep_window_size) {
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
            return false; // Allow close
        }

        private void show_close_confirmation_dialog () {
            var dialog = new Adw.AlertDialog (
                "Processes are still running",
                "Closing this window will terminate all running processes. Are you sure you want to continue?"
            );
            
            dialog.add_response ("cancel", "_Cancel");
            dialog.add_response ("close", "_Close Window");
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
         * Show confirmation dialog when closing a tab with running processes
         * @param tab_page The tab page to potentially close
         */
        private void show_close_tab_confirmation_dialog (Adw.TabPage tab_page) {
            var dialog = new Adw.AlertDialog (
                "Process is still running",
                "Closing this tab will terminate the running process. Are you sure you want to continue?"
            );
            
            dialog.add_response ("cancel", "_Cancel");
            dialog.add_response ("close", "_Close Tab");
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
    }
}