import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "monitore.js" as M

// Seite Monitors: die echten Bildschirme aus Hyprland (hyprctl monitors -j, nur solange die Seite
// offen ist). Eine neue Auflösung, Skalierung, Position oder Drehung wird sofort gesetzt und muss
// innerhalb von 15 Sekunden bestätigt werden, sonst gilt wieder der vorherige Stand.
Column {
    id: mp
    spacing: Theme.pad(12)
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
            refreshRate: 0, scale: 1, x: s.x, y: s.y, availableModes: [], transform: 0
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
        return { name: name, resolution: "", refresh: 0, scale: "", position: "", transform: "normal" }
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
    // Drehung eines Bildschirms: eingestellt (alte Einträge ohne Wert: normal)
    function rotation(name) { return M.parts(entry(name).transform) }
    function rotate(name, grad, mirrored) { change(name, { transform: M.compose(grad, mirrored) }) }
    // nach dem Drehen: überlappen sich Bildschirme mit fest eingetragener Lage? (automatische Lage
    // ordnet Hyprland selbst neu)
    readonly property bool fixedPositions: outputs.some(o => o.position && o.position !== "" && o.position !== "auto")
    readonly property bool overlap: {
        const neu = {}
        for (const o of outputs) neu[o.name] = M.transformName(o.transform)
        return monitors.length > 1 && M.overlaps(monitors, neu)
    }
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
            anchors { left: parent.left; leftMargin: Theme.pad(18); verticalCenter: parent.verticalCenter }
            text: "Keep this display setting? Reverting in " + mp.countdown + " s"
            size: 14; strong: true
        }
        Row {
            anchors { right: parent.right; rightMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
            spacing: Theme.pad(8)
            Pill { icon: "󰄬"; text: "Keep"; active: true; onClicked: mp.keep(); Probe { name: "monitors-keep" } }
            Pill { icon: "󰑓"; text: "Revert"; onClicked: mp.revert(); Probe { name: "monitors-revert" } }
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
                spacing: Theme.pad(10)
                Row {
                    spacing: Theme.pad(12)
                    Glyph { text: "󰍹"; size: 22; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        Txt { text: card.modelData.name + (card.modelData.description ? " · " + card.modelData.description : ""); size: 14; title: true }
                        Txt {
                            text: card.modelData.width + "x" + card.modelData.height
                                  + (card.modelData.refreshRate ? " @ " + Math.round(card.modelData.refreshRate) + " Hz" : "")
                                  + " · scale " + card.modelData.scale + " · at " + card.modelData.x + "x" + card.modelData.y
                                  + " · rotation " + M.label2(card.modelData.transform)
                            sub: true; size: 12
                        }
                    }
                }
                Txt { text: "Resolution"; size: 12; strong: true; color: Theme.subtext }
                Flow {
                    width: parent.width
                    spacing: Theme.pad(6)
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
                Txt { text: "Scale"; size: 12; strong: true; color: Theme.subtext }
                Flow {
                    width: parent.width
                    spacing: Theme.pad(6)
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
                // ---- Drehung: 0°, 90°, 180°, 270° und gespiegelt, mit Vorschau der Ausrichtung
                Txt { text: "Rotation"; size: 12; strong: true; color: Theme.subtext }
                Row {
                    id: rotRow
                    spacing: Theme.pad(14)
                    readonly property var rot: mp.rotation(card.modelData.name)
                    // Vorschau-Kachel: der Bildschirm, wie er steht (A zeigt oben und die Spiegelung)
                    Item {
                        width: 52; height: 52
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            id: tile
                            anchors.centerIn: parent
                            width: 44; height: 28
                            radius: Theme.corner(5)
                            color: Theme.card
                            border.width: 1
                            border.color: Theme.glassBorder
                            // Wayland dreht gegen den Uhrzeigersinn
                            rotation: -rotRow.rot.grad
                            transform: Scale { origin.x: tile.width / 2; xScale: rotRow.rot.mirrored ? -1 : 1 }
                            Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            Rectangle { x: 6; y: 3; width: parent.width - 12; height: 3; radius: Theme.corner(1.5); color: Theme.accent }
                            Txt { anchors.centerIn: parent; anchors.verticalCenterOffset: 2; text: "A"; size: 12; heavy: true }
                        }
                    }
                    Flow {
                        width: card.width - 32 - 52 - 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.pad(6)
                        Repeater {
                            model: [0, 90, 180, 270]
                            delegate: Pill {
                                required property int modelData
                                text: modelData + "°"
                                active: rotRow.rot.grad === modelData
                                onClicked: mp.rotate(card.modelData.name, modelData, rotRow.rot.mirrored)
                                Probe { name: "monitor-rotate-" + card.modelData.name + "-" + modelData }
                            }
                        }
                        Item { width: 8; height: 30 }
                        Row {
                            spacing: Theme.pad(8)
                            height: 30
                            Txt { text: "Mirrored"; size: 12; anchors.verticalCenter: parent.verticalCenter }
                            Toggle {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: rotRow.rot.mirrored
                                onToggled: mp.rotate(card.modelData.name, rotRow.rot.grad, !rotRow.rot.mirrored)
                                Probe { name: "monitor-mirror-" + card.modelData.name }
                            }
                        }
                    }
                }
                Txt {
                    visible: mp.overlap
                    width: parent.width
                    text: mp.fixedPositions
                        ? "Screens overlap after rotating: their positions are set by hand – adjust \"Position\" so they sit side by side."
                        : "Screens overlap after rotating – Hyprland arranges automatic positions again in a moment."
                    color: Theme.warn
                    size: 12
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                Row {
                    spacing: Theme.pad(8)
                    Txt { text: "Position"; size: 12; strong: true; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
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
