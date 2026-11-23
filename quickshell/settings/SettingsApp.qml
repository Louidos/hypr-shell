import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Einstellungs-App: schwebendes Glas-Fenster in der Bildschirmmitte (etwa 1100 × 700, Blur dahinter
// über die Hyprland-Regel für "hypr-shell-settings"; gemeinsamer Baustein Overlay). Öffnen mit SUPER+U,
// über das Zahnrad im Panel oder "shell-quickshell ipc settings open <seite>"; Esc schliesst.
Scope {
    id: app
    readonly property var screen: Settings.screenFor(Settings.get("desktop.screen", ""))

    IpcHandler {
        target: "settings"
        function open(page: string): void { Ui.openSettings(page) }
        function toggle(): void { Ui.toggleSettings("") }
        function close(): void { Ui.closeSettings() }
        function search(text: string): void { Ui.openSettings(""); Ui.settingsSearch = text }
    }

    Overlay {
        name: "settings"
        ipc: false
        place: "center"
        glass: false
        margin: 0
        screen: app.screen
        panelWidth: Math.min(1100, (app.screen ? app.screen.width : 1920) - 40)
        panelHeight: Math.min(700, (app.screen ? app.screen.height : 1080) - 60)
        keyboardFocus: WlrKeyboardFocus.Exclusive
        // Esc behandelt die App selbst (erst die Suche leeren, dann schliessen)
        closeOnEscape: false
        content: Component { SettingsContent { } }
    }
}
