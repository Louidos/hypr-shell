import Quickshell
import QtQuick
import "desktop"
import "dashboard"
import "panel"

// hypr-shell: Quickshell-Oberfläche (gestartet von ~/.local/bin/shell-quickshell, das das
// Symbolthema aus settings.json – theme.icons – über QS_ICON_THEME setzt)
ShellRoot {
    Desktop { }
    Dashboard { }
    HotCorner { }
}
