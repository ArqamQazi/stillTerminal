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
        string? working_dir = null;

        if (options.contains ("working-directory")) {
            working_dir = options.lookup_value (
                "working-directory", GLib.VariantType.STRING
                ).get_string ();
        }

        if (working_dir != null && working_dir.strip () != "") {
            var win = new MainWindow (this, true, working_dir);
            win.present ();
        } else {
            this.activate ();
        }

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
