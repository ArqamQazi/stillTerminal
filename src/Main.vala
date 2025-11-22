public class StillTerminal.App : Adw.Application {
    // Member variables

    // Constructor
    public App () {
        Object (application_id: "io.stillhq.terminal",
                flags : GLib.ApplicationFlags.DEFAULT_FLAGS
                );
        // Ensure libadwaita automatically loads style resources (style.css, etc.)
        this.set_resource_base_path ("/io/stillhq/terminal");
    }

    protected override void activate () {
        // Ensure our bundled icons are available by name
        var display = Gdk.Display.get_default ();
        if (display != null) {
            var icon_theme = Gtk.IconTheme.get_for_display (display);
            icon_theme.add_resource_path ("/io/stillhq/terminal/icons");
            icon_theme.add_resource_path ("/io/stillhq/terminal/icons/symbolic");
            icon_theme.add_resource_path ("/io/stillhq/terminal/icons/symbolic/scalable/apps");
            icon_theme.add_resource_path ("/io/stillhq/terminal/icons/symbolic/scalable/actions");
        }

        var win = new MainWindow (this);
        win.present ();
    }

    // No custom file-open handling required currently
}

int main (string[] args) {
    var my_app = new StillTerminal.App ();
    return my_app.run (args);
}
