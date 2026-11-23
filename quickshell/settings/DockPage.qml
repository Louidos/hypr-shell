import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Kopf der Seite Dock: Voreinstellungen (ändern nur dock.*-Werte, nie die Einträge), Export und
// Import der Dock-Werte als JSON-Datei (alles oder nichts) und "Reset all". Die einzelnen Werte
// stehen darunter in ihren Abschnitten; jede Änderung wirkt sofort am echten Dock, das sichtbar
// bleibt, solange diese Seite offen ist.
Column {
    id: dp
    spacing: 12
    property var presets: []
    property string message: ""
    property string file: Settings.home + "/hypr-shell-dock.json"
    property bool resetArmed: false

    function run(args) {
        message = ""
        act.command = [Settings.bin + "shell-dock"].concat(args)
        act.running = true
    }
    Component.onCompleted: list.running = true

    Process {
        id: list
        command: [Settings.bin + "shell-dock", "presets"]
        stdout: StdioCollector { onStreamFinished: { try { dp.presets = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: act
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") dp.message = text.trim().split("\n").slice(-1)[0] }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") dp.message = text.trim().split("\n").slice(-1)[0] }
        onExited: code => { if (code === 0 && dp.message === "") dp.message = "Done" }
    }
    Timer { id: disarm; interval: 4000; onTriggered: dp.resetArmed = false }

    // ---- Voreinstellungen
    GlassCard {
        width: parent.width
        height: presetCol.implicitHeight + 28
        Column {
            id: presetCol
            x: 18; y: 14
            width: parent.width - 36
            spacing: 10
            Txt { text: "Presets"; size: 14; weight: Font.DemiBold }
            Txt { width: parent.width; text: "Change only the dock values – your items stay as they are."; size: 12; sub: true; wrapMode: Text.Wrap }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: dp.presets
                    delegate: Pill {
                        required property var modelData
                        text: modelData.name
                        active: Settings.get("dock.preset", "mac") === modelData.name
                        onClicked: dp.run(["preset", modelData.name])
                        Probe { name: "dock-preset-" + modelData.name }
                    }
                }
            }
            Txt {
                width: parent.width
                text: (dp.presets.find(p => p.name === Settings.get("dock.preset", "mac")) || {}).description || ""
                size: 12
                sub: true
                wrapMode: Text.Wrap
            }
        }
    }

    // ---- Export, Import, Reset all
    GlassCard {
        width: parent.width
        height: fileCol.implicitHeight + 28
        Column {
            id: fileCol
            x: 18; y: 14
            width: parent.width - 36
            spacing: 10
            Txt { text: "Export and import"; size: 14; weight: Font.DemiBold }
            Field {
                width: parent.width
                mono: true
                text: dp.file
                onAccepted: t => dp.file = t.trim()
            }
            Row {
                spacing: 6
                Pill { text: "Export"; icon: "󰈝"; onClicked: dp.run(["export", dp.file]); Probe { name: "dock-export" } }
                Pill { text: "Import"; icon: "󰈞"; onClicked: dp.run(["import", dp.file]); Probe { name: "dock-import" } }
                Pill {
                    text: dp.resetArmed ? "Click again to reset" : "Reset all"
                    icon: "󰑓"
                    active: dp.resetArmed
                    onClicked: {
                        if (!dp.resetArmed) { dp.resetArmed = true; disarm.restart(); return }
                        dp.resetArmed = false
                        dp.run(["reset"])
                    }
                    Probe { name: "dock-reset" }
                }
            }
            Txt {
                visible: dp.message !== ""
                width: parent.width
                text: dp.message
                size: 12
                sub: true
                wrapMode: Text.Wrap
            }
        }
    }
}
