namespace StillTerminal {
    public class StNewTabDialog : GLib.Object {
        public Adw.Dialog dialog;
        public Adw.NavigationView nav_view;
        public Adw.PreferencesPage page;
        public Adw.PreferencesGroup system;
        public Adw.PreferencesGroup containers;
        public Adw.PreferencesGroup ssh;
        private Adw.ActionRow system_empty_row;
        private Adw.ActionRow containers_empty_row;
        private Adw.ActionRow ssh_empty_row;
        public MainWindow main_window;

        public StNewTabDialog (MainWindow main_window) {
            this.main_window = main_window;
            this.dialog = new Adw.Dialog ();
            this.dialog.title = "Choose New Tab Profile";
            this.dialog.content_width = 600;
            this.dialog.content_height = 500;

            var header_bar = new Adw.HeaderBar ();

            // Add plus button to headerbar
            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.tooltip_text = "Add Profile";
            add_button.clicked.connect (() => {
                this.show_profile_creator ();
            });
            header_bar.pack_end (add_button);

            page = new Adw.PreferencesPage ();
            page.title = "New Tab Profile";
            page.icon_name = "io.stillhq.terminal-symbolic";

            system = new Adw.PreferencesGroup ();
            system.title = "System";
            system.description = "Terminals Accessing Your Main System";

            containers = new Adw.PreferencesGroup ();
            containers.title = "Containers";
            containers.description = "Terminals Accessing Your Containers";

            ssh = new Adw.PreferencesGroup ();
            ssh.title = "Remote";
            ssh.description = "Terminals Accessing Remote Connections";

            page.add (system);
            page.add (containers);
            page.add (ssh);

            // Build the main page layout
            var toolbar_view = new Adw.ToolbarView ();
            toolbar_view.add_top_bar (header_bar);
            toolbar_view.set_content (page);

            // Create main navigation page with custom headerbar
            var main_page = new Adw.NavigationPage.with_tag (toolbar_view, "Choose New Tab Profile", "main");

            // Set up navigation view
            this.nav_view = new Adw.NavigationView ();
            this.nav_view.add (main_page);

            this.dialog.set_child (this.nav_view);

            load_profiles ();
        }

        public void present (Gtk.Widget parent) {
            this.clear_groups ();
            this.load_profiles ();
            // Pop to main page in case we're on a subpage
            this.nav_view.pop_to_tag ("main");
            this.dialog.present (parent);
        }

        public void close () {
            this.dialog.close ();
        }

        public void load_profiles () {
            // Clear existing profiles
            clear_groups ();

            // Get all profiles and sort them
            StProfile[] profiles = get_profiles ();

            // Track profile counts for each group
            int system_count = 0;
            int containers_count = 0;
            int ssh_count = 0;

            // Sort profiles by name within each type
            foreach (var profile in profiles) {
                var action_row = new Adw.ActionRow ();
                action_row.title = profile.name;

                if (profile.type_subtitle != null && profile.type_subtitle != "") {
                    action_row.subtitle = profile.type_subtitle;
                }

                // Add profile icon with fallbacks based on type
                var icon_widget = create_profile_icon (profile);
                action_row.add_prefix (icon_widget);

                // Add right arrow icon to all profile rows
                var arrow_icon = new Gtk.Image.from_icon_name ("go-next-symbolic");
                arrow_icon.add_css_class ("dim-label");
                action_row.add_suffix (arrow_icon);

                action_row.activatable = true;
                action_row.activated.connect (() => {
                    this.main_window.add_tab (profile);
                    this.close ();
                });

                // Add to appropriate group based on type
                switch (profile.type) {
                    case StProfileType.SYSTEM:
                        system.add (action_row);
                        system_count++;
                        break;
                    case StProfileType.DISTROBOX:
                        containers.add (action_row);
                        containers_count++;
                        break;
                    case StProfileType.SSH:
                        ssh.add (action_row);
                        ssh_count++;
                        break;
                }
            }

            // Add "no profiles exist" placeholders to empty groups
            if (system_count == 0) {
                this.system_empty_row = new Adw.ActionRow ();
                this.system_empty_row.title = "No System Profiles Exist";
                this.system_empty_row.sensitive = false;
                system.add (this.system_empty_row);
            }

            if (containers_count == 0) {
                this.containers_empty_row = new Adw.ActionRow ();
                this.containers_empty_row.title = "No Container Profiles Exist";
                this.containers_empty_row.sensitive = false;
                containers.add (this.containers_empty_row);
            }

            if (ssh_count == 0) {
                this.ssh_empty_row = new Adw.ActionRow ();
                this.ssh_empty_row.title = "No Remote Profiles Exist";
                this.ssh_empty_row.sensitive = false;
                ssh.add (this.ssh_empty_row);
            }

            // Always show groups
            system.visible = true;
            containers.visible = true;
            ssh.visible = true;
        }

        private void clear_groups () {
            // Recreate groups to ensure they're clean
            page.remove (system);
            page.remove (containers);
            page.remove (ssh);

            // Clear empty row references
            this.system_empty_row = null;
            this.containers_empty_row = null;
            this.ssh_empty_row = null;

            system = new Adw.PreferencesGroup ();
            system.title = "System";
            system.description = "Terminals Accessing Your Main System";

            containers = new Adw.PreferencesGroup ();
            containers.title = "Containers";
            containers.description = "Terminals Accessing Your Containers";

            ssh = new Adw.PreferencesGroup ();
            ssh.title = "Remote";
            ssh.description = "Terminals Accessing Remote Connections";

            page.add (system);
            page.add (containers);
            page.add (ssh);
        }

        private Gtk.Widget create_profile_icon (StProfile profile) {
            // Check if the icon is an emoji
            if (profile.icon_name != null && profile.icon_name != "" && is_emoji (profile.icon_name)) {
                var emoji_label = new Gtk.Label (profile.icon_name);
                emoji_label.add_css_class ("large-emoji");
                emoji_label.set_size_request (32, 32);
                return emoji_label;
            }

            // Create image widget
            var icon_image = new Gtk.Image ();
            icon_image.pixel_size = 32;

            // Check if it's a Linux distro icon (GTK will find it in registered icon theme paths)
            if (profile.icon_name != null && profile.icon_name in AVAILABLE_ICONS) {
                icon_image.set_from_icon_name (profile.icon_name);
            } else if (profile.type == StProfileType.DISTROBOX) {
                // Container profiles: use our custom symbolic icon (GTK will apply theme styling)
                icon_image.set_from_icon_name ("container-symbolic");
            } else if (profile.type == StProfileType.SSH) {
                // SSH profiles: use our custom symbolic icon (GTK will apply theme styling)
                icon_image.set_from_icon_name ("remote-terminal-symbolic");
            } else {
                // System/default profiles: same terminal icon used elsewhere in settings
                icon_image.set_from_icon_name ("utilities-terminal-symbolic");
            }

            return icon_image;
        }

        private bool is_emoji (string text) {
            // Simple check for emoji - look for non-ASCII characters that are likely emoji
            uint8[] bytes = text.data;
            for (int i = 0; i < bytes.length; i++) {
                if (bytes[i] > 127) { // Non-ASCII character, likely emoji
                    return true;
                }
            }
            return false;
        }

        private void show_profile_creator () {
            var selector = new StProfileTypeSelectorPage ();
            selector.type_selected.connect ((t) => {
                this.show_profile_creator_for_type (t);
            });
            this.nav_view.push (selector);
        }

        private void show_profile_creator_for_type (StProfileType profile_type) {
            var page = new StSimpleProfileCreatorPage (profile_type);
            page.profile_created.connect ((profile) => {
                this.main_window.add_tab (profile);
                this.close ();
            });
            this.nav_view.push (page);
        }
    }

    // Type selector page for new tab profile creation flow (within dialog)
    public class StProfileTypeSelectorPage : Adw.NavigationPage {
        public signal void type_selected (StProfileType type);
        private StProfileType selected_type = StProfileType.SYSTEM;

        public StProfileTypeSelectorPage() {
            this.title = "Select Profile Type";

            var header_bar = new Adw.HeaderBar ();
            header_bar.set_show_start_title_buttons (false);
            header_bar.set_show_end_title_buttons (false);

            var next_button = new Gtk.Button.with_label ("Next");
            next_button.add_css_class ("suggested-action");
            next_button.clicked.connect (() => {
                this.type_selected (this.selected_type);
            });
            header_bar.pack_end (next_button);

            var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content_box.append (header_bar);

            var page = new Adw.PreferencesPage ();
            var group = new Adw.PreferencesGroup ();
            group.set_title ("Profile Type");
            page.add (group);

            Gtk.CheckButton? last_button = null;

            var system_row = new Adw.ActionRow ();
            system_row.set_title ("System Profile");
            system_row.set_subtitle ("Use your local system");
            var system_icon = new Gtk.Image.from_icon_name ("computer-symbolic");
            system_row.add_prefix (system_icon);
            var system_button = new Gtk.CheckButton ();
            system_button.valign = Gtk.Align.CENTER;
            system_button.halign = Gtk.Align.END;
            system_button.set_group (last_button);
            system_button.set_active (true);
            system_button.toggled.connect ((btn) => { if (btn.active) {
                                                          this.selected_type = StProfileType.SYSTEM;
                                                      }
                                           });
            system_row.add_suffix (system_button);
            system_row.set_activatable_widget (system_button);
            group.add (system_row);
            last_button = system_button;

            var container_row = new Adw.ActionRow ();
            container_row.set_title ("Container Profile");
            container_row.set_subtitle ("Use a container (Distrobox)");
            var container_icon = new Gtk.Image.from_icon_name ("container-symbolic");
            container_row.add_prefix (container_icon);
            var container_button = new Gtk.CheckButton ();
            container_button.valign = Gtk.Align.CENTER;
            container_button.halign = Gtk.Align.END;
            container_button.set_group (last_button);
            container_button.toggled.connect ((btn) => { if (btn.active) {
                                                             this.selected_type = StProfileType.DISTROBOX;
                                                         }
                                              });
            container_row.add_suffix (container_button);
            container_row.set_activatable_widget (container_button);
            group.add (container_row);
            last_button = container_button;

            var ssh_row = new Adw.ActionRow ();
            ssh_row.set_title ("SSH Profile");
            ssh_row.set_subtitle ("Connect to a remote server");
            // Use our bundled remote-terminal icon for SSH
            var ssh_icon = new Gtk.Image.from_icon_name ("remote-terminal-symbolic");
            ssh_row.add_prefix (ssh_icon);
            var ssh_button = new Gtk.CheckButton ();
            ssh_button.valign = Gtk.Align.CENTER;
            ssh_button.halign = Gtk.Align.END;
            ssh_button.set_group (last_button);
            ssh_button.toggled.connect ((btn) => { if (btn.active) {
                                                       this.selected_type = StProfileType.SSH;
                                                   }
                                        });
            ssh_row.add_suffix (ssh_button);
            ssh_row.set_activatable_widget (ssh_button);
            group.add (ssh_row);

            content_box.append (page);
            this.set_child (content_box);
        }
    }

    // Simple profile creator page for new tab dialog context (within dialog)
    public class StSimpleProfileCreatorPage : Adw.NavigationPage {
        public signal void profile_created (StProfile profile);
        private StillTerminal.StProfileEditorWidget editor_widget;
        private Gtk.Button create_button;

        public StSimpleProfileCreatorPage(StProfileType profile_type = StProfileType.SYSTEM) {
            this.title = "Create New Profile";

            var header_bar = new Adw.HeaderBar ();
            header_bar.set_show_start_title_buttons (false);
            header_bar.set_show_end_title_buttons (false);

            this.create_button = new Gtk.Button.with_label ("Create");
            this.create_button.add_css_class ("suggested-action");
            this.create_button.clicked.connect (this.on_create_clicked);
            header_bar.pack_end (this.create_button);

            var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content_box.append (header_bar);

            // Create editor widget with a blank profile of the specified type
            var blank_profile = StProfile.new_blank_profile ();
            blank_profile.type = profile_type;

            // Set appropriate default values based on type
            switch (profile_type) {
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

            this.editor_widget = new StillTerminal.StProfileEditorWidget (blank_profile);
            content_box.append (this.editor_widget);

            // Connect validation signal to update button sensitivity
            this.editor_widget.validation_changed.connect ((is_valid) => {
                this.create_button.set_sensitive (is_valid);
            });

            // Set initial button state
            this.create_button.set_sensitive (this.editor_widget.is_valid);

            this.set_child (content_box);
        }

        private void on_create_clicked () {
            var profile = this.editor_widget.get_edited_profile ();
            profile.save_to_json (get_local_profile_dir () + "/" + profile.id + ".json");
            this.profile_created (profile);
        }
    }
}
