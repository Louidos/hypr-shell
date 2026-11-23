import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Anzeige für Lautstärke, Stumm, Mikrofon, Bildschirm- und Tastaturhelligkeit: kleine Glas-Pille
// unten in der Mitte, erscheint von selbst (shell-osd ruft "ipc osd display" auf) und verschwindet nach
// 1,5 Sekunden. Nimmt keine Klicks an und ist kein Panel (schliesst also kein offenes Panel).
Scope {
    id: osd
    property string kind: "volume"
    property int value: 0
    property bool muted: false
    readonly property bool enabled: Settings.get("osd.enabled", true)

    function show(k, v, m) {
        if (!enabled) return
        kind = k
        value = Math.max(0, Math.min(100, v))
        muted = m
        ov.localOpen = true
        hideTimer.restart()
    }
    readonly property string icon: {
        if (kind === "mic") return muted ? "󰍭" : "󰍬"
        if (kind === "brightness") return value < 34 ? "󰃞" : value < 67 ? "󰃟" : "󰃠"
        if (kind === "kbd") return value === 0 ? "󰌌" : "󰥻"
        if (muted || value === 0) return "󰝟"
        return value < 34 ? "󰕿" : value < 67 ? "󰖀" : "󰕾"
    }

    Timer { id: hideTimer; interval: 1500; onTriggered: ov.localOpen = false }

    IpcHandler {
        target: "osd"
        function display(kind: string, value: int, muted: bool): void { osd.show(kind, value, muted) }
        // was gerade angezeigt wird ("" wenn nichts) – für Tests
        function current(): string { return ov.open ? osd.kind + " " + osd.value + (osd.muted ? " muted" : "") : "" }
    }

    Overlay {
        id: ov
        name: "osd"
        exclusive: false
        ipc: false
        place: "bottom"
        margin: 72
        panelWidth: 320
        panelHeight: 56
        radius: 28
        keyboardFocus: WlrKeyboardFocus.None
        layer: WlrLayer.Overlay
        closeOnOutside: false
        closeOnEscape: false
        clickThrough: true
        lazy: false

        content: Component {
            Item {
                Glyph {
                    id: ico
                    anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                    text: osd.icon
                    size: 20
                    color: osd.muted ? Theme.subtext : Theme.text
                }
                Rectangle {
                    id: track
                    anchors { left: ico.right; leftMargin: 16; right: pct.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    height: 6
                    radius: 3
                    color: Theme.track
                    Rectangle {
                        width: parent.width * osd.value / 100
                        height: parent.height
                        radius: 3
                        color: osd.muted ? Theme.subtext : Theme.pill
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }
                Txt {
                    id: pct
                    anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: osd.muted ? "off" : osd.value + "%"
                    size: 13
                    weight: Font.DemiBold
                    font.family: Theme.mono
                }
            }
        }
    }
}
