import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"

// Grosse gestapelte Uhr (Stunden über Minuten), weiss und leicht durchscheinend.
// Position als Anteil der Bildschirmgrösse aus settings.json (desktop.clock.x / .y).
PanelWindow {
    id: w
    readonly property real k: (screen ? screen.height : 1080) / 1080 * Settings.get("desktop.clock.scale", 1.0)
    readonly property real size: 168 * k

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "hypr-shell-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; left: true }
    margins {
        left: Math.round(Settings.get("desktop.clock.x", 0.02) * (screen ? screen.width : 1920))
        top: Math.round(Settings.get("desktop.clock.y", 0.045) * (screen ? screen.height : 1080))
    }
    implicitWidth: Math.ceil(stack.implicitWidth) + 4
    implicitHeight: Math.ceil(stack.implicitHeight)
    mask: Region { }   // nimmt keine Klicks an

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        id: stack
        spacing: -w.size * 0.16
        Text {
            text: Qt.formatTime(clock.date, "HH")
            font.family: Theme.display
            font.pixelSize: w.size
            color: Qt.rgba(1, 1, 1, 0.90)
        }
        Text {
            text: Qt.formatTime(clock.date, "mm")
            font.family: Theme.display
            font.pixelSize: w.size
            color: Qt.rgba(1, 1, 1, 0.50)
        }
    }
}
