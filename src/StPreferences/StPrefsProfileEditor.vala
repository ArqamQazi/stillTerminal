namespace StillTerminal {
    // Reusable profile editor widget that can be used in different contexts
        public class StProfileEditorWidget : Gtk.Box {
        public StProfile profile { get; private set; }
        string[] available_schemes;
        string selected_color_scheme_id;
        Adw.PreferencesGroup pref_group;
        Adw.EntryRow name_row;
        Adw.ActionRow profile_type;
        Adw.ActionRow color_scheme_row;
        Adw.EntryRow working_directory_row;
        Gtk.FileDialog file_dialog;
        Adw.EntryRow spawn_command_row;
        Adw.ActionRow icon_row;
        Gtk.Label icon_preview_label;
        Gtk.Image icon_preview_image;
        Gtk.Stack icon_preview_stack;
        Adw.PreferencesGroup ssh_auth_group;
        Adw.PreferencesGroup ssh_options_group;
        Adw.PreferencesGroup container_group;
        Adw.ActionRow db_warning_row;
        
        // SSH-specific fields
        Adw.EntryRow ssh_host_row;
        Adw.EntryRow ssh_user_row;
        Adw.SpinRow ssh_port_row;
        Adw.ActionRow ssh_private_key_row;
        Adw.PasswordEntryRow ssh_password_row;
        Adw.EntryRow ssh_extra_options_row;
        Adw.ActionRow ssh_command_preview_row;
        Gtk.FileDialog ssh_key_dialog;
        
        public signal void profile_changed();
        public signal void validation_changed(bool is_valid);
        
        private bool _is_valid = false;
        public bool is_valid { 
            get { return _is_valid; }
            private set { 
                if (_is_valid != value) {
                    _is_valid = value;
                    validation_changed(value);
                }
            }
        }

        public StProfileEditorWidget (StProfile profile) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            
            this.profile = profile;
            this.available_schemes = get_available_schemes ().keys.to_array ();
            this.available_schemes += "system";
            this.available_schemes.move (this.available_schemes.length - 1, 0, 1);
            var preferences_page = new Adw.PreferencesPage ();
            this.pref_group = new Adw.PreferencesGroup ();
            this.pref_group.set_title ("General");
            preferences_page.add (this.pref_group);

            this.ssh_auth_group = new Adw.PreferencesGroup ();
            this.ssh_auth_group.set_title ("SSH Authentication");
            preferences_page.add (this.ssh_auth_group);

            this.ssh_options_group = new Adw.PreferencesGroup ();
            this.ssh_options_group.set_title ("SSH Options");
            preferences_page.add (this.ssh_options_group);

            this.append (preferences_page);

            this.setup_ui_components();
            this.setup_validation();
            this.load_profile_data();
        }
        
        private void setup_ui_components() {
            // Profile name entry
            this.name_row = new Adw.EntryRow ();
            this.name_row.set_title ("Profile Name (Required)");
            this.name_row.set_input_purpose (Gtk.InputPurpose.NAME);
            this.name_row.changed.connect (this.on_field_changed);
            this.pref_group.add (this.name_row);

            // Profile type (read-only display)
            this.profile_type = new Adw.ActionRow ();
            this.profile_type.set_title ("Profile Type");
            this.profile_type.set_sensitive (false);
            this.pref_group.add (this.profile_type);
            
            // Color scheme picker (button opens theme gallery)
            this.color_scheme_row = new Adw.ActionRow ();
            this.color_scheme_row.set_title ("Color Scheme");
            var open_scheme_button = new Gtk.Button.with_label ("Choose…");
            open_scheme_button.add_css_class ("flat");
            open_scheme_button.valign = Gtk.Align.CENTER;
            open_scheme_button.clicked.connect (() => {
                var picker = new StThemePickerPage ("Choose Theme", true, this.selected_color_scheme_id);
                picker.scheme_selected.connect ((id) => {
                    this.selected_color_scheme_id = id;
                    this.profile.color_scheme = id;
                    this.update_color_scheme_row_subtitle();
                    this.update_color_scheme_row_sensitivity();
                    this.on_field_changed();
                    var dlg = this.get_ancestor(typeof(Adw.PreferencesDialog)) as Adw.PreferencesDialog;
                    if (dlg != null) dlg.pop_subpage ();
                });
                var dlg = this.get_ancestor(typeof(Adw.PreferencesDialog)) as Adw.PreferencesDialog;
                if (dlg != null) dlg.push_subpage (picker);
            });
            this.color_scheme_row.add_suffix (open_scheme_button);
            this.color_scheme_row.set_activatable_widget (open_scheme_button);
            this.pref_group.add (this.color_scheme_row);

            // Working directory with folder picker
            this.working_directory_row = new Adw.EntryRow ();
            this.working_directory_row.set_title ("Starting Directory");
            this.working_directory_row.changed.connect (this.on_field_changed);
            var working_directory_button = new Gtk.Button.from_icon_name("folder-open-symbolic");
            working_directory_button.add_css_class("flat");
            working_directory_button.clicked.connect (this.on_directory_picker_clicked);
            working_directory_button.valign = Gtk.Align.CENTER;
            this.working_directory_row.add_suffix(working_directory_button);
            this.file_dialog = new Gtk.FileDialog();
            this.pref_group.add (this.working_directory_row);

            // Spawn command entry
            this.spawn_command_row = new Adw.EntryRow ();
            this.spawn_command_row.set_title ("Profile Starting Command");
            this.spawn_command_row.changed.connect (() => { this.on_field_changed(); this.update_ssh_command_preview(); });
            this.pref_group.add (this.spawn_command_row);

            // SSH-specific fields (only shown for SSH profiles)
            this.setup_ssh_fields();

            // Container-specific fields (only shown for Distrobox profiles)
            this.setup_container_fields();

            // Icon picker with preview and buttons
            this.setup_icon_picker();
        }
        
        private void update_color_scheme_row_subtitle() {
            if (this.selected_color_scheme_id == null || this.selected_color_scheme_id == "system") {
                this.color_scheme_row.set_subtitle ("System");
                return;
            }
            var scheme = StColorScheme.new_from_id (this.selected_color_scheme_id);
            if (scheme != null && scheme.name != null && scheme.name != "") {
                this.color_scheme_row.set_subtitle (scheme.name);
            } else {
                this.color_scheme_row.set_subtitle (this.selected_color_scheme_id);
            }
        }
        
        private void setup_ssh_fields() {
            // SSH Host entry
            this.ssh_host_row = new Adw.EntryRow ();
            this.ssh_host_row.set_title ("SSH Host (Required)");
            this.ssh_host_row.set_input_purpose (Gtk.InputPurpose.URL);
            this.ssh_host_row.changed.connect (() => { this.on_field_changed(); this.update_ssh_command_preview(); });
            this.ssh_options_group.add (this.ssh_host_row);

            // SSH User entry
            this.ssh_user_row = new Adw.EntryRow ();
            this.ssh_user_row.set_title ("SSH Username");
            this.ssh_user_row.set_input_purpose (Gtk.InputPurpose.NAME);
            this.ssh_user_row.changed.connect (() => { this.on_field_changed(); this.update_ssh_command_preview(); });
            this.ssh_options_group.add (this.ssh_user_row);

            // SSH Port spinner
            var port_adjustment = new Gtk.Adjustment(22, 1, 65535, 1, 10, 0);
            this.ssh_port_row = new Adw.SpinRow (port_adjustment, 0, 0);
            this.ssh_port_row.set_title ("SSH Port");
            this.ssh_port_row.set_numeric(true);
            this.ssh_port_row.set_digits(0);
            this.ssh_port_row.set_value (22);
            this.ssh_port_row.changed.connect (() => { this.on_field_changed(); this.update_ssh_command_preview(); });
            this.ssh_options_group.add (this.ssh_port_row);

            // SSH Private Key file picker
            this.ssh_private_key_row = new Adw.ActionRow ();
            this.ssh_private_key_row.set_title ("SSH Private Key");
            this.ssh_private_key_row.set_subtitle ("Select a private key file (optional)");
            
            var key_button = new Gtk.Button.with_label ("Choose Key File");
            key_button.add_css_class ("flat");
            key_button.valign = Gtk.Align.CENTER;
            key_button.clicked.connect (this.on_ssh_key_picker_clicked);
            this.ssh_private_key_row.add_suffix (key_button);

            var clear_key_button = new Gtk.Button.from_icon_name("edit-clear-symbolic");
            clear_key_button.add_css_class("flat");
            clear_key_button.set_valign(Gtk.Align.CENTER);
            clear_key_button.set_tooltip_text("Clear and use default identity");
            clear_key_button.clicked.connect(() => {
                this.profile.ssh_private_key_path = null;
                this.ssh_private_key_row.set_subtitle("");
                this.on_field_changed();
                this.update_ssh_command_preview();
            });
            this.ssh_private_key_row.add_suffix(clear_key_button);
            
            this.ssh_key_dialog = new Gtk.FileDialog ();
            this.ssh_key_dialog.set_title ("Select SSH Private Key");
            this.ssh_key_dialog.set_modal (true);
            
            // Set up file filters for key files
            var filter = new Gtk.FileFilter ();
            filter.name = "SSH Private Keys";
            filter.add_pattern ("*.pem");
            filter.add_pattern ("*.key");
            filter.add_pattern ("id_rsa");
            filter.add_pattern ("id_ed25519");
            filter.add_pattern ("id_ecdsa");
            
            var all_files_filter = new Gtk.FileFilter ();
            all_files_filter.name = "All Files";
            all_files_filter.add_pattern ("*");
            
            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (filter);
            filters.append (all_files_filter);
            this.ssh_key_dialog.set_filters (filters);
            this.ssh_key_dialog.set_default_filter (filter);
            
            this.ssh_auth_group.add (this.ssh_private_key_row);

            // Password row (stored securely in keyring)
            this.ssh_password_row = new Adw.PasswordEntryRow();
            this.ssh_password_row.set_title("Password (Stored Securely in GNOME Keyring)");
            this.ssh_password_row.changed.connect(() => { this.on_field_changed(); this.update_ssh_command_preview(); });
            var pw_button = new Gtk.Button.with_label("Save to Keyring");
            pw_button.add_css_class("flat");
            pw_button.valign = Gtk.Align.CENTER;
            pw_button.clicked.connect(() => {
                if (this.profile.id.strip() == "") return;
                string pw = this.ssh_password_row.get_text();
                if (pw.strip() != "") {
                    StSecretManager.store_password(this.profile.id, pw);
                }
            });
            this.ssh_password_row.add_suffix(pw_button);
            this.ssh_auth_group.add(this.ssh_password_row);

            // Extra options input
            this.ssh_extra_options_row = new Adw.EntryRow();
            this.ssh_extra_options_row.set_title("Extra SSH Options (Advanced)");
            this.ssh_extra_options_row.set_text(this.profile.ssh_extra_options ?? "");
            this.ssh_extra_options_row.changed.connect(() => { this.on_field_changed(); this.update_ssh_command_preview(); });
            this.ssh_options_group.add(this.ssh_extra_options_row);

            // Read-only spawn command preview
            this.ssh_command_preview_row = new Adw.ActionRow();
            this.ssh_command_preview_row.set_title("SSH Command Preview");
            this.ssh_command_preview_row.set_subtitle("");
            this.ssh_options_group.add(this.ssh_command_preview_row);
            
            // Initially hide SSH fields (they'll be shown only for SSH profiles)
            this.update_ssh_fields_visibility();
            this.update_ssh_command_preview();
        }

        // Distrobox fields
        Adw.ComboRow db_image_combo;
        Adw.EntryRow db_custom_image_row;
        Adw.ExpanderRow db_advanced_expander;
        Adw.EntryRow db_additional_packages_row;
        Adw.EntryRow db_additional_flags_row;
        Adw.EntryRow db_volumes_row;
        Adw.SwitchRow db_init_switch;
        Adw.SwitchRow db_root_switch;
        Adw.SwitchRow db_pull_switch;
        Adw.EntryRow db_home_row;
        Adw.EntryRow db_hostname_row;
        Adw.EntryRow db_platform_row;
        Adw.EntryRow db_pre_init_hooks_row;
        Adw.EntryRow db_init_hooks_row;
        Adw.SwitchRow db_match_theme_switch;

        private void setup_container_fields() {
            this.container_group = new Adw.PreferencesGroup ();
            this.container_group.set_title ("Container Options");
            this.container_group.set_visible(false);
            var first = this.get_first_child();
            var page = first as Adw.PreferencesPage;
            if (page != null) {
                page.add(this.container_group);
            }

            // Match container theme toggle (per-profile) — placed at top
            this.db_match_theme_switch = new Adw.SwitchRow();
            this.db_match_theme_switch.set_title("Use Container Image Color");
            this.db_match_theme_switch.set_active(true); // default ON
            this.db_match_theme_switch.notify["active"].connect(() => {
                // When enabling, force scheme to System if not already
                if (this.db_match_theme_switch.get_active() && (this.selected_color_scheme_id == null || this.selected_color_scheme_id != "system")) {
                    this.selected_color_scheme_id = "system";
                    this.profile.color_scheme = "system";
                    this.update_color_scheme_row_subtitle();
                }
                this.on_field_changed();
                this.update_color_scheme_row_sensitivity();
            });
			this.container_group.add(this.db_match_theme_switch);

			// Warning banner/row
            this.db_warning_row = new Adw.ActionRow();
            this.db_warning_row.set_title("Changing Distrobox options will recreate the container on next launch.");
			this.db_warning_row.add_css_class("warning");
			this.db_warning_row.set_activatable(false);
			this.container_group.add(this.db_warning_row);

            // Image selector (common images + Custom)
            this.db_image_combo = new Adw.ComboRow();
            this.db_image_combo.set_title("Image");
            string[] image_labels = { "Ubuntu (latest)", "Debian (stable)", "Fedora (latest)", "Arch Linux (latest)", "openSUSE Tumbleweed", "Alpine (latest)", "Custom…" };
            this.db_image_combo.set_model(new Gtk.StringList(image_labels));
            this.db_image_combo.notify["selected"].connect(() => {
                this.on_field_changed();
                this.db_custom_image_row.set_visible(this.db_image_combo.get_selected() == image_labels.length - 1);
            });
            this.container_group.add(this.db_image_combo);

            // Custom image input (shown only when Custom selected)
            this.db_custom_image_row = new Adw.EntryRow();
            this.db_custom_image_row.set_title("Custom Image Reference");
            // Placeholder not supported on EntryRow in our API version; keep title concise
            this.db_custom_image_row.set_visible(false);
            this.db_custom_image_row.changed.connect(this.on_field_changed);
            this.container_group.add(this.db_custom_image_row);

            // Removed: Extra enter args

            // Advanced options expander (maps to distrobox create)
            this.db_advanced_expander = new Adw.ExpanderRow();
            this.db_advanced_expander.set_title("Advanced Options");
            this.container_group.add(this.db_advanced_expander);

			// (switch already added at top)

            this.db_additional_packages_row = new Adw.EntryRow();
            this.db_additional_packages_row.set_title("Additional Packages");
            // no subtitle API on EntryRow in our build; leave title only
            this.db_additional_packages_row.changed.connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_additional_packages_row);

            this.db_additional_flags_row = new Adw.EntryRow();
            this.db_additional_flags_row.set_title("Additional Flags");
            // no subtitle API on EntryRow
            this.db_additional_flags_row.changed.connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_additional_flags_row);

            this.db_volumes_row = new Adw.EntryRow();
            this.db_volumes_row.set_title("Volumes");
            // no subtitle API on EntryRow
            this.db_volumes_row.changed.connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_volumes_row);

            this.db_init_switch = new Adw.SwitchRow();
            this.db_init_switch.set_title("Use Init Inside Container");
            this.db_init_switch.notify["active"].connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_init_switch);

            this.db_root_switch = new Adw.SwitchRow();
            this.db_root_switch.set_title("Rootful create (use --root)");
            this.db_root_switch.notify["active"].connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_root_switch);

            this.db_pull_switch = new Adw.SwitchRow();
            this.db_pull_switch.set_title("Always Pull Image (–-pull)");
            this.db_pull_switch.notify["active"].connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_pull_switch);

            this.db_home_row = new Adw.EntryRow();
            this.db_home_row.set_title("Custom Home Directory");
            this.db_home_row.changed.connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_home_row);

            this.db_hostname_row = new Adw.EntryRow();
            this.db_hostname_row.set_title("Hostname");
            this.db_hostname_row.changed.connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_hostname_row);

            this.db_platform_row = new Adw.EntryRow();
            this.db_platform_row.set_title("Platform (e.g., linux/arm64)");
            this.db_platform_row.changed.connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_platform_row);

            this.db_pre_init_hooks_row = new Adw.EntryRow();
            this.db_pre_init_hooks_row.set_title("Pre-Init Hooks");
            // no subtitle API on EntryRow
            this.db_pre_init_hooks_row.changed.connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_pre_init_hooks_row);

            this.db_init_hooks_row = new Adw.EntryRow();
            this.db_init_hooks_row.set_title("Init Hooks");
            // no subtitle API on EntryRow
            this.db_init_hooks_row.changed.connect(this.on_field_changed);
            this.db_advanced_expander.add_row(this.db_init_hooks_row);
        }

        private void setup_icon_picker() {
            this.icon_row = new Adw.ActionRow ();
            this.icon_row.set_title ("Profile Icon");
            
            // Create icon preview stack (shows either emoji label or image)
            this.icon_preview_stack = new Gtk.Stack();
            this.icon_preview_label = new Gtk.Label("");
            this.icon_preview_label.add_css_class("large-emoji");
            this.icon_preview_label.set_size_request(32, 32);
            this.icon_preview_image = new Gtk.Image();
            this.icon_preview_image.pixel_size = 32;
            
            this.icon_preview_stack.add_named(this.icon_preview_label, "emoji");
            this.icon_preview_stack.add_named(this.icon_preview_image, "icon");
            this.icon_row.add_prefix(this.icon_preview_stack);
            
            // Button box for icon picker actions
            var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            
            // Linux distro icons button
            var distro_button = new Gtk.Button.with_label("Distro Icons");
            distro_button.add_css_class("flat");
            distro_button.set_valign(Gtk.Align.CENTER);
            distro_button.clicked.connect(this.on_distro_icon_picker_clicked);
            button_box.append(distro_button);
            
            // Emoji picker button 
            var emoji_button = new Gtk.Button.with_label("Emojis");
            emoji_button.add_css_class("flat");
            emoji_button.set_valign(Gtk.Align.CENTER);
            emoji_button.clicked.connect(this.on_emoji_picker_clicked);
            button_box.append(emoji_button);
            
            // Clear icon button
            var clear_button = new Gtk.Button.from_icon_name("edit-clear-symbolic");
            clear_button.add_css_class("flat");
            clear_button.tooltip_text = "Clear Icon";
            clear_button.clicked.connect(() => {
                this.set_icon(null);
            });
            button_box.append(clear_button);
            
            this.icon_row.add_suffix(button_box);
            this.pref_group.add (this.icon_row);
        }
        
        private void setup_validation() {
            // Perform initial validation
            this.validate_fields();
        }
        
        private void load_profile_data() {
            this.name_row.set_text (profile.name);
            this.profile_type.set_subtitle (this.get_profile_type_display_name(this.profile.type));
            
            // Initialize selected scheme and subtitle
            this.selected_color_scheme_id = (this.profile.color_scheme ?? "system");
            this.update_color_scheme_row_subtitle();
            
            this.working_directory_row.set_text(profile.working_directory);
            if (profile.spawn_command != null) {
                this.spawn_command_row.set_text (profile.spawn_command);
            }
            
            // Load SSH-specific fields
            if (profile.ssh_host != null) {
                this.ssh_host_row.set_text(profile.ssh_host);
            }
            if (profile.ssh_user != null) {
                this.ssh_user_row.set_text(profile.ssh_user);
            }
            this.ssh_port_row.set_value(profile.ssh_port);
            if (profile.ssh_private_key_path != null) {
                this.ssh_private_key_row.set_subtitle("Selected: " + File.new_for_path(profile.ssh_private_key_path).get_basename());
            }

            // Extra options
            this.ssh_extra_options_row.set_text(profile.ssh_extra_options ?? "");
            this.update_ssh_command_preview();

            // Load container-specific fields
            if (profile.type == StProfileType.DISTROBOX) {
                string img = "";
                if (profile.type_params != null) {
                    if (profile.type_params.has_key("image")) img = profile.type_params["image"]; 
                }
                if (img == "") img = "docker.io/library/ubuntu:latest";
                if (this.container_group == null) {
                    // ensure container group exists
                    this.setup_container_fields();
                }
                // Map image to known list, otherwise select Custom
                int idx = 0;
                switch (img) {
                    case "docker.io/library/ubuntu:latest": idx = 0; break;
                    case "docker.io/library/debian:stable": idx = 1; break;
                    case "registry.fedoraproject.org/fedora:latest": idx = 2; break;
                    case "docker.io/library/archlinux:latest": idx = 3; break;
                    case "registry.opensuse.org/opensuse/tumbleweed:latest": idx = 4; break;
                    case "docker.io/library/alpine:latest": idx = 5; break;
                    default: idx = 6; break; // Custom
                }
                this.db_image_combo.set_selected(idx);
                this.db_custom_image_row.set_visible(idx == 6);
                if (idx == 6) this.db_custom_image_row.set_text(img);
                this.update_container_fields_visibility();

                // Initialize match theme toggle from type_params
                bool match = true; // default ON when absent
                if (profile.type_params != null && profile.type_params.has_key("match_container_theme")) {
                    match = (profile.type_params["match_container_theme"] == "true");
                }
                this.db_match_theme_switch.set_active(match);
                this.update_color_scheme_row_sensitivity();

                // Load advanced options
                this.db_additional_packages_row.set_text(this.get_type_param_or_empty(profile, "additional_packages"));
                this.db_additional_flags_row.set_text(this.get_type_param_or_empty(profile, "additional_flags"));
                this.db_volumes_row.set_text(this.get_type_param_or_empty(profile, "volumes"));
                this.db_init_switch.set_active(this.get_type_param_bool(profile, "init"));
                this.db_root_switch.set_active(this.get_type_param_bool(profile, "root"));
                this.db_pull_switch.set_active(this.get_type_param_bool(profile, "pull"));
                this.db_home_row.set_text(this.get_type_param_or_empty(profile, "home"));
                this.db_hostname_row.set_text(this.get_type_param_or_empty(profile, "hostname"));
                this.db_platform_row.set_text(this.get_type_param_or_empty(profile, "platform"));
                this.db_pre_init_hooks_row.set_text(this.get_type_param_or_empty(profile, "pre_init_hooks"));
                this.db_init_hooks_row.set_text(this.get_type_param_or_empty(profile, "init_hooks"));
            }

            this.set_icon(profile.icon_name);
            this.update_ssh_fields_visibility();
        }
        
        private string get_profile_type_display_name(StProfileType type) {
            switch (type) {
                case StProfileType.SYSTEM:
                    return "System Profile";
                case StProfileType.DISTROBOX:
                    return "Container Profile";
                case StProfileType.SSH:
                    return "Remote SSH Profile";
                default:
                    return "Unknown Profile Type";
            }
        }
        
        private void set_icon(string? icon_name) {
            this.profile.icon_name = icon_name;
            this.update_icon_preview();
            this.profile_changed();
        }
        
        private void update_icon_preview() {
            if (this.profile.icon_name == null || this.profile.icon_name == "") {
                // No icon set - show placeholder
                this.icon_preview_image.set_from_icon_name("image-missing-symbolic");
                this.icon_preview_stack.set_visible_child_name("icon");
                return;
            }
            
            // Check if it's an emoji
            if (this.is_emoji(this.profile.icon_name)) {
                this.icon_preview_label.set_text(this.profile.icon_name);
                this.icon_preview_stack.set_visible_child_name("emoji");
            } else if (this.profile.icon_name in AVAILABLE_ICONS) {
                // It's a Linux distro icon
                this.icon_preview_image.set_from_resource(@"/io/stillhq/terminal/icons/$(this.profile.icon_name).svg");
                this.icon_preview_stack.set_visible_child_name("icon");
            } else {
                // No valid icon - show placeholder
                this.icon_preview_image.set_from_icon_name("image-missing-symbolic");
                this.icon_preview_stack.set_visible_child_name("icon");
            }
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

        public StProfile get_edited_profile () {
            string selected_color_scheme = (this.selected_color_scheme_id ?? "system").ascii_down();
            
            // Get SSH fields
            string? ssh_host = this.ssh_host_row.get_text().strip() != "" ? this.ssh_host_row.get_text().strip() : null;
            string? ssh_user = this.ssh_user_row.get_text().strip() != "" ? this.ssh_user_row.get_text().strip() : null;
            int ssh_port = (int)this.ssh_port_row.get_value();
            string? ssh_private_key_path = this.profile.ssh_private_key_path;
            var edited_profile = new StProfile (
                this.name_row.get_text ().strip().ascii_down().replace (" ", "_"),
                this.name_row.get_text ().strip(),
                selected_color_scheme,
                this.working_directory_row.get_text(),
                this.spawn_command_row.get_text() != "" ? this.spawn_command_row.get_text() : null,
                this.profile.profile_file,
                this.profile.icon_name,  // This should be the current icon from editor
                this.profile.type,
                this.collect_type_params(),
                this.profile.type_subtitle,
                ssh_host, ssh_user, ssh_port, ssh_private_key_path,
                this.profile.ssh_auth_method, this.profile.ssh_strict_host_key_checking, this.ssh_extra_options_row.get_text()
            );
            
            // Persist password to keyring if provided
            if (edited_profile.type == StProfileType.SSH) {
                var pw = this.ssh_password_row.get_text();
                if (pw != null && pw.strip() != "" && edited_profile.id.strip() != "") {
                    StSecretManager.store_password(edited_profile.id, pw);
                }
            }

            return edited_profile;
        }

        private string get_type_param_or_empty(StProfile profile, string key) {
            if (profile.type_params != null && profile.type_params.has_key(key)) {
                string? value = profile.type_params[key];
                if (value != null) {
                    return value;
                }
            }
            return "";
        }

        private bool get_type_param_bool(StProfile profile, string key) {
            if (profile.type_params != null && profile.type_params.has_key(key)) {
                string? value = profile.type_params[key];
                if (value != null) {
                    return value.ascii_down() == "true";
                }
            }
            return false;
        }

        // Compare only the keys that affect distrobox create
        private Gee.HashMap<string,string> filter_create_params(Gee.HashMap<string,string>? input) {
            var out = new Gee.HashMap<string,string>();
            if (input == null) return out;
            string[] keys = {"image","additional_packages","additional_flags","volumes","init","root","pull","home","hostname","platform","pre_init_hooks","init_hooks"};
            foreach (string k in keys) {
                if (input.has_key(k) && input[k] != null) out[k] = input[k];
            }
            return out;
        }

        public bool distrobox_create_options_changed(StProfile edited) {
            if (edited.type != StProfileType.DISTROBOX) return false;
            var before = this.filter_create_params(this.profile.type_params);
            var after = this.filter_create_params(edited.type_params);
            if (before.size != after.size) return true;
            foreach (var e in before.entries) {
                if (!after.has_key(e.key)) return true;
                if ((after[e.key] ?? "") != (e.value ?? "")) return true;
            }
            return false;
        }

        public string get_container_name_for(StProfile p) {
            if (p.type_params != null && p.type_params.has_key("name") && p.type_params["name"].strip() != "") return p.type_params["name"].strip();
            return "stillterminal-" + p.id;
        }

        private Gee.HashMap<string,string>? collect_type_params() {
            if (this.profile.type != StProfileType.DISTROBOX) {
                return this.profile.type_params; // unchanged for other types
            }
            if (this.container_group == null) return this.profile.type_params;
            var p = new Gee.HashMap<string,string>();
            Gee.HashMap<string,string>? existing_params = this.profile.type_params;
            if (existing_params != null) {
                foreach (var entry in existing_params.entries) {
                    if (entry.value != null) {
                        p[entry.key] = entry.value;
                    }
                }
            }
            string[] managed_keys = {"image","additional_packages","additional_flags","volumes","init","root","pull","home","hostname","platform","pre_init_hooks","init_hooks","match_container_theme"};
            foreach (string key in managed_keys) {
                if (p.has_key(key)) {
                    p.remove(key);
                }
            }
            // Resolve selected image
            int sel = (int) this.db_image_combo.get_selected();
            string img = "";
            switch (sel) {
                case 0: img = "docker.io/library/ubuntu:latest"; break;
                case 1: img = "docker.io/library/debian:stable"; break;
                case 2: img = "registry.fedoraproject.org/fedora:latest"; break;
                case 3: img = "docker.io/library/archlinux:latest"; break;
                case 4: img = "registry.opensuse.org/opensuse/tumbleweed:latest"; break;
                case 5: img = "docker.io/library/alpine:latest"; break;
                default:
                    img = this.db_custom_image_row.get_text().strip();
                    if (img == "") img = "docker.io/library/ubuntu:latest";
                    break;
            }
            p["image"] = img;
            // Removed: enter_args
            // Advanced options persisted for create
            string add_pkgs = this.db_additional_packages_row.get_text().strip();
            if (add_pkgs != "") p["additional_packages"] = add_pkgs;
            string add_flags = this.db_additional_flags_row.get_text().strip();
            if (add_flags != "") p["additional_flags"] = add_flags;
            string vols = this.db_volumes_row.get_text().strip();
            if (vols != "") p["volumes"] = vols; // newline or space separated, we'll split later
            if (this.db_init_switch.get_active()) p["init"] = "true";
            if (this.db_root_switch.get_active()) p["root"] = "true";
            if (this.db_pull_switch.get_active()) p["pull"] = "true";
            string home = this.db_home_row.get_text().strip(); if (home != "") p["home"] = home;
            string hostname = this.db_hostname_row.get_text().strip(); if (hostname != "") p["hostname"] = hostname;
            string platform = this.db_platform_row.get_text().strip(); if (platform != "") p["platform"] = platform;
            string pre_hooks = this.db_pre_init_hooks_row.get_text().strip(); if (pre_hooks != "") p["pre_init_hooks"] = pre_hooks;
            string init_hooks = this.db_init_hooks_row.get_text().strip(); if (init_hooks != "") p["init_hooks"] = init_hooks;

            // Explicitly store the container name that will be used
            // This ensures deletion uses the exact same name that was used for creation
            string? explicit_name = null;
            if (existing_params != null && existing_params.has_key("name")) {
                explicit_name = existing_params["name"];
            }
            if (explicit_name != null && explicit_name.strip() != "") {
                // Keep explicit custom name if it was set
                explicit_name = explicit_name.strip().replace(" ", "_");
                p["name"] = explicit_name;
            } else {
                // Store the default computed name explicitly so deletion can find it
                p["name"] = "stillterminal-" + this.profile.id.replace(" ", "_");
            }

            // Also persist fallback for compatibility
            p["fallback_name"] = "stillterminal-" + this.profile.id.replace(" ", "_");

            // Persist match container theme toggle
            // Persist match container theme toggle (explicitly store true/false)
            p["match_container_theme"] = this.db_match_theme_switch.get_active() ? "true" : "false";
            return p;
        }

        private void update_color_scheme_row_sensitivity() {
            bool disable = this.profile.type == StProfileType.DISTROBOX && this.db_match_theme_switch != null && this.db_match_theme_switch.get_active() && (this.selected_color_scheme_id == null || this.selected_color_scheme_id == "system");
            if (this.color_scheme_row != null) this.color_scheme_row.set_sensitive(!disable);
        }

        // Dropdown changed handler removed; dropdown replaced by theme picker

        private void on_field_changed () {
            this.validate_fields();
            this.profile_changed();
        }

        private void validate_fields() {
            bool name_valid = this.validate_name();
            bool directory_valid = this.validate_directory();
            bool ssh_valid = this.validate_ssh_fields();
            
            this.is_valid = name_valid && directory_valid && ssh_valid;
        }
        
        private bool validate_name() {
            string name = this.name_row.get_text().strip();
            bool valid = name.length > 0 && this.is_valid_profile_name(name);
            
            if (valid) {
                this.name_row.remove_css_class("error");
            } else {
                this.name_row.add_css_class("error");
            }
            
            return valid;
        }
        
        private bool validate_directory() {
            string dir = this.working_directory_row.get_text();
            bool valid = dir != "" && GLib.FileUtils.test(dir, GLib.FileTest.IS_DIR);
            
            if (valid) {
                this.working_directory_row.remove_css_class("error");
            } else {
                this.working_directory_row.add_css_class("error");
            }
            
            return valid;
        }

        private bool validate_ssh_fields() {
            // Only validate SSH fields if this is an SSH profile
            if (this.profile.type != StProfileType.SSH) {
                return true;
            }

            bool valid = true;

            // SSH host is required
            string host = this.ssh_host_row.get_text().strip();
            if (host == "") {
                this.ssh_host_row.add_css_class("error");
                valid = false;
            } else {
                this.ssh_host_row.remove_css_class("error");
            }

            // SSH port must be valid
            int port = (int)this.ssh_port_row.get_value();
            if (port < 1 || port > 65535) {
                this.ssh_port_row.add_css_class("error");
                valid = false;
            } else {
                this.ssh_port_row.remove_css_class("error");
            }

            // SSH private key path must be valid if specified
            if (this.profile.ssh_private_key_path != null && this.profile.ssh_private_key_path.strip() != "") {
                var key_file = File.new_for_path(this.profile.ssh_private_key_path);
                if (!key_file.query_exists()) {
                    this.ssh_private_key_row.add_css_class("error");
                    valid = false;
                } else {
                    this.ssh_private_key_row.remove_css_class("error");
                }
            }

            return valid;
        }
        
        private bool is_valid_profile_name(string name) {
            // Allow Unicode characters, letters, numbers, spaces, and common symbols
            if (name.length == 0) return false;
            
            // Check for invalid filesystem characters
            string invalid_chars = "/\\:*?\"<>|";
            for (int i = 0; i < invalid_chars.length; i++) {
                if (name.index_of_char(invalid_chars[i]) != -1) {
                    return false;
                }
            }
            
            return true;
        }

        private void on_directory_picker_clicked () {
            var root = this.get_root() as Gtk.Window;
            if (root != null) {
                this.file_dialog.select_folder.begin (root, null, this.on_folder_selected);
            }
        }

        private void on_folder_selected(GLib.Object? source_object, GLib.AsyncResult res) {
            try {
                string? folder = this.file_dialog.select_folder.end(res).get_path();
                if (folder != null) {
                    this.working_directory_row.set_text(folder);
                    this.validate_fields();
                }
            } catch (GLib.Error e) {
            }
        }

        private void on_ssh_key_picker_clicked() {
            var root = this.get_root() as Gtk.Window;
            if (root != null) {
                this.ssh_key_dialog.open.begin(root, null, this.on_ssh_key_selected);
            }
        }

        private void on_ssh_key_selected(GLib.Object? source_object, GLib.AsyncResult res) {
            try {
                var file = this.ssh_key_dialog.open.end(res);
                if (file != null) {
                    this.profile.ssh_private_key_path = file.get_path();
                    this.ssh_private_key_row.set_subtitle("Selected: " + file.get_basename());
                    this.on_field_changed();
                    this.update_ssh_command_preview();
                }
            } catch (GLib.Error e) {
            }
        }

        private void update_ssh_fields_visibility() {
            bool is_ssh_profile = (this.profile.type == StProfileType.SSH);
            this.ssh_auth_group.set_visible(is_ssh_profile);
            this.ssh_options_group.set_visible(is_ssh_profile);
            this.ssh_host_row.set_visible(is_ssh_profile);
            this.ssh_user_row.set_visible(is_ssh_profile);
            this.ssh_port_row.set_visible(is_ssh_profile);
            this.ssh_private_key_row.set_visible(is_ssh_profile);
            this.ssh_extra_options_row.set_visible(is_ssh_profile);
            this.ssh_password_row.set_visible(is_ssh_profile);
        }

        private void update_container_fields_visibility() {
            bool is_distrobox = (this.profile.type == StProfileType.DISTROBOX);
            if (this.container_group != null) this.container_group.set_visible(is_distrobox);
        }

        private void update_ssh_command_preview() {
            if (this.profile.type != StProfileType.SSH) return;

            string? host = this.ssh_host_row.get_text().strip() != "" ? this.ssh_host_row.get_text().strip() : null;
            string? user = this.ssh_user_row.get_text().strip() != "" ? this.ssh_user_row.get_text().strip() : null;
            int port = (int)this.ssh_port_row.get_value();
            string? key = this.profile.ssh_private_key_path;
            string? extra = this.ssh_extra_options_row.get_text();
            string? spawn_cmd = this.spawn_command_row.get_text().strip() != "" ? this.spawn_command_row.get_text().strip() : null;

            var temp = new StProfile(
                this.profile.id, this.profile.name, this.profile.color_scheme, this.profile.working_directory,
                spawn_cmd, this.profile.profile_file, this.profile.icon_name, this.profile.type,
                this.profile.type_params, this.profile.type_subtitle,
                host, user, port, key, this.profile.ssh_auth_method, this.profile.ssh_strict_host_key_checking, extra
            );

            var args = temp.get_ssh_arguments();
            if (args == null) { this.ssh_command_preview_row.set_subtitle(""); return; }

            bool has_pw = (this.ssh_password_row.get_text().strip() != "");
            if (!has_pw && this.profile.id.strip() != "") has_pw = StSecretManager.has_password(this.profile.id);

            string preview = has_pw ? "sshpass -e " : "";
            foreach (string a in args) {
                if (a.index_of_char(' ') >= 0) preview += "\"" + a + "\" "; else preview += a + " ";
            }
            this.ssh_command_preview_row.set_subtitle(preview.strip());
        }
        
        private void on_distro_icon_picker_clicked() {
            var dialog = new DistroIconPickerDialog();
            dialog.icon_selected.connect((icon_name) => {
                this.set_icon(icon_name);
                dialog.close();
            });
            
            var root = this.get_root() as Gtk.Window;
            if (root != null) {
                dialog.set_transient_for(root);
                dialog.present();
            }
        }
        
        private void on_emoji_picker_clicked() {
            var emoji_chooser = new Gtk.EmojiChooser();
            emoji_chooser.emoji_picked.connect((emoji) => {
                this.set_icon(emoji);
                emoji_chooser.popdown();
            });
            
            // Position the emoji chooser relative to the button
            var root = this.get_root() as Gtk.Window;
            if (root != null) {
                emoji_chooser.set_parent(root);
                emoji_chooser.popup();
            }
        }
    }

    // Dialog for picking Linux distribution icons
    public class DistroIconPickerDialog : Adw.Window {
        public signal void icon_selected(string icon_name);
        
        public DistroIconPickerDialog() {
            this.title = "Choose Distribution Icon";
            this.default_width = 400;
            this.default_height = 300;
            this.modal = true;
            
            var header_bar = new Adw.HeaderBar();
            var cancel_button = new Gtk.Button.with_label("Cancel");
            cancel_button.clicked.connect(() => this.close());
            header_bar.pack_start(cancel_button);
            
            var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            content_box.append(header_bar);
            
            var scrolled = new Gtk.ScrolledWindow();
            scrolled.vexpand = true;
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
            
            var flow_box = new Gtk.FlowBox();
            flow_box.valign = Gtk.Align.START;
            flow_box.max_children_per_line = 4;
            flow_box.selection_mode = Gtk.SelectionMode.NONE;
            flow_box.margin_top = 12;
            flow_box.margin_bottom = 12;
            flow_box.margin_start = 12;
            flow_box.margin_end = 12;
            
            // Add icons for each Linux distribution
            foreach (string icon_name in AVAILABLE_ICONS) {
                var button = new Gtk.Button();
                button.add_css_class("flat");
                button.add_css_class("icon-button");
                
                var icon_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
                icon_box.margin_top = 12;
                icon_box.margin_bottom = 12;
                icon_box.margin_start = 12;
                icon_box.margin_end = 12;
                
                var icon_image = new Gtk.Image.from_resource(@"/io/stillhq/terminal/icons/$(icon_name).svg");
                icon_image.pixel_size = 48;
                icon_box.append(icon_image);
                
                var icon_label = new Gtk.Label(icon_name);
                icon_label.add_css_class("caption");
                icon_box.append(icon_label);
                
                button.set_child(icon_box);
                button.clicked.connect(() => {
                    this.icon_selected(icon_name);
                });
                
                flow_box.append(button);
            }
            
            scrolled.set_child(flow_box);
            content_box.append(scrolled);
            this.set_content(content_box);
        }
    }

    // Wrapper class for backwards compatibility with existing preferences system
    public class StProfileEditorPage : Adw.NavigationPage {
        private StProfileEditorWidget editor_widget;
        private StPrefsDialog dialog;
        public Adw.HeaderBar header;
        private Gtk.Button? button;

        public StProfileEditorPage (StPrefsDialog dialog, StProfile profile) {
            this.dialog = dialog;
            this.title = "Profile Settings";

            this.header = new Adw.HeaderBar ();
            this.header.set_show_start_title_buttons (false);
            this.header.set_show_end_title_buttons (false);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.append (this.header);
            
            this.editor_widget = new StProfileEditorWidget(profile);
            box.append(this.editor_widget);

            this.set_child (box);
            
            // Connect validation signal to update button sensitivity
            this.editor_widget.validation_changed.connect((is_valid) => {
                if (this.button != null) {
                    this.button.set_sensitive(is_valid);
                }
            });
        }

        public StProfile get_edited_profile () {
            return this.editor_widget.get_edited_profile();
        }

        public void set_button (Gtk.Button button) {
            this.button = button;
            button.add_css_class("suggested-action");
            button.set_sensitive(this.editor_widget.is_valid);
            this.header.pack_end (button);
        }
    }
}