namespace StillTerminal {
    public enum StSshAuthMethod {
        PUBLIC_KEY,
        PASSWORD_STORED,
        PASSWORD_INTERACTIVE;

        public string to_string() {
            switch (this) {
                case PUBLIC_KEY: return "public_key";
                case PASSWORD_STORED: return "password_stored";
                case PASSWORD_INTERACTIVE: return "password_interactive";
            }
            return "public_key";
        }

        public static StSshAuthMethod from_string(string s) {
            switch (s.ascii_down()) {
                case "password_stored": return PASSWORD_STORED;
                case "password_interactive": return PASSWORD_INTERACTIVE;
                case "public_key":
                default:
                    return PUBLIC_KEY;
            }
        }
    }
    public enum StProfileType {
        SYSTEM, DISTROBOX, SSH;

        public string to_string() {
            switch (this) {
                case SYSTEM:
                    return "system";
                case DISTROBOX:
                    return "distrobox";
                case SSH:
                    return "ssh";
            }
            return "";
        }

        public static StProfileType? from_string(string type) {
            switch (type.ascii_down()) {
                case "system":
                    return SYSTEM;
                case "distrobox":
                    return DISTROBOX;
                case "ssh":
                    return SSH;
            }
            return null;
        }
    }

    public class StProfile : GLib.Object {
        public string id;
        public string name;
        public string color_scheme;
        public string working_directory;
        public string? spawn_command;
        public string? profile_file;
        public string? icon_name;
        public StProfileType type;
        // Dictionary of type-specific parameters for readability
        public Gee.HashMap<string,string>? type_params;
        public string? type_subtitle;
        
        // SSH-specific fields
        public string? ssh_host;
        public string? ssh_user;
        public int ssh_port;
        public string? ssh_private_key_path;
        public StSshAuthMethod ssh_auth_method = StSshAuthMethod.PUBLIC_KEY;
        public bool ssh_strict_host_key_checking = true;
        public string? ssh_extra_options;
    
        public StProfile (
            string id, string name, string color_scheme, string working_directory,
            string? spawn_command = null, string? profile_file = null,
            string? icon_name = null, StProfileType type = StProfileType.SYSTEM,
            Gee.HashMap<string,string>? type_params = null, string? type_subtitle = null,
            string? ssh_host = null, string? ssh_user = null, int ssh_port = 22,
            string? ssh_private_key_path = null,
            StSshAuthMethod ssh_auth_method = StSshAuthMethod.PUBLIC_KEY,
            bool ssh_strict_host_key_checking = true,
            string? ssh_extra_options = null
        ) {
            this.id = id;
            this.name = name;
            this.color_scheme = color_scheme;
            this.working_directory = working_directory;
            this.spawn_command = spawn_command;
            this.profile_file = profile_file;
            this.icon_name = icon_name;
            this.type = type;
            this.type_params = type_params;
            this.type_subtitle = type_subtitle;
            this.ssh_host = ssh_host;
            this.ssh_user = ssh_user;
            this.ssh_port = ssh_port;
            this.ssh_private_key_path = ssh_private_key_path;
            this.ssh_auth_method = ssh_auth_method;
            this.ssh_strict_host_key_checking = ssh_strict_host_key_checking;
            this.ssh_extra_options = ssh_extra_options;
        }

        public static StProfile? new_blank_profile() {
            return new StProfile(
                "",
                "",
                "system",
                GLib.Environment.get_home_dir(),
                null,
                null,
                null,
                StProfileType.SYSTEM,
                null,
                null,
                null, null, 22, null, StSshAuthMethod.PUBLIC_KEY, true, null
            );
        }
    
        public static StProfile? new_from_json(string filename) {
            Json.Parser parser = new Json.Parser();
            try {
                parser.load_from_file (filename);
            } catch (GLib.Error e) {
                return null;
            }
    
            Json.Object obj = parser.get_root().get_object();
            
            StProfileType profile_type = StProfileType.SYSTEM;
            if (obj.has_member("type")) {
                profile_type = StProfileType.from_string(obj.get_string_member("type"));
            }
    
            // Load type_params
            Gee.HashMap<string,string>? type_params = null;
            if (obj.has_member("type_params")) {
                type_params = new Gee.HashMap<string,string>();
                var p = obj.get_object_member("type_params");
                foreach (string key in p.get_members()) {
                    // Store only string-typed members
                    type_params[key] = p.get_string_member(key);
                }
            }

            string? ssh_host = null;
            string? ssh_user = null;
            int ssh_port = 22;
            string? ssh_private_key_path = null;
            StSshAuthMethod ssh_auth_method = StSshAuthMethod.PUBLIC_KEY;
            bool ssh_strict_host_key_checking = true;
            string? ssh_extra_options = null;
            if (profile_type == StProfileType.SSH) {
                ssh_host = obj.has_member("ssh_host") ? obj.get_string_member("ssh_host") : null;
                ssh_user = obj.has_member("ssh_user") ? obj.get_string_member("ssh_user") : null;
                ssh_port = obj.has_member("ssh_port") ? (int) obj.get_int_member("ssh_port") : 22;
                ssh_private_key_path = obj.has_member("ssh_private_key_path") ? obj.get_string_member("ssh_private_key_path") : null;
                if (obj.has_member("ssh_auth_method")) {
                    ssh_auth_method = StSshAuthMethod.from_string(obj.get_string_member("ssh_auth_method"));
                }
                if (obj.has_member("ssh_strict_host_key_checking")) {
                    // Prefer boolean; assume valid schema
                    ssh_strict_host_key_checking = obj.get_boolean_member("ssh_strict_host_key_checking");
                }
                if (obj.has_member("ssh_extra_options")) {
                    ssh_extra_options = obj.get_string_member("ssh_extra_options");
                }
            }
    
            return new StProfile(
                obj.get_string_member("id"),
                obj.get_string_member("name"),
                obj.has_member("color_scheme") ? obj.get_string_member("color_scheme") : "system",
                obj.has_member("working_directory") ? obj.get_string_member("working_directory") : "",
                obj.has_member("spawn_command") ? obj.get_string_member("spawn_command") : "",
                filename,
                obj.has_member("icon_name") ? obj.get_string_member("icon_name") : "",
                profile_type,
                type_params,
                obj.has_member("type_subtitle") ? obj.get_string_member("type_subtitle") : "",
                ssh_host, ssh_user, ssh_port, ssh_private_key_path,
                ssh_auth_method, ssh_strict_host_key_checking, ssh_extra_options
            );
        }
    
        public Gee.HashMap<string, string> as_hash() {
            var hash = new Gee.HashMap<string, string>();
            hash["id"] = this.id;
            hash["name"] = this.name;
            hash["color_scheme"] = this.color_scheme;
            hash["working_directory"] = this.working_directory;
            if (this.spawn_command != null) hash["spawn_command"] = this.spawn_command;
            if (this.profile_file != null) hash["profile_file"] = this.profile_file;
            if (this.icon_name != null) hash["icon_name"] = this.icon_name;
            hash["type"] = this.type.to_string();
            if (this.type_params != null) {
                foreach (var entry in this.type_params.entries) {
                    hash["type_params." + entry.key] = entry.value;
                }
            }
            if (this.type_subtitle != null) hash["type_subtitle"] = this.type_subtitle;
            if (this.ssh_host != null) hash["ssh_host"] = this.ssh_host;
            if (this.ssh_user != null) hash["ssh_user"] = this.ssh_user;
            hash["ssh_port"] = this.ssh_port.to_string();
            if (this.ssh_private_key_path != null) hash["ssh_private_key_path"] = this.ssh_private_key_path;
            hash["ssh_auth_method"] = this.ssh_auth_method.to_string();
            hash["ssh_strict_host_key_checking"] = this.ssh_strict_host_key_checking ? "true" : "false";
            if (this.ssh_extra_options != null) hash["ssh_extra_options"] = this.ssh_extra_options;
            return hash;
        }
    
        public void save_to_json(string filename) {
            var builder = new Json.Builder();
            builder.begin_object();

            // Add all string fields
            var hash = this.as_hash();
            foreach (var entry in hash.entries) {
                if (entry.key == "ssh_port") {
                    // Handle SSH port as integer
                    builder.set_member_name(entry.key);
                    builder.add_int_value(int.parse(entry.value));
                } else if (entry.key.has_prefix("type_params.")) {
                    // Defer: we write type_params as a single object outside this loop
                } else if (entry.key == "ssh_strict_host_key_checking") {
                    builder.set_member_name(entry.key);
                    builder.add_boolean_value(entry.value == "true" || entry.value == "1");
                } else {
                    // Handle all other fields as strings
                    builder.set_member_name(entry.key);
                    builder.add_string_value(entry.value);
                }
            }

            // Write type_params map if present
            if (this.type_params != null && this.type_params.size > 0) {
                builder.set_member_name("type_params");
                builder.begin_object();
                foreach (var kv in this.type_params.entries) {
                    builder.set_member_name(kv.key);
                    builder.add_string_value(kv.value);
                }
                builder.end_object();
            }

            builder.end_object();

            var generator = new Json.Generator();
            generator.set_pretty(true);
            generator.set_root(builder.get_root());

            try {
                generator.to_file(filename);
            } catch (GLib.Error e) {
            }
        }

        public string[]? get_ssh_arguments() {
            if (this.type != StProfileType.SSH) {
                return null;
            }

            if (this.ssh_host == null || this.ssh_host.strip() == "") {
                return null;
            }

            var args = new Gee.ArrayList<string>();
            args.add("ssh");

            // Add user if specified
            if (this.ssh_user != null && this.ssh_user.strip() != "") {
                args.add("-l");
                args.add(this.ssh_user.strip());
            }

            // Add port if not default (22)
            if (this.ssh_port != 22) {
                args.add("-p");
                args.add(this.ssh_port.to_string());
            }

            // Add private key if specified
            if (this.ssh_private_key_path != null && this.ssh_private_key_path.strip() != "") {
                args.add("-i");
                args.add(this.ssh_private_key_path.strip());
                // Ensure only the provided identity is used (avoid agent/default keys masking invalid -i)
                args.add("-o");
                args.add("IdentitiesOnly=yes");
            }

            // Extra options (advanced users)
            if (this.ssh_extra_options != null && this.ssh_extra_options.strip() != "") {
                foreach (string part in this.ssh_extra_options.strip().split(" ")) {
                    if (part.strip() != "") args.add(part);
                }
            }

            // Allocate a TTY when executing a remote command so it runs interactively
            bool has_remote_command = this.spawn_command != null && this.spawn_command.strip() != "";
            if (has_remote_command) {
                // Use -tt to force TTY allocation to avoid some server configs closing early
                args.add("-tt");
            }

            // Add host
            args.add(this.ssh_host.strip());

            // If a starting command is provided, run it on the remote side as a single string
            // This preserves intended quoting when shown in the preview and executed remotely
            if (has_remote_command) {
                args.add(this.spawn_command.strip());
            }

            return args.to_array();
        }
    }

    public StProfile get_fallback_profile() {
        return new StProfile(
            "system_fallback",
            "System",
            "system",
            GLib.Environment.get_home_dir(),
            null,
            null,
            null,
            StProfileType.SYSTEM,
            null,
            "stillOS (Fallback Profile)",
            null, null, 22, null
        );
    }

    public StProfile get_default_profile() {
        StProfile[] profiles = get_profiles ();
        if (profiles.length == 0) {
            return get_fallback_profile();
        }
        foreach (var profile in profiles) {
            if (profile.id == "default") {
                return profile;
            }
        }
        return profiles[0];
    }

    public string get_local_profile_dir() {
        File file = File.new_build_filename(
            GLib.Environment.get_home_dir(),
            "/.local/share/stillTerminal/profiles"
        );

        // Create the directory if it doesn't exist
        if (!(file.query_exists())) {
            try {
                file.make_directory_with_parents();
            } catch (GLib.Error e) {
            }
        }

        // Checking if a directory is empty and making a default profile if it is
        try {
            Dir dir = Dir.open(file.get_path(), 0);
            string? name = null;
            bool profiles_empty = false;

            while ((name = dir.read_name()) != null) {
                if (name != "." && name != "..") {
                    profiles_empty = true;
                }
            }

            if (!(profiles_empty)) {
                var profile = get_fallback_profile();
                    profile.id = "default";
                    profile.name = "Default";
                    profile.type_subtitle = "stillOS Default Profile";
                    profile.save_to_json(file.get_child("default.json").get_path());
            }
        } catch (GLib.FileError e) {
        }

        return file.get_path ();
    }

    public StProfile[] get_profiles() {
        var profile_dir = get_local_profile_dir();
        StProfile[] profiles = {};

        var dir = File.new_for_path(profile_dir);
        try {
            var enumerator = dir.enumerate_children(
                "standard::name,standard::type",
                FileQueryInfoFlags.NONE,
                null
            );

            FileInfo? info;
            while ((info = enumerator.next_file()) != null) {
                if (info.get_file_type() != FileType.REGULAR) {
                    continue;
                }
    
                var profile = StProfile.new_from_json(
                    GLib.Path.build_filename (profile_dir, info.get_name())
                );
                if (profile != null) {
                    profiles += profile;
                }
            }
        } catch (GLib.Error e) {
            return {get_fallback_profile ()};
        }

        // Sort profiles: default first, then alphabetically by name
        return sort_profiles_with_default_first(profiles);
    }
    
    private StProfile[] sort_profiles_with_default_first(StProfile[] profiles) {
        StProfile[] sorted_profiles = {};
        StProfile? default_profile = null;
        Gee.ArrayList<StProfile> other_profiles = new Gee.ArrayList<StProfile>();
        
        // Separate default profile from others
        foreach (var profile in profiles) {
            if (profile.id == "default") {
                default_profile = profile;
            } else {
                other_profiles.add(profile);
            }
        }
        
        // Sort other profiles alphabetically by name (case-insensitive)
        other_profiles.sort((a, b) => {
            return a.name.ascii_casecmp(b.name);
        });
        
        // Add default first (if it exists), then alphabetically sorted profiles
        if (default_profile != null) {
            sorted_profiles += default_profile;
        }
        
        foreach (var profile in other_profiles) {
            sorted_profiles += profile;
        }
        
        return sorted_profiles;
    }
}