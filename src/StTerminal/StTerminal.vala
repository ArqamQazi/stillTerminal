namespace StillTerminal {
    public class StTerminal : Vte.Terminal {
        public signal void press_any_key_close_requested ();
        public signal void appearance_changed ();

        public StProfile profile;
        public Vte.Terminal vte;
        public StSettings settings;
        public Pango.FontDescription default_font_desc;
        public Adw.StyleManager style_manager;
        public Adw.TabPage? tab_page;
        public Gdk.RGBA current_background_color;
        public Gdk.RGBA current_foreground_color;
        private bool process_running = false;
        private GLib.Pid shell_pid = -1;
        private Gtk.EventControllerKey? close_prompt_controller = null;
        private bool waiting_for_close_key = false;

        public StTerminal (StSettings settings, StProfile profile) {
            Object ();
            this.settings = settings;
            this.profile = profile;
            int scrollback = profile.get_scrollback_lines_setting ();
            if (scrollback < -1) {
                scrollback = StProfile.DEFAULT_SCROLLBACK_LINES;
            }
            this.set_scrollback_lines (scrollback);

            this.style_manager = Adw.StyleManager.get_default ();

            this.vexpand = true;
            this.hexpand = true;
            this.set_enable_fallback_scrolling (true);

            // Used if custom font is disabled
            this.default_font_desc = this.get_font ().copy ();
            this.spawn_profile ();
            this.settings.bind_to_vte (this);

            // Track when child processes exit
            this.child_exited.connect (on_child_exited);
        }

        public void set_tab_page (Adw.TabPage tab_page) {
            this.tab_page = tab_page;
            // Use property notification instead of deprecated signal/getter
            this.notify["window-title"].connect (() => {
                // Use termprop string (xterm.title) to avoid deprecated getter
                size_t _len = 0;
                string? term_title = this.get_termprop_string ("xterm.title", out _len);
                string title = profile.name;
                if (term_title != null && term_title.strip () != "") {
                    title += ": " + term_title;
                }
                this.tab_page.set_title (title);
            });
        }

        public void spawn_profile () {
            set_appearance ();

            // Spawn terminal and track the shell PID
            var argv = get_spawn_list (this.profile);

            this.spawn_async (
                Vte.PtyFlags.DEFAULT,
                this.profile.working_directory,
                argv,
                get_env_for_spawn (this.profile),
                GLib.SpawnFlags.SEARCH_PATH,
                null,
                -1,
                null,
                (terminal, pid, error) => {
                if (error == null) {
                    this.shell_pid = pid;
                    this.process_running = true;
                } else {
                    this.process_running = false;
                    this.shell_pid = -1;
                    string failure = "Failed to start profile \"%s\": %s".printf (this.profile.name, error.message);
                    show_press_any_key_prompt (failure);
                }
            }
                );
        }

        public string[] get_spawn_list (StProfile profile) {
            // no-op: type-specific metadata now in profile.type_params
            switch (profile.type) {
            default:
            if (profile.spawn_command == null) {
                return new string[] { GLib.Environment.get_variable ("SHELL") };
            }
            string[] spawn_args = profile.spawn_command.split (" ");
            if (spawn_args.length == 0) {
                return new string[] { GLib.Environment.get_variable ("SHELL") };
            }

            GLib.File file = GLib.File.new_for_path (spawn_args[0]);
            if (file.query_exists ()) {
                return spawn_args;
            }
            string[] shell_cmd = { GLib.Environment.get_variable ("SHELL"), "-c" };
            foreach (string arg in spawn_args) {
                shell_cmd += arg;
            }
            return shell_cmd;

                case StProfileType.DISTROBOX:
                    // External helper binary (installed separately)
                    string? helper_path = GLib.Environment.find_program_in_path ("st-distrobox");
                    if (helper_path != null) {
                        return { "st-distrobox", "--profile-id", profile.id };
                    }
                    // Fallback: inform user and open their shell
                    string shell = GLib.Environment.get_variable ("SHELL");
                    if (shell == null || shell.strip () == "") {
                        shell = "/bin/sh";
                    }
                    string msg = "echo 'st-distrobox not found in PATH. Please install st-distrobox.'";
                    return { shell, "-c", msg + "; exec " + shell };

                case StProfileType.SSH:
                    var ssh_args = profile.get_ssh_arguments ();
                    if (ssh_args != null) {
                        if (StSecretManager.has_password (profile.id)) {
                            string[] cmd = { "sshpass", "-e" };
                            foreach (string a in ssh_args) {
                                cmd += a;
                            }
                            return cmd;
                        }
                        return ssh_args;
                    }
                    // Fallback to shell if SSH arguments are invalid
                    return new string[] { GLib.Environment.get_variable ("SHELL") };
            }
        }

        private string[]? get_env_for_spawn (StProfile profile) {
            // Only inject SSHPASS env when needed. Otherwise inherit current env (null).
            if (profile.type == StProfileType.SSH) {
                string? pw = StSecretManager.lookup_password (profile.id);
                if (pw != null && pw.length > 0) {
                    string[] envv = GLib.Environ.get ();
                    envv = GLib.Environ.set_variable (envv, "SSHPASS", pw, true);
                    return envv;
                }
            }
            return null;
        }

        public void set_appearance () {
            bool is_dark = this.style_manager.dark;
            string color_scheme_name = this.profile.color_scheme;

            if (color_scheme_name == "system") {
                string system_choice = this.settings.system_color;
                // Per-profile flag in type_params: match_container_theme=true
                if (this.profile.type == StProfileType.DISTROBOX
                    && this.profile.type_params != null
                    && this.profile.type_params.has_key ("match_container_theme")
                    && this.profile.type_params["match_container_theme"] == "true") {
                    string? mapped = map_container_to_scheme_id (this.profile);
                    if (mapped != null && mapped.strip () != "") {
                        // Only use mapped if that scheme actually exists
                        var avail = get_available_schemes ();
                        if (avail.has_key (mapped)) {
                            system_choice = mapped;
                        }
                    }
                }
                color_scheme_name = system_choice;
            }
            var color_scheme = StColorScheme.new_from_id (color_scheme_name);
            if (color_scheme == null) {
                color_scheme = StillTerminal.get_default_scheme ();
            }
            if (color_scheme == null) {
                // Ultimate fallback: avoid null deref; leave defaults
                return;
            }

            // Set color scheme
            Gdk.RGBA bold_color = Gdk.RGBA ();
            Gdk.RGBA cursor_color = Gdk.RGBA ();
            Gdk.RGBA background_color = Gdk.RGBA ();
            Gdk.RGBA foreground_color = Gdk.RGBA ();
            Gdk.RGBA[] palette;

            bool parsed_ok = true;
            if (is_dark) {
                parsed_ok &= bold_color.parse ( color_scheme.dark_bold_color );
                parsed_ok &= cursor_color.parse ( color_scheme.dark_cursor_color );
                parsed_ok &= background_color.parse ( color_scheme.dark_background_color );
                parsed_ok &= foreground_color.parse ( color_scheme.dark_foreground_color );
                palette = color_scheme.get_dark_rgba_palette ();
            } else {
                parsed_ok &= bold_color.parse ( color_scheme.light_bold_color );
                parsed_ok &= cursor_color.parse ( color_scheme.light_cursor_color );
                parsed_ok &= background_color.parse ( color_scheme.light_background_color );
                parsed_ok &= foreground_color.parse ( color_scheme.light_foreground_color );
                palette = color_scheme.get_light_rgba_palette ();
            }

            if (!parsed_ok) {
                bold_color.parse ("#000000");
                cursor_color.parse ( is_dark ? "#ffffff" : "#000000" );
                background_color.parse ( is_dark ? "#000000" : "#ffffff" );
                foreground_color.parse ( is_dark ? "#ffffff" : "#000000" );
                var fb = StillTerminal.get_default_scheme ();
                if (fb != null) {
                    palette = is_dark ? fb.get_dark_rgba_palette () : fb.get_light_rgba_palette ();
                } else {
                    palette = new Gdk.RGBA[16];
                    for (int i = 0; i < 16; i++) {
                        palette[i].parse (is_dark ? "#ffffff" : "#000000");
                    }
                }
            }

            background_color.alpha = (float) this.settings.opacity * 0.01f;

            this.set_color_cursor ( bold_color );
            this.set_color_cursor ( cursor_color );
            this.set_colors (
                foreground_color, background_color, palette
                );

            // Remember current theme colors and notify listeners (e.g. the
            // header bar) so they can match the terminal's appearance.
            this.current_background_color = background_color;
            this.current_foreground_color = foreground_color;
            this.appearance_changed ();

            // Set font
            if (this.settings.use_custom_font) {
                var font_desc = Pango.FontDescription.from_string (this.settings.custom_font);
                this.set_font (font_desc);
            } else {
                this.set_font (this.default_font_desc);
            }
        }

        public static string rgba_to_css (Gdk.RGBA color) {
            int r = (int) (color.red * 255.0f + 0.5f);
            int g = (int) (color.green * 255.0f + 0.5f);
            int b = (int) (color.blue * 255.0f + 0.5f);
            double a = (double) color.alpha;
            if (r < 0) r = 0; else if (r > 255) r = 255;
            if (g < 0) g = 0; else if (g > 255) g = 255;
            if (b < 0) b = 0; else if (b > 255) b = 255;
            if (a < 0.0) a = 0.0; else if (a > 1.0) a = 1.0;
            return "rgba(%d,%d,%d,%.3f)".printf (r, g, b, a);
        }

        private string? map_container_to_scheme_id (StProfile profile) {
            if (profile == null || profile.type != StProfileType.DISTROBOX) {
                return null;
            }
            string image = "";
            if (profile.type_params != null && profile.type_params.has_key ("image") && profile.type_params["image"] != null) {
                image = profile.type_params["image"];
            }
            string haystack = image.strip ();
            if (haystack == "" && profile.icon_name != null) {
                haystack = profile.icon_name;
            }
            haystack = haystack.ascii_down ();

            if (haystack.index_of ("ubuntu") >= 0) {
                return "ubuntu";
            }
            if (haystack.index_of ("debian") >= 0) {
                return "debian";
            }
            if (haystack.index_of ("fedora") >= 0) {
                return "fedora";
            }
            if (haystack.index_of ("arch") >= 0) {
                return "archlinux";
            }
            if (haystack.index_of ("opensuse") >= 0 || haystack.index_of ("tumbleweed") >= 0 || haystack.index_of ("leap") >= 0) {
                return "opensuse";
            }
            if (haystack.index_of ("alpine") >= 0) {
                return "alpine";
            }
            if (haystack.index_of ("almalinux") >= 0) {
                return "almalinux";
            }
            if (haystack.index_of ("centos") >= 0) {
                return "centos";
            }
            if (haystack.index_of ("redhat") >= 0 || haystack.index_of ("rhel") >= 0) {
                return "redhat";
            }

            return null;
        }

        /**
         * Get the current working directory of the terminal's deepest child process.
         * Walks /proc/{pid}/task/{pid}/children to find the innermost process,
         * then reads its CWD. Only supported for SYSTEM profiles.
         * @return the current working directory path, or the profile's initial
         *         working_directory as a fallback
         */
        public string? get_current_directory_path () {
            if (this.profile.type != StProfileType.SYSTEM) {
                return null;
            }

            if (this.shell_pid <= 0 || !this.process_running) {
                return this.profile.working_directory;
            }

            // Walk the process tree to find the deepest child
            int current_pid = (int) this.shell_pid;
            int depth = 0;
            int max_depth = 20; // Safety limit to avoid infinite loops

            while (depth < max_depth) {
                try {
                    string children_path = "/proc/%d/task/%d/children".printf (current_pid, current_pid);
                    string children_content;
                    if (GLib.FileUtils.get_contents (children_path, out children_content)) {
                        string trimmed = children_content.strip ();
                        if (trimmed.length > 0) {
                            string[] child_pids = trimmed.split (" ");
                            if (child_pids.length > 0 && child_pids[0].strip () != "") {
                                int child_pid = int.parse (child_pids[0].strip ());
                                if (child_pid > 0) {
                                    current_pid = child_pid;
                                    depth++;
                                    continue;
                                }
                            }
                        }
                    }
                } catch (Error e) {
                    break;
                }
                break;
            }

            // Read the CWD of the deepest process
            try {
                string cwd = GLib.FileUtils.read_link ("/proc/%d/cwd".printf (current_pid));
                if (cwd != null && cwd.strip () != "") {
                    return cwd;
                }
            } catch (Error e) {
                // Fall through to fallback
            }

            return this.profile.working_directory;
        }

        /**
         * Construct a file:// URI for opening the current directory in a
         * file manager. Only supported for SYSTEM profiles.
         * @return a URI string suitable for GLib.AppInfo.launch_default_for_uri,
         *         or null if unsupported or the URI cannot be constructed
         */
        public string? get_file_manager_uri () {
            string? dir = get_current_directory_path ();
            if (dir != null) {
                return "file://" + dir;
            }
            return null;
        }

        /**
         * Called when the shell process exits
         * @param status Exit status of the shell
         */
        private void on_child_exited (int status) {
            this.process_running = false;
            show_press_any_key_prompt (describe_exit_status (status));
        }

        public bool has_running_process () {
            // Check if we have a valid PTY and shell process
            var pty = this.get_pty ();
            if (pty == null || !this.process_running || this.shell_pid == -1) {
                return false;
            }

            // Check for child processes using /proc filesystem
            try {
                string children_path = "/proc/%d/task/%d/children".printf ((int)this.shell_pid, (int)this.shell_pid);
                string children_content;
                if (GLib.FileUtils.get_contents (children_path, out children_content)) {
                    // If there are child process IDs listed, processes are running
                    string trimmed = children_content.strip ();
                    if (trimmed.length > 0) {
                        return true;
                    }
                }
            } catch (Error e) {
                // If /proc method fails, silently fall through to fallback
            }

            // Fallback: check process status
            try {
                string stat_path = "/proc/%d/stat".printf ((int)this.shell_pid);
                string stat_content;
                if (GLib.FileUtils.get_contents (stat_path, out stat_content)) {
                    string[] parts = stat_content.split (" ");
                    if (parts.length > 7) {
                        // Check if there are child processes (field 17 in /proc/pid/stat)
                        int num_threads = int.parse (parts[19]);
                        // If shell has more than 1 thread, might have children
                        return num_threads > 1;
                    }
                }
            } catch (Error e) {
                // Silent fallback failure
            }

            return false;
        }

        private void ensure_close_prompt_controller () {
            if (this.close_prompt_controller != null) {
                return;
            }
            this.close_prompt_controller = new Gtk.EventControllerKey ();
            this.add_controller (this.close_prompt_controller);
            this.close_prompt_controller.key_pressed.connect ((keyval, keycode, state) => {
                if (!this.waiting_for_close_key) {
                    return false;
                }
                this.waiting_for_close_key = false;
                this.press_any_key_close_requested ();
                return true;
            });
        }

        private string describe_exit_status (int status) {
            if (status == 0) {
                return "Process exited normally.";
            }
            return "Process exited with status %d.".printf (status);
        }

        private void show_press_any_key_prompt (string? message) {
            ensure_close_prompt_controller ();
            if (this.waiting_for_close_key) {
                return;
            }
            this.waiting_for_close_key = true;
            this.set_can_focus (true);
            this.grab_focus ();

            string prompt = "\r\n";
            if (message != null && message.strip () != "") {
                prompt += message.strip ();
                prompt += "\r\n";
            }
            prompt += "Press any key to close this tab...";
            prompt += "\r\n";
            this.feed (prompt.data);
        }
    }
}

