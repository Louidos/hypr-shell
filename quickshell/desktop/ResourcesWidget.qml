import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"

// Drei runde Glas-Kacheln am linken Rand: CPU, RAM, Datenträger – je ein Ring mit Prozentzahl.
// Fragt nur alle 2 s /proc ab, den Datenträger alle 30 s.
PanelWindow {
    id: w
    readonly property real k: (screen ? screen.height : 1080) / 1080 * Settings.get("desktop.resources.scale", 1.0)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "hypr-shell-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; left: true }
    margins {
        left: Math.round(Settings.get("desktop.resources.x", 0.015) * (screen ? screen.width : 1920))
        top: Math.round(Settings.get("desktop.resources.y", 0.56) * (screen ? screen.height : 1080))
    }
    implicitWidth: Math.ceil(col.implicitWidth)
    implicitHeight: Math.ceil(col.implicitHeight)
    mask: Region { }

    Usage { id: usage; running: w.visible }

    Column {
        id: col
        spacing: 10 * w.k
        Repeater {
            model: [
                { label: "CPU", icon: "", value: () => usage.cpu },
                { label: "RAM", icon: "", value: () => usage.mem },
                { label: "Disk", icon: "", value: () => usage.disk }
            ]
            delegate: GlassPanel {
                id: tile
                required property var modelData
                readonly property real v: modelData.value()
                width: 158 * w.k
                height: 116 * w.k
                radius: Theme.cardRadius * w.k
                Ring {
                    id: ring
                    width: 44 * w.k
                    height: width
                    thickness: 4 * w.k
                    value: tile.v
                    anchors { top: parent.top; right: parent.right; margins: 14 * w.k }
                }
                Glyph {
                    anchors.centerIn: ring
                    text: tile.modelData.icon
                    size: 15 * w.k
                    color: Theme.subtext
                }
                Column {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 16 * w.k }
                    spacing: 0
                    Txt {
                        text: Math.round(tile.v) + "%"
                        size: 26 * w.k
                        weight: Font.Bold
                    }
                    Txt {
                        text: tile.modelData.label
                        size: 11 * w.k
                        sub: true
                    }
                }
            }
        }
    }
}
