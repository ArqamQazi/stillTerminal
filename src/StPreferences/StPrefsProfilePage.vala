namespace StillTerminal {
    public class StPrefsProfilePage : Adw.PreferencesPage {
        public StPrefsDialog dialog;
        private Adw.PreferencesGroup system_group;
        private Adw.PreferencesGroup containers_group;
        private Adw.PreferencesGroup ssh_group;
        private Adw.PreferencesGroup creation_group;
        Adw.ActionRow[] system_rows = {};
        Adw.ActionRow[] container_rows = {};
        Adw.ActionRow[] ssh_rows = {};

        public StPrefsProfilePage (StPrefsDialog dialog) {
            this.dialog = dialog;
            this.set_title ("Profiles");
            this.set_icon_name ("utilities-terminal-symbolic");

            this.setup_profile_groups();
            this.regenerate_profile_list ();
        }
        
        private void setup_profile_groups() {
            // System profiles group
            this.system_group = new Adw.PreferencesGroup ();
            this.system_group.set_title ("System Profiles");
            this.system_group.set_description ("Terminals accessing your local system");
            this.add (system_group);

            // Container profiles group
            this.containers_group = new Adw.PreferencesGroup ();
            this.containers_group.set_title ("Container Profiles");
            this.containers_group.set_description ("Terminals accessing containerized environments");
            this.add (containers_group);

            // SSH profiles group
            this.ssh_group = new Adw.PreferencesGroup ();
            this.ssh_group.set_title ("Remote SSH Profiles");
            this.ssh_group.set_description ("Terminals accessing remote servers");
            this.add (ssh_group);
        }
        
        private void create_profile_of_type(StProfileType type) {
            var blank_profile = StProfile.new_blank_profile();
            blank_profile.type = type;
            
            // Set appropriate default values based on type
            switch (type) {
                case StProfileType.SYSTEM:
                    blank_profile.type_subtitle = "";
                    break;
                case StProfileType.DISTROBOX:
                    blank_profile.type_subtitle = "Container Environment";
                    break;
                case StProfileType.SSH:
                    blank_profile.type_subtitle = "Remote Connection";
                    break;
            }
            
            this.push_profile_editor(blank_profile);
        }
        
        private void push_profile_editor(StProfile profile) {
            var editor_page = new StProfileEditorPage(this.dialog, profile);
            var create_button = new Gtk.Button.with_label("Create");
            create_button.clicked.connect(() => {
                this.create_profile_button(editor_page);
            });
            editor_page.set_button(create_button);
            this.dialog.preferences_dialog.push_subpage(editor_page);
        }

        private string normalize_container_name(string? raw_name) {
            if (raw_name == null) {
                return "";
            }
            string name = raw_name.strip();
            if (name == "") {
                return "";
            }

            name = name.replace(" ", "_");

            string? style_env = GLib.Environment.get_variable("ST_DISTROBOX_NAME_STYLE");
            string style = (style_env != null && style_env.strip() != "") ? style_env.strip().ascii_down() : "underscores";

            switch (style) {
                case "underscores":
                    name = name.replace("-", "_");
                    break;
                case "dashes":
                    name = name.replace("_", "-");
                    break;
                default:
                    break;
            }

            return name;
        }

        private string build_container_name_from_profile(StProfile profile) {
            string profile_id_slug = profile.id.replace(" ", "_");
            string base_name = "stillterminal-" + profile_id_slug;
            return this.normalize_container_name(base_name);
        }

        private string get_distrobox_container_name(StProfile profile) {
            if (profile.type_params != null && profile.type_params.has_key("name")) {
                string? custom_name = profile.type_params["name"];
                string normalized_custom = this.normalize_container_name(custom_name);
                if (normalized_custom != "") {
                    return normalized_custom;
                }
            }
            if (profile.type_params != null && profile.type_params.has_key("fallback_name")) {
                string normalized_fallback = this.normalize_container_name(profile.type_params["fallback_name"]);
                if (normalized_fallback != "") {
                    return normalized_fallback;
                }
            }
            return this.build_container_name_from_profile(profile);
        }

        private bool run_command(string[] argv) {
            string? helper = GLib.Environment.get_variable("STILLTERMINAL_HOSTHELPER");
            string[] full_argv;
            if (helper != null && helper.strip() != "") {
                full_argv = new string[argv.length + 1];
                full_argv[0] = helper;
                for (int i = 0; i < argv.length; i++) full_argv[i + 1] = argv[i];
            } else {
                full_argv = argv;
            }

            int status = 0;
            string? stdout = null;
            string? stderr = null;
            try {
                GLib.Process.spawn_sync(null, full_argv, null, GLib.SpawnFlags.SEARCH_PATH, null, out stdout, out stderr, out status);
            } catch (GLib.SpawnError e) {
                print("Failed to spawn command: %s\n", e.message);
                return false;
            }
            if (status != 0) {
                if (stderr != null && stderr.strip() != "") {
                    print("Command failed: %s\n", stderr.strip());
                }
                return false;
            }
            return true;
        }

        private void stop_and_remove_distrobox_container(string container_name) {
            if (container_name == null) {
                return;
            }
            string name = this.normalize_container_name(container_name);
            if (name == "") {
                return;
            }

            bool stopped = this.run_command(new string[] {"distrobox", "stop", "--yes", name});
            if (!stopped) {
                print("Failed to stop distrobox container %s\n", name);
            }
            bool removed = this.run_command(new string[] {"distrobox", "rm", "-f", "--yes", name});
            if (!removed) {
                print("Failed to remove distrobox container %s\n", name);
            }
        }
        
        private void create_profile_button(StProfileEditorPage editor_page) {
            var profile = editor_page.get_edited_profile();
            profile.save_to_json(get_local_profile_dir() + "/" + profile.id + ".json");
            this.regenerate_profile_list();
            // Pop the editor page, then the type selector beneath it
            this.dialog.preferences_dialog.pop_subpage();
            this.dialog.preferences_dialog.pop_subpage();
        }

        private void save_profile_with_backup (StProfile profile) {
            File original_file = File.new_for_path(profile.profile_file);
            File backup_file = File.new_for_path(profile.profile_file + ".bak");
            
            try {
                // Create a backup
                if (original_file.query_exists()) {
                    original_file.copy(backup_file, FileCopyFlags.OVERWRITE);
                }
                
                // Save the new profile data
                profile.save_to_json(profile.profile_file);
                
                // If everything went well, delete the backup
                if (backup_file.query_exists()) {
                    backup_file.delete();
                }
                
                // Saved successfully
            } catch (Error e) {
                print("Error saving profile: %s\n", e.message);
                
                try {
                    // If there was an error, attempt to restore from backup
                    if (backup_file.query_exists()) {
                        original_file.delete(); // Delete the potentially corrupted file
                        backup_file.move(original_file, FileCopyFlags.OVERWRITE);
                    // Restored from backup
                    }
                } catch (Error restore_error) {
                    print("Error restoring from backup: %s\n", restore_error.message);
                }
            }
        }
        
        public void open_profile_editor(StProfile profile) {
            var profile_editor = new StProfileEditorPage (this.dialog, profile);
            
            var save_button = new Gtk.Button.with_label ("Save");
            save_button.clicked.connect(() => {
                var edited = profile_editor.get_edited_profile ();
                bool should_delete = false;
                // Detect create-time changes for distrobox profiles
                if (profile.type == StProfileType.DISTROBOX) {
                    // Compare current vs edited create-time subset
                    Gee.HashMap<string,string> before = new Gee.HashMap<string,string>();
                    if (profile.type_params != null) {
                        foreach (var entry in profile.type_params.entries) before[entry.key] = entry.value;
                    }
                    Gee.HashMap<string,string> after = new Gee.HashMap<string,string>();
                    if (edited.type_params != null) {
                        foreach (var entry in edited.type_params.entries) after[entry.key] = entry.value;
                    }
                    string[] keys = {"image","additional_packages","additional_flags","volumes","init","root","pull","home","hostname","platform","pre_init_hooks","init_hooks"};
                    foreach (string k in keys) {
                        string bv = before.has_key(k) ? (before[k] ?? "") : "";
                        string av = after.has_key(k) ? (after[k] ?? "") : "";
                        if (bv != av) { should_delete = true; break; }
                    }
                }

                this.save_profile_with_backup(edited);

                if (edited.type == StProfileType.DISTROBOX && should_delete) {
                    this.stop_and_remove_distrobox_container(this.get_distrobox_container_name(profile));
                }

                regenerate_profile_list ();
                this.dialog.preferences_dialog.pop_subpage ();
            });
            profile_editor.set_button (save_button);
            
            if (profile.id != "default") {
                // Group destructive actions on the left of the header and style as destructive
                var destructive_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);

                var remove_button = new Gtk.Button.with_label ("Remove Profile");
                remove_button.add_css_class ("destructive-action");
                remove_button.clicked.connect (() => {
                    if (profile.type == StProfileType.DISTROBOX) {
                        this.stop_and_remove_distrobox_container(this.get_distrobox_container_name(profile));
                    }

                    if (profile.profile_file != null && profile.profile_file.strip() != "") {
                        var file = File.new_for_path(profile.profile_file);
                        try {
                            file.delete();
                        } catch (Error e) {
                            print ("Error deleting profile: %s\n".printf (e.message));
                        }
                    }

                    // Clear stored SSH password if any
                    StSecretManager.clear_password(profile.id);

                    regenerate_profile_list ();
                    this.dialog.preferences_dialog.pop_subpage ();
                });
                destructive_box.append(remove_button);
                profile_editor.header.pack_start (destructive_box);
            }

            this.dialog.preferences_dialog.push_subpage (profile_editor);
        }

        
        public void regenerate_profile_list () {
            // Clear only existing profile rows (not the "Create New Profile" action rows)
            foreach (var row in this.system_rows) {
                this.system_group.remove (row);
            }
            foreach (var row in this.container_rows) {
                this.containers_group.remove (row);
            }
            foreach (var row in this.ssh_rows) {
                this.ssh_group.remove (row);
            }
            
            this.system_rows = {};
            this.container_rows = {};
            this.ssh_rows = {};

            var profile_index = get_profiles ();
            
            foreach (StProfile profile in profile_index) {
                var row = new Adw.ActionRow ();
                row.set_title (profile.name);

                // Create icon widget with proper emoji and resource support
                var icon_widget = this.create_profile_icon(profile);
                row.add_prefix (icon_widget);

                if (profile.type_subtitle != null && profile.type_subtitle != "") {
                    row.set_subtitle (profile.type_subtitle);
                }

                var arrow_icon = new Gtk.Image.from_icon_name ("go-next-symbolic");
                arrow_icon.add_css_class ("dim-label");
                row.add_suffix (arrow_icon);
                
                row.set_activatable(true);
                row.activated.connect (() => {
                    this.open_profile_editor (profile);
                });
                
                // Add to appropriate group based on profile type
                switch (profile.type) {
                    case StProfileType.SYSTEM:
                        this.system_group.add (row);
                        this.system_rows += row;
                        break;
                    case StProfileType.DISTROBOX:
                        this.containers_group.add (row);
                        this.container_rows += row;
                        break;
                    case StProfileType.SSH:
                        this.ssh_group.add (row);
                        this.ssh_rows += row;
                        break;
                }
            }
            
            // Add a single nameless group with one "Add Container Profile" option
            this.add_single_container_add_row();
            
            // Always show groups so users can access "New Profile" action rows
            this.system_group.visible = true;
            this.containers_group.visible = true;
            this.ssh_group.visible = true;
        }
        
        private void add_single_container_add_row() {
            if (this.creation_group != null) {
                this.remove(this.creation_group);
                this.creation_group = null;
            }
            this.creation_group = new Adw.PreferencesGroup();
            // Intentionally no title/description for a nameless group

            var container_new_row = new Adw.ActionRow();
            container_new_row.set_title("Add Profile");
            container_new_row.set_subtitle("Create a new terminal profile");

            var container_icon = new Gtk.Image.from_icon_name("list-add-symbolic");
            container_icon.pixel_size = 24;
            container_new_row.add_prefix(container_icon);

            var container_arrow = new Gtk.Image.from_icon_name("go-next-symbolic");
            container_arrow.add_css_class("dim-label");
            container_new_row.add_suffix(container_arrow);

            container_new_row.set_activatable(true);
            container_new_row.activated.connect(() => {
                this.open_type_selector();
            });

            this.creation_group.add(container_new_row);
            this.add(this.creation_group);
        }

        private void open_type_selector() {
            var selector = new StProfileTypeSelectorSubpage(this.dialog);
            selector.type_selected.connect((t) => {
                // Push editor on top of selector so Back returns to selector
                this.create_profile_of_type(t);
            });
            this.dialog.preferences_dialog.push_subpage(selector);
        }
        
        private Gtk.Widget create_profile_icon(StProfile profile) {
            // Check if the icon is an emoji
            if (profile.icon_name != null && profile.icon_name != "" && this.is_emoji(profile.icon_name)) {
                var emoji_label = new Gtk.Label(profile.icon_name);
                emoji_label.add_css_class("large-emoji");
                emoji_label.set_size_request(32, 32);
                return emoji_label;
            }
            
            // Create image widget
            var icon_image = new Gtk.Image();
            icon_image.pixel_size = 32;
            
            // Check if it's a Linux distro icon from resources
            if (profile.icon_name != null && profile.icon_name in AVAILABLE_ICONS) {
                icon_image.set_from_resource(@"/io/stillhq/terminal/icons/$(profile.icon_name).svg");
            } else {
                // Use default terminal icon
                icon_image.set_from_icon_name("utilities-terminal-symbolic");
            }
            
            return icon_image;
        }
        
        private bool is_emoji(string text) {
            // Check for non-ASCII characters that are likely emoji
            uint8[] bytes = text.data;
            for (int i = 0; i < bytes.length; i++) {
                if (bytes[i] > 127) {
                    return true;
                }
            }
            return false;
        }
    }
}