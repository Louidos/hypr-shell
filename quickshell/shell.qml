import Quickshell
import QtQuick
import "desktop"
import "dashboard"
import "panel"
import "settings"
import "launcher"
import "apps"
import "notifications"
import "osd"
import "power"
import "clipboard"
import "overview"
import "cheatsheet"
import "missa"
import "dock"
import "switcher"
import "snap"
import "common"

// hypr-shell: Quickshell-Oberfläche (gestartet von ~/.local/bin/shell-quickshell, das das
// Symbolthema aus settings.json – theme.icons – über QS_ICON_THEME setzt)
ShellRoot {
    Desktop { }
    Dashboard { }
    HotCorner { }
    NightLight { }
    SettingsApp { }
    Launcher { }
    AppGrid { }
    Notifications { }
    Osd { }
    PowerMenu { }
    Clipboard { }
    Overview { }
    Switcher { }
    SnapPreview { }
    Cheatsheet { }
    // Missa nur, wenn missa.enabled an ist (sonst kein Panel, kein IPC-Ziel, keine Netzanfrage)
    LazyLoader { active: Integrations.missa; MissaChat { } }
    LazyLoader { active: Integrations.missaAgent; MissaAgent { } }
    // Dock: aus (dock.enabled = false) heisst kein Fenster und keine Abfrage
    LazyLoader { active: Settings.get("dock.enabled", true) === true; Dock { } }
}
