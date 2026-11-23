import Quickshell
import QtQuick
import "desktop"
import "dashboard"
import "panel"
import "settings"
import "launcher"
import "notifications"
import "osd"
import "power"

// hypr-shell: Quickshell-Oberfläche (gestartet von ~/.local/bin/shell-quickshell, das das
// Symbolthema aus settings.json – theme.icons – über QS_ICON_THEME setzt)
ShellRoot {
    Desktop { }
    Dashboard { }
    HotCorner { }
    SettingsApp { }
    Launcher { }
    Notifications { }
    Osd { }
    PowerMenu { }
}
