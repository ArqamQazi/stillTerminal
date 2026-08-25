public class StillTerminal.App : Adw.Application {
    // Member variables

    // Constructor
    public App () {
        Object (application_id: "io.stillhq.terminal",
                flags : GLib.ApplicationFlags.HANDLES_COMMAND_LINE
                );
        // Ensure libadwaita automatically loads style resources (style.css, etc.)
        this.set_resource_base_path ("/io/stillhq/terminal");

        // Register command-line options
        this.add_main_option (
            "working-directory", 'w',
            GLib.OptionFlags.NONE, GLib.OptionArg.STRING,
            _ ("Set the initial working directory"), _ ("DIR")
            );
        this.add_main_option (
            "command", '\0',
            GLib.OptionFlags.NONE, GLib.OptionArg.STRING,
            _ ("Execute a command string"), _ ("COMMAND")
            );
        this.add_main_option (
            "title", 't',
            GLib.OptionFlags.NONE, GLib.OptionArg.STRING,
            _ ("Set the initial terminal title"), _ ("TITLE")
            );
        this.add_main_option (
            "zoom", '\0',
            GLib.OptionFlags.NONE, GLib.OptionArg.DOUBLE,
            _ ("Set the terminal zoom factor"), _ ("FACTOR")
            );
        this.add_main_option (
            "fullscreen", '\0',
            GLib.OptionFlags.NONE, GLib.OptionArg.NONE,
            _ ("Open the window fullscreen"), null
            );
    }

    protected override void startup () {
        base.startup ();

        // Ensure our bundled icons are available by name (one-time setup)
        var display = Gdk.Display.get_default ();
        if (display != null) {
            var icon_theme = Gtk.IconTheme.get_for_display (display);
            icon_theme.add_resource_path ("/io/stillhq/terminal/icons");
            icon_theme.add_resource_path ("/io/stillhq/terminal/icons/symbolic");
            icon_theme.add_resource_path ("/io/stillhq/terminal/icons/symbolic/scalable/apps");
            icon_theme.add_resource_path ("/io/stillhq/terminal/icons/symbolic/scalable/actions");
        }
    }

    protected override void activate () {
        var win = new MainWindow (this);
        win.present ();
    }

    protected override int command_line (GLib.ApplicationCommandLine cmdline) {
        var options = cmdline.get_options_dict ();
        string? requested_working_dir = null;
        string? legacy_command = null;
        string? title = null;
        double zoom = 1.0;
        bool start_fullscreen = options.contains ("fullscreen");

        if (options.contains ("working-directory")) {
            requested_working_dir = options.lookup_value (
                "working-directory", GLib.VariantType.STRING
                ).get_string ();
        }

        if (options.contains ("command")) {
            legacy_command = options.lookup_value (
                "command", GLib.VariantType.STRING
                ).get_string ();
        }

        if (options.contains ("title")) {
            title = options.lookup_value (
                "title", GLib.VariantType.STRING
                ).get_string ();
        }

        if (options.contains ("zoom")) {
            zoom = options.lookup_value (
                "zoom", GLib.VariantType.DOUBLE
                ).get_double ();
            if (zoom <= 0.0) {
                cmdline.printerr (_ ("Zoom factor must be greater than zero.\n"));
                return 2;
            }
        }

        string[]? command;
        try {
            command = LaunchRequest.parse_command (
                legacy_command, cmdline.get_arguments ()
            );
        } catch (Error e) {
            cmdline.printerr (_ ("Failed to parse command line: %s\n").printf (e.message));
            return 2;
        }

        string? working_dir = LaunchRequest.resolve_working_directory (
            requested_working_dir, cmdline.get_cwd ()
        );
        var win = new MainWindow (
            this, true, working_dir, command, title, zoom, start_fullscreen
        );
        win.present ();

        return 0;
    }

    // No custom file-open handling required currently
}

int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.bindtextdomain (StillTerminal.GETTEXT_PACKAGE, StillTerminal.LOCALEDIR);
    Intl.bind_textdomain_codeset (StillTerminal.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (StillTerminal.GETTEXT_PACKAGE);

    var my_app = new StillTerminal.App ();
    return my_app.run (args);
}
