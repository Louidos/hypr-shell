import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"

// Grosse gestapelte Uhr (Stunden über Minuten) in JetBrainsMono Nerd Font (theme.font.clock), fett, 150 px bei
// 1080 Bildschirmzeilen; Stunden 85 % deckend, Minuten 45 % (wie die Vorlage).
// Position als Anteil der Bildschirmgrösse aus settings.json (desktop.clock.x / .y).
PanelWindow {
    id: w
    readonly property real k: (screen ? screen.height : 1080) / 1080 * Ui.widget("clock", "scale", 1.0)
    readonly property real size: 150 * k
    readonly property bool h12: Settings.get("desktop.clock.format", "24h") === "12h"
    function hours(d) {
        const h = h12 ? (d.getHours() % 12 || 12) : d.getHours()
        return (h < 10 ? "0" : "") + h
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "hypr-shell-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; left: true }
    margins {
        left: Math.round(Ui.widget("clock", "x", 0.02) * (screen ? screen.width : 1920))
        top: Math.round(Ui.widget("clock", "y", 0.045) * (screen ? screen.height : 1080))
    }
    implicitWidth: Math.ceil(stack.implicitWidth) + 4
    implicitHeight: Math.ceil(stack.implicitHeight)
    mask: Region { }   // nimmt keine Klicks an

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        id: stack
        spacing: -42 * w.k
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.hours(clock.date)
            Probe { name: "desktop-clock" }
            font.family: Theme.clock
            font.pixelSize: w.size
            font.bold: true
            color: "#F6F5F4"
            opacity: 0.85
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "mm")
            font.family: Theme.clock
            font.pixelSize: w.size
            font.bold: true
            color: "#F6F5F4"
            opacity: 0.45
        }
    }
}
