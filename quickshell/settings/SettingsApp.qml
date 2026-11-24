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
        id: ov
        name: "settings"
        ipc: false
        place: "center"
        glass: false
        margin: 0
        screen: app.screen
        // Entwurf 1100 × 700 (im Hochformat höher); Overlay begrenzt auf den Bildschirm, die Seiten
        // rollen selbst. Schmal oder hochkant: Seiten oben statt links (compact)
        panelWidth: 1100
        panelHeight: ov.portrait ? 1100 : 700
        scroll: false
        keyboardFocus: WlrKeyboardFocus.Exclusive
        // Esc behandelt die App selbst (erst die Suche leeren, dann schliessen)
        closeOnEscape: false
        content: Component { SettingsContent { compact: ov.portrait || ov.fitWidth < 860 } }
    }
}
