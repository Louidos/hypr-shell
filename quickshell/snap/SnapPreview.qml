import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Vorschau beim Andocken: eine Glasfläche zeigt, wo das gezogene Fenster beim Loslassen landet.
// shell-snap (während des Ziehens) ruft "ipc snap show <bildschirm> x y b h" (logische Pixel im
// Gesamtbild) bzw. "ipc snap hide". Nimmt weder Klicks noch die Tastatur an.
Scope {
    id: sp
    property string screenName: ""
    property rect target: Qt.rect(0, 0, 0, 0)
    property bool shown: false
    readonly property bool animate: Settings.get("andocken.animation", true) === true && !Ui.gaming

    IpcHandler {
        target: "snap"
        function show(screen: string, x: int, y: int, w: int, h: int): void {
            sp.screenName = screen
            sp.target = Qt.rect(x, y, w, h)
            sp.shown = true
        }
        function hide(): void { sp.shown = false }
        function state(): string { return sp.shown ? sp.screenName + " " + sp.target.x + " " + sp.target.y + " " + sp.target.width + " " + sp.target.height : "hidden" }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property bool here: sp.shown && modelData.name === sp.screenName
            visible: here || area.opacity > 0.01
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hypr-shell-snap"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region { }   // keine Klicks
            Rectangle {
                id: area
                x: sp.target.x - win.modelData.x
                y: sp.target.y - win.modelData.y
                width: sp.target.width
                height: sp.target.height
                radius: Settings.get("look.rounding", 14)
                color: Theme.glass(0.35)
                border.width: Math.max(1, Theme.borderWidth)
                border.color: Theme.glassBorder
                opacity: win.here ? 1 : 0
                scale: win.here ? 1 : 0.96
                Behavior on opacity { enabled: sp.animate; NumberAnimation { duration: 140 } }
                Behavior on scale { enabled: sp.animate; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on x { enabled: sp.animate && win.here; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: sp.animate && win.here; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on width { enabled: sp.animate && win.here; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: sp.animate && win.here; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Probe { name: "snap-preview" }
            }
        }
    }
}
