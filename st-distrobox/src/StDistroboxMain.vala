/**
 * Standalone st-distrobox helper.
 *
 * Reads a stillTerminal profile JSON and ensures a distrobox exists, then enters it.
 * Usage:
 *   st-distrobox --profile-file /path/to/profile.json
 *   st-distrobox --profile-id <id>  (searches default profile dir)
 */

namespace StDistrobox {
    public class Profile : GLib.Object {
        public string id;
        public string? spawn_command;
        public string type;
        public Gee.HashMap<string,string>? type_params;

        public static Profile? from_file(string filename) {
            var parser = new Json.Parser();
            try { parser.load_from_file(filename); } catch (Error e) { return null; }
            var obj = parser.get_root().get_object();

            var p = new Profile();
            p.id = obj.get_string_member("id");
            p.type = obj.has_member("type") ? obj.get_string_member("type") : "system";
            p.spawn_command = obj.has_member("spawn_command") ? obj.get_string_member("spawn_command") : null;

            if (obj.has_member("type_params")) {
                p.type_params = new Gee.HashMap<string,string>();
                var tp = obj.get_object_member("type_params");
                foreach (string key in tp.get_members()) {
                    try { p.type_params[key] = tp.get_string_member(key); } catch (Error e) {}
                }
            }
            return p;
        }
    }

    private string get_profile_dir() {
        string home_dir = GLib.Environment.get_home_dir();
        return GLib.Path.build_filename(home_dir, ".local", "share", "stillTerminal", "profiles");
    }

    private Profile? load_profile_by_id(string id) {
        string dir = get_profile_dir();
        try {
            var d = File.new_for_path(dir);
            var e = d.enumerate_children("standard::name,standard::type", FileQueryInfoFlags.NONE, null);
            FileInfo? info;
            while ((info = e.next_file()) != null) {
                if (info.get_file_type() != FileType.REGULAR) continue;
                var p = Profile.from_file(GLib.Path.build_filename(dir, info.get_name()));
                if (p != null && p.id == id) return p;
            }
        } catch (Error e) {}
        return null;
    }

    private bool container_exists(string name, bool debug) {
        try {
            string[] argv = {"distrobox", "enter", "-n", name, "--", "true"};
            if (debug) {
                stderr.printf("[st-distrobox] exists check: %s\n", string.joinv(" ", argv));
            }
            int status = 1; string? out_str = null; string? err_str = null;
            GLib.Process.spawn_sync(null, argv, null, GLib.SpawnFlags.SEARCH_PATH, null, out out_str, out err_str, out status);
            if (debug) {
                stderr.printf("[st-distrobox] exists status=%d\n", status);
                if (out_str != null && out_str.strip() != "") stderr.printf("[stdout] %s\n", out_str);
                if (err_str != null && err_str.strip() != "") stderr.printf("[stderr] %s\n", err_str);
            }
            return status == 0;
        } catch (Error e) {
            if (debug) stderr.printf("[st-distrobox] exists check error: %s\n", e.message);
            return false;
        }
    }

    private bool create_container(Profile p, string name, string image, bool debug) {
        try {
            bool has_nvidia = GLib.FileUtils.test("/dev/nvidia0", GLib.FileTest.EXISTS) ||
                              GLib.FileUtils.test("/proc/driver/nvidia/version", GLib.FileTest.EXISTS) ||
                              GLib.FileUtils.test("/usr/bin/nvidia-smi", GLib.FileTest.EXISTS);

            var argv_list = new Gee.ArrayList<string>();
            argv_list.add("distrobox"); argv_list.add("create");
            argv_list.add("-n"); argv_list.add(name);
            argv_list.add("-i"); argv_list.add(image);
            argv_list.add("--no-entry"); argv_list.add("--yes");
            if (has_nvidia) argv_list.add("--nvidia");

            var tp = p.type_params;
            if (tp != null) {
                if (tp.has_key("pull") && tp["pull"] == "true") argv_list.add("--pull");
                if (tp.has_key("root") && tp["root"] == "true") argv_list.add("--root");
                if (tp.has_key("home")) { argv_list.add("--home"); argv_list.add(tp["home"]); }
                if (tp.has_key("hostname")) { argv_list.add("--hostname"); argv_list.add(tp["hostname"]); }
                if (tp.has_key("platform")) { argv_list.add("--platform"); argv_list.add(tp["platform"]); }
                if (tp.has_key("init") && tp["init"] == "true") argv_list.add("--init");
                if (tp.has_key("additional_packages")) { argv_list.add("--additional-packages"); argv_list.add(tp["additional_packages"]); }
                if (tp.has_key("additional_flags")) { argv_list.add("--additional-flags"); argv_list.add(tp["additional_flags"]); }
                if (tp.has_key("pre_init_hooks")) { argv_list.add("--pre-init-hooks"); argv_list.add(tp["pre_init_hooks"]); }
                if (tp.has_key("init_hooks")) { argv_list.add("--init-hooks"); argv_list.add(tp["init_hooks"]); }
                if (tp.has_key("volumes")) {
                    foreach (string line in tp["volumes"].split("\n")) {
                        string v = line.strip();
                        if (v != "") { argv_list.add("--volume"); argv_list.add(v); }
                    }
                }
            }

            string[] argv = argv_list.to_array();
            if (debug) stderr.printf("[st-distrobox] create: %s\n", string.joinv(" ", argv));
            int status = 1; string? out_str = null; string? err_str = null;
            GLib.Process.spawn_sync(null, argv, null, GLib.SpawnFlags.SEARCH_PATH, null, out out_str, out err_str, out status);
            if (debug) {
                stderr.printf("[st-distrobox] create status=%d\n", status);
                if (out_str != null && out_str.strip() != "") stderr.printf("[stdout] %s\n", out_str);
                if (err_str != null && err_str.strip() != "") stderr.printf("[stderr] %s\n", err_str);
            }
            return status == 0;
        } catch (Error e) { return false; }
    }

    public static int main(string[] args) {
        string? profile_file = null; string? profile_id = null;
        bool debug = GLib.Environment.get_variable("ST_DISTROBOX_DEBUG") != null;
        for (int i = 1; i < args.length; i++) {
            if (args[i] == "--profile-file" && i + 1 < args.length) profile_file = args[++i];
            else if (args[i] == "--profile-id" && i + 1 < args.length) profile_id = args[++i];
            else if (args[i] == "--debug") debug = true;
        }

        Profile? p = null;
        if (profile_file != null) p = Profile.from_file(profile_file);
        else if (profile_id != null) p = load_profile_by_id(profile_id);

        if (p == null) { stderr.printf("st-distrobox: unable to load profile\n"); return 1; }
        if (p.type.ascii_down() != "distrobox") { stderr.printf("st-distrobox: not a distrobox profile\n"); return 1; }

        string name = (p.type_params != null && p.type_params.has_key("name") && p.type_params["name"].strip() != "") ? p.type_params["name"].strip() : ("stillterminal-" + p.id);
        string image = (p.type_params != null && p.type_params.has_key("image") && p.type_params["image"].strip() != "") ? p.type_params["image"].strip() : "docker.io/library/ubuntu:latest";
        if (debug) stderr.printf("[st-distrobox] profile id=%s name=%s image=%s\n", p.id, name, image);

        if (!container_exists(name, debug)) {
            if (!create_container(p, name, image, debug)) {
                stderr.printf("st-distrobox: failed to create container '%s'\n", name);
                return 1;
            }
        }

        var argv_list = new Gee.ArrayList<string>();
        argv_list.add("distrobox"); argv_list.add("enter"); argv_list.add("-n"); argv_list.add(name);
        if (p.spawn_command != null && p.spawn_command.strip() != "") {
            argv_list.add("--");
            foreach (var tok in p.spawn_command.strip().split(" ")) { if (tok.strip() != "") argv_list.add(tok); }
        }
        if (debug) stderr.printf("[st-distrobox] enter: %s\n", string.joinv(" ", argv_list.to_array()));

        // In debug mode, run synchronously to capture output; otherwise exec-replace
        if (debug) {
            try {
                string? out_str = null; string? err_str = null; int status = 1;
                GLib.Process.spawn_sync(null, argv_list.to_array(), null, GLib.SpawnFlags.SEARCH_PATH, null, out out_str, out err_str, out status);
                stderr.printf("[st-distrobox] enter status=%d\n", status);
                if (out_str != null && out_str.strip() != "") stderr.printf("[stdout] %s\n", out_str);
                if (err_str != null && err_str.strip() != "") stderr.printf("[stderr] %s\n", err_str);
                return status;
            } catch (Error e) {
                stderr.printf("st-distrobox: enter failed: %s\n", e.message);
                return 127;
            }
        } else {
            // Exec replace this process so VTE tracks the container directly
            string[] exec_argv = new string[argv_list.size + 1];
            for (int i = 0; i < argv_list.size; i++) exec_argv[i] = argv_list.get(i);
            exec_argv[argv_list.size] = null;
            try {
                Posix.execvp(exec_argv[0], exec_argv);
            } catch (Error e) {
                stderr.printf("st-distrobox: exec failed: %s\n", e.message);
                return 127;
            }
            return 0;
        }
    }
}



