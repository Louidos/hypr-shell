import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Oben auf den Seiten Look und Theme: Voreinstellungen (glass, minimal, gaming) und eine Live-Vorschau
// mit den aktuellen Werten – eine Glasfläche der Shell und ein aktives und ein inaktives Fenster mit
// Rand, Rundung und Transparenz. Jede Änderung unten wirkt sofort auch hier.
Column {
    id: lp
    spacing: 12
    property var presets: []
    Process {
        running: true
        command: [Settings.bin + "shell-look", "presets"]
        stdout: StdioCollector { onStreamFinished: { try { lp.presets = JSON.parse(text) } catch (e) { } } }
    }
    readonly property real rounding: Settings.get("look.rounding", 14)
    readonly property bool white: Settings.get("look.border_color", "white") === "white"
    readonly property color borderActive: white ? Qt.rgba(Qt.color(Theme.borderBase).r, Qt.color(Theme.borderBase).g, Qt.color(Theme.borderBase).b, Settings.get("theme.border.opacity", 0.35)) : Theme.accent
    readonly property color borderInactive: white ? Qt.rgba(Qt.color(Theme.borderBase).r, Qt.color(Theme.borderBase).g, Qt.color(Theme.borderBase).b, Settings.get("theme.border.opacity_inactive", 0.15)) : Theme.c.outline
    readonly property int windowBorder: Settings.get("look.border", 1)

    GlassCard {
        width: lp.width
        height: presetRow.implicitHeight + 28
        Column {
            id: presetRow
            x: 16; y: 14
            width: parent.width - 32
            spacing: 8
            Txt { text: "Look preset"; size: 14; weight: Font.DemiBold }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: lp.presets
                    delegate: Pill {
                        required property var modelData
                        text: modelData.name
                        active: Settings.get("look.preset", "glass") === modelData.name
                        onClicked: lookProc.start(modelData.name)
                        Probe { name: "look-preset-" + modelData.name }
                    }
                }
            }
            Txt {
                width: parent.width
                text: (lp.presets.find(p => p.name === Settings.get("look.preset", "glass")) || {}).description || ""
                sub: true; size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone
            }
        }
    }
    Process {
        id: lookProc
        function start(name) { command = [Settings.bin + "shell-look", "preset", name]; running = true }
    }

    // ---- Live-Vorschau: Hintergrund wie ein Hintergrundbild, darauf Glas und zwei Fenster
    Rectangle {
        width: lp.width
        height: 150
        radius: Theme.cardRadius
        clip: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.mix(Theme.accent, "#101014", 0.35) }
            GradientStop { position: 1; color: Theme.mix(Theme.c.surface, "#e8e8ec", 0.25) }
        }
        // Glasfläche der Shell (Panel)
        Rectangle {
            x: 16; y: 16
            width: Math.min(220, parent.width * 0.32); height: parent.height - 32
            radius: Theme.panelRadius
            color: Theme.glass()
            border.width: Theme.borderWidth
            border.color: Theme.glassBorder
            Txt { anchors.centerIn: parent; text: "Glass"; size: 13; weight: Font.DemiBold }
            Probe { name: "look-preview-glass" }
        }
        // inaktives und aktives Fenster
        Repeater {
            model: [{ active: false, dx: 0.45, dy: 26 }, { active: true, dx: 0.62, dy: 44 }]
            delegate: Rectangle {
                required property var modelData
                x: parent.width * modelData.dx; y: modelData.dy
                width: parent.width * 0.32; height: parent.height - modelData.dy - 14
                radius: lp.rounding
                color: Qt.rgba(0.11, 0.11, 0.13, modelData.active ? Settings.get("look.opacity.active", 0.95) : Settings.get("look.opacity.inactive", 0.88))
                border.width: lp.windowBorder
                border.color: modelData.active ? lp.borderActive : lp.borderInactive
                Txt { x: 12; y: 10; text: modelData.active ? "Active window" : "Inactive window"; size: 12; sub: !modelData.active }
            }
        }
    }
}
