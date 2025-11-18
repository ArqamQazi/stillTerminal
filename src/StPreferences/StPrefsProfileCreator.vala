namespace StillTerminal {
    public enum CreationType {
        SYSTEM, SSH, CUSTOM_DISTROBOX;
    }

    public class StProfileCreatorTypePage : Adw.NavigationPage {
        StPrefsDialog dialog;
        Adw.PreferencesGroup pref_group;
        CreationType selected_option;

        public StProfileCreatorTypePage (StPrefsDialog dialog) {
            this.dialog = dialog;
            this.can_pop = false;
            this.title = "New Profile";

            var header = new Adw.HeaderBar ();
            header.set_show_start_title_buttons (false);
            header.set_show_end_title_buttons (false);
            
            var preferences_page = new Adw.PreferencesPage ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.append (header);
            box.append (preferences_page);

            this.pref_group = new Adw.PreferencesGroup ();
            this.pref_group.set_title("Select Profile Type");
            preferences_page.add(this.pref_group);
            this.set_child(box);

            Gtk.CheckButton? last_button = null;
            add_check_button(
                out last_button,
                "System Profile", "Use the system profile",
                "utilities-terminal-symbolic",
                CreationType.SYSTEM, last_button
            );
            last_button.set_active (true);
            var more_soon = new Adw.ActionRow();
            more_soon.set_title("More Options Coming Soon");
            more_soon.set_subtitle("We're working on adding more profile types");
            this.pref_group.add (more_soon);

            add_check_button(
                out last_button,
                "Custom Distrobox Profile", "Create a custom distrobox profile",
                "container-symbolic",
                CreationType.CUSTOM_DISTROBOX, last_button
            );

            // No explicit Cancel when a back button exists in the dialog

            var next_button = new Gtk.Button.with_label("Next");
            next_button.add_css_class("suggested-action");
            next_button.clicked.connect( () => {
                next_page();
            });
            header.pack_end(next_button);
            
        }
    
        public Adw.ActionRow add_check_button (
            out Gtk.CheckButton button,
            string title, string subtitle,
            string icon_name, CreationType type,
            Gtk.CheckButton? last_button
        ) {
            Adw.ActionRow row = new Adw.ActionRow();
            row.set_title(title);
            row.set_subtitle(subtitle);
            // All icons are now loaded from the icon theme
            Gtk.Image icon = new Gtk.Image.from_icon_name(icon_name);
            row.add_prefix(icon);
            button = new Gtk.CheckButton ();
            button.valign = Gtk.Align.CENTER;
            button.halign = Gtk.Align.END;
            if (last_button != null) {
                button.set_group(last_button);
            }
            row.add_suffix(button);
            this.pref_group.add (row);
            button.toggled.connect ((button) => {
                if (button.active) {
                    this.selected_option = type;
                }
            });
            row.set_activatable_widget (button);
            return row;
        }

        public void next_page () {
            switch (this.selected_option) {
                case CreationType.SYSTEM:
                    this.push_profile_editor (StProfile.new_blank_profile ());
                    break;
                case CreationType.CUSTOM_DISTROBOX:
                    var page = new StCustomDistroboxCreatorPage(this.dialog);
                    this.dialog.preferences_dialog.push_subpage(page);
                    break;
            }
        }

        public void push_profile_editor (StProfile profile) {
            var editor_page = new StProfileEditorPage(this.dialog, profile);
            var create_button = new Gtk.Button.with_label("Create");
            create_button.set_sensitive (false);
            create_button.clicked.connect(() => {
                this.create_profile_button (editor_page);
            });
            editor_page.set_button(create_button);
            this.dialog.preferences_dialog.push_subpage(editor_page);
        }

        public void create_profile_button (StProfileEditorPage editor_page) {
            var profile = editor_page.get_edited_profile();
            profile.save_to_json (get_local_profile_dir() + "/" + profile.id + ".json");
            this.dialog.window.add_tab(profile);

            this.dialog.preferences_dialog.close();
        }
    }

    // Page to collect minimal Distrobox settings
    public class StCustomDistroboxCreatorPage : Adw.NavigationPage {
        StPrefsDialog dialog;
        Adw.PreferencesGroup group;
        Adw.EntryRow name_row;
        Adw.EntryRow image_row;
        Adw.ExpanderRow advanced_row;
        Adw.EntryRow extra_args_row;

        public StCustomDistroboxCreatorPage (StPrefsDialog dialog) {
            this.dialog = dialog;
            this.title = "Distrobox Settings";

            var header = new Adw.HeaderBar ();
            header.set_show_start_title_buttons (false);
            header.set_show_end_title_buttons (false);

            var preferences_page = new Adw.PreferencesPage ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.append (header);
            box.append (preferences_page);
            this.set_child (box);

            this.group = new Adw.PreferencesGroup ();
            this.group.set_title ("Container Profile");
            preferences_page.add (this.group);

            // Profile name
            this.name_row = new Adw.EntryRow ();
            this.name_row.set_title ("Profile Name (Required)");
            this.name_row.set_text ("Distrobox");
            this.group.add (this.name_row);

            this.image_row = new Adw.EntryRow ();
            this.image_row.set_title ("Image");
            this.image_row.set_text ("docker.io/library/ubuntu:latest");
            this.group.add (this.image_row);

            this.advanced_row = new Adw.ExpanderRow ();
            this.advanced_row.set_title ("Advanced");
            this.advanced_row.set_subtitle ("Optional extra enter args (space-separated)");
            this.group.add (this.advanced_row);

            this.extra_args_row = new Adw.EntryRow ();
            this.extra_args_row.set_title ("Extra Enter Args");
            this.extra_args_row.set_text ("");
            this.advanced_row.add_row (this.extra_args_row);

            // No explicit Back; rely on dialog's built-in back navigation

            var create_button = new Gtk.Button.with_label ("Create");
            create_button.add_css_class ("suggested-action");
            create_button.clicked.connect (this.on_create_clicked);
            header.pack_end (create_button);
        }

        private void on_create_clicked () {
            // Validate name
            string name = this.name_row.get_text().strip();
            if (name == "") {
                this.name_row.add_css_class("error");
                return;
            }

            // Slug helpers - add timestamp to ensure uniqueness
            string slug_for_id = name.ascii_down().replace (" ", "_");
            int64 timestamp = GLib.get_real_time() / 1000000;
            slug_for_id = "%s_%ld".printf(slug_for_id, (long)timestamp);
            
            string slug_for_container = name.ascii_down().replace (" ", "_");
            // Also make container name unique with timestamp
            string container_name = "sterm_%s_%ld".printf(slug_for_container, (long)timestamp);

            var params = new Gee.HashMap<string,string>();
            string image = this.image_row.get_text().strip();
            params["image"] = image != "" ? image : "docker.io/library/ubuntu:latest";
            string extra = this.extra_args_row.get_text().strip();
            if (extra != "") params["enter_args"] = extra;
            // Container name derived from profile name with timestamp for uniqueness
            params["name"] = container_name;

            // Build profile (default container icon: Ubuntu)
            var profile = new StProfile(
                slug_for_id,
                name,
                "system",
                GLib.Environment.get_home_dir(),
                null,
                null,
                "ubuntu-symbolic",
                StProfileType.DISTROBOX,
                params,
                "Container Environment"
            );

            // Save and open
            string file = get_local_profile_dir() + "/" + profile.id + ".json";
            profile.save_to_json (file);
            this.dialog.window.add_tab(profile);
            this.dialog.preferences_dialog.close();
        }
    }

    // Lightweight selector usable inside Preferences as a subpage
    public class StProfileTypeSelectorSubpage : Adw.NavigationPage {
        public signal void type_selected(StProfileType type);
        StPrefsDialog dialog;
        Adw.PreferencesGroup pref_group;
        StProfileType selected_type = StProfileType.SYSTEM;

        public StProfileTypeSelectorSubpage(StPrefsDialog dialog) {
            this.dialog = dialog;
            this.title = "Select Profile Type";

            var header = new Adw.HeaderBar ();
            header.set_show_start_title_buttons (false);
            header.set_show_end_title_buttons (false);

            var preferences_page = new Adw.PreferencesPage ();
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.append (header);
            box.append (preferences_page);
            this.set_child (box);

            this.pref_group = new Adw.PreferencesGroup ();
            preferences_page.add (this.pref_group);

            Gtk.CheckButton? last_button = null;
            add_check_button(out last_button, "System Profile", "Use the system profile", "utilities-terminal-symbolic", StProfileType.SYSTEM, null);
            last_button.set_active(true);
            add_check_button(out last_button, "Container Profile", "Use a container (Distrobox)", "container-symbolic", StProfileType.DISTROBOX, last_button);
            add_check_button(out last_button, "SSH Profile", "Connect to a remote server", "remote-terminal-symbolic", StProfileType.SSH, last_button);

            // No explicit Cancel; dialog provides a back button

            var next_button = new Gtk.Button.with_label("Next");
            next_button.add_css_class("suggested-action");
            next_button.clicked.connect(() => this.type_selected(this.selected_type));
            header.pack_end(next_button);
        }

        private Adw.ActionRow add_check_button(out Gtk.CheckButton button, string title, string subtitle, string icon_name, StProfileType type, Gtk.CheckButton? last_button) {
            Adw.ActionRow row = new Adw.ActionRow();
            row.set_title(title);
            row.set_subtitle(subtitle);
            Gtk.Image icon = new Gtk.Image.from_icon_name (icon_name);
            row.add_prefix(icon);
            button = new Gtk.CheckButton ();
            button.valign = Gtk.Align.CENTER;
            button.halign = Gtk.Align.END;
            if (last_button != null) button.set_group(last_button);
            row.add_suffix(button);
            this.pref_group.add (row);
            button.toggled.connect ((btn) => { if (btn.active) this.selected_type = type; });
            row.set_activatable_widget (button);
            return row;
        }
    }
}