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
import "clipboard"
import "overview"
import "cheatsheet"
import "missa"
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
    Notifications { }
    Osd { }
    PowerMenu { }
    Clipboard { }
    Overview { }
    Cheatsheet { }
    // Missa nur, wenn missa.enabled an ist (sonst kein Panel, kein IPC-Ziel, keine Netzanfrage)
    LazyLoader { active: Integrations.missa; MissaChat { } }
    LazyLoader { active: Integrations.missaAgent; MissaAgent { } }
}
