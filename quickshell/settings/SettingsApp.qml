import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Einstellungs-App: schwebendes Glas-Fenster in der Bildschirmmitte (etwa 1100 × 700, Blur dahinter
// über die Hyprland-Regel für "hypr-shell-settings"). Öffnen mit SUPER+U, über das Zahnrad im
// Panel oder "shell-quickshell ipc settings open <seite>"; Esc schliesst.
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

    PanelWindow {
        id: win
        property real t: Ui.settingsOpen ? 1 : 0
        Behavior on t { NumberAnimation { duration: Ui.settingsOpen ? 320 : 180; easing.type: Easing.OutCubic } }

        screen: app.screen
        visible: app.screen !== null && (Ui.settingsOpen || t > 0.001)
        implicitWidth: Math.min(1100, (app.screen ? app.screen.width : 1920) - 40)
        implicitHeight: Math.min(700, (app.screen ? app.screen.height : 1080) - 60)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hypr-shell-settings"
        WlrLayershell.keyboardFocus: Ui.settingsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Loader {
            id: content
            anchors.fill: parent
            active: Ui.settingsOpen || win.t > 0.001
            opacity: win.t
            scale: 0.97 + 0.03 * win.t
            focus: true
            sourceComponent: SettingsContent { }
            onLoaded: item.forceActiveFocus()
        }
    }
}
