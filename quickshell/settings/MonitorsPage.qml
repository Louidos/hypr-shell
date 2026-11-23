import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "monitore.js" as M

// Seite Monitors: die echten Bildschirme aus Hyprland (hyprctl monitors -j, nur solange die Seite
// offen ist). Eine neue Auflösung, Skalierung oder Position wird sofort gesetzt und muss innerhalb
// von 15 Sekunden bestätigt werden, sonst gilt wieder der vorherige Stand.
Column {
    id: mp
    spacing: 12
    property var monitors: []
    property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    // Bestätigung
    property var previous: null
    property int countdown: 0
    readonly property var outputs: Settings.get("monitors.outputs", [])

    function load() {
        if (hyprland) { if (!proc.running) proc.running = true; return }
        // ohne Hyprland (z. B. im Test): die Bildschirme, die Quickshell kennt
        monitors = Quickshell.screens.map(s => ({
            name: s.name, description: s.model || "", width: s.width, height: s.height,
            refreshRate: 0, scale: 1, x: s.x, y: s.y, availableModes: []
        }))
    }
    Component.onCompleted: load()
    Process {
        id: proc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { mp.monitors = JSON.parse(text) } catch (e) { mp.monitors = [] } } }
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: mp.load() }

    function entry(name) {
        for (let i = 0; i < outputs.length; i++) if (outputs[i].name === name) return outputs[i]
        return { name: name, resolution: "", refresh: 0, scale: "", position: "" }
    }
    // Eintrag für einen Bildschirm ändern; mit Rückfrage nach 15 Sekunden
    function change(name, patch) {
        const list = outputs.map(o => Object.assign({}, o))
        let e = list.find(o => o.name === name)
        if (!e) { e = entry(name); list.push(e) }
        Object.assign(e, patch)
        if (previous === null) previous = outputs
        countdown = 15
        Ui.set("monitors.outputs", list, false)
    }
    function keep() { previous = null; countdown = 0 }
    function revert() {
        if (previous !== null) Ui.set("monitors.outputs", previous, false)
        previous = null; countdown = 0
    }
    Timer {
        interval: 1000; repeat: true; running: mp.countdown > 0
        onTriggered: { mp.countdown--; if (mp.countdown <= 0) mp.revert() }
    }
    // Auflösungen zum Wählen (die grössten sechs, dazu immer die laufende und die eingestellte)
    function modes(m) { return M.modes(m, entry(m.name).resolution, 6) }

    // ---- Bestätigung
    GlassCard {
        visible: mp.countdown > 0
        width: parent.width
        height: 64
        color: Qt.rgba(1, 1, 1, 0.12)
        Txt {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            text: "Keep this display setting? Reverting in " + mp.countdown + " s"
            size: 14; weight: Font.DemiBold
        }
        Row {
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8
            Pill { icon: "󰄬"; text: "Keep"; active: true; onClicked: mp.keep() }
            Pill { icon: "󰑓"; text: "Revert"; onClicked: mp.revert() }
        }
    }

    Txt {
        visible: !mp.hyprland
        width: parent.width
        text: "No Hyprland session: showing the screens Quickshell knows. Modes appear inside Hyprland."
        sub: true; size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone
    }

    Repeater {
        model: mp.monitors
        delegate: GlassCard {
            id: card
            required property var modelData
            readonly property var e: mp.entry(modelData.name)
            width: mp.width
            height: mcol.implicitHeight + 28
            Column {
                id: mcol
                x: 16; y: 14
                width: parent.width - 32
                spacing: 10
                Row {
                    spacing: 12
                    Glyph { text: "󰍹"; size: 22; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        Txt { text: card.modelData.name + (card.modelData.description ? " · " + card.modelData.description : ""); size: 14; weight: Font.Bold }
                        Txt {
                            text: card.modelData.width + "x" + card.modelData.height
                                  + (card.modelData.refreshRate ? " @ " + Math.round(card.modelData.refreshRate) + " Hz" : "")
                                  + " · scale " + card.modelData.scale + " · at " + card.modelData.x + "x" + card.modelData.y
                            sub: true; size: 12
                        }
                    }
                }
                Txt { text: "Resolution"; size: 12; weight: Font.DemiBold; color: Theme.subtext }
                Flow {
                    width: parent.width
                    spacing: 6
                    Pill {
                        text: "Automatic"
                        active: card.e.resolution === ""
                        onClicked: mp.change(card.modelData.name, { resolution: "", refresh: 0 })
                    }
                    Repeater {
                        model: mp.modes(card.modelData)
                        delegate: Pill {
                            required property var modelData
                            text: M.label(modelData)
                            active: card.e.resolution === modelData.res
                            onClicked: mp.change(card.modelData.name, { resolution: modelData.res, refresh: modelData.hz })
                        }
                    }
                }
                Txt { text: "Scale"; size: 12; weight: Font.DemiBold; color: Theme.subtext }
                Row {
                    spacing: 6
                    Repeater {
                        model: ["", "1", "1.25", "1.5", "1.75", "2"]
                        delegate: Pill {
                            required property string modelData
                            text: modelData === "" ? "Like all screens" : modelData
                            active: String(card.e.scale) === modelData
                            onClicked: mp.change(card.modelData.name, { scale: modelData })
                        }
                    }
                }
                Row {
                    spacing: 8
                    Txt { text: "Position"; size: 12; weight: Font.DemiBold; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                    Field {
                        width: 160
                        mono: true
                        text: card.e.position
                        placeholder: "automatic, e.g. 1920x0"
                        onAccepted: t => mp.change(card.modelData.name, { position: t.trim() })
                    }
                }
            }
        }
    }
}
