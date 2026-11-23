import QtQuick
import "../common"

// Eine Zeile der Einstellungs-App, erzeugt aus einem Eintrag des Schemas: Symbol, Titel,
// Erklärung und rechts das passende Bedienelement. Listen bekommen darunter einen Editor.
// Jede Änderung geht über shell-set (Ui.set) und wirkt sofort.
GlassCard {
    id: row
    property var spec: ({})
    readonly property string key: spec.key || ""
    readonly property var value: Settings.get(key, spec.default)
    readonly property var rawv: Settings.rawValue(key)
    readonly property bool changed: rawv !== undefined && JSON.stringify(rawv) !== JSON.stringify(spec.default)
    readonly property bool wide: spec.type === "list" || spec.type === "stringlist" || spec.type === "objectlist"
    // zuletzt gesetzter Wert, bis settings.json ihn bestätigt (damit Schalter sofort umspringen)
    property var pending: undefined
    readonly property var shown: pending !== undefined ? pending : value
    property bool flash: false

    function write(v) {
        pending = v
        pendingTimer.restart()
        Ui.set(key, v, false)
    }
    onValueChanged: pending = undefined
    Timer { id: pendingTimer; interval: 2000; onTriggered: row.pending = undefined }

    function decimals() {
        const s = String(spec.step || 1)
        return s.indexOf(".") >= 0 ? s.split(".")[1].length : 0
    }
    function fmt(v) {
        if (typeof v !== "number") return String(v)
        return v.toFixed(decimals()) + (spec.unit ? " " + spec.unit : "")
    }

    height: head.height + (wide ? editor.height + 14 : 0)
    color: flash ? Qt.rgba(1, 1, 1, 0.14) : Theme.card
    Behavior on color { ColorAnimation { duration: 400 } }
    Timer { running: row.flash; interval: 1600; onTriggered: row.flash = false }

    Item {
        id: head
        width: parent.width
        height: Math.max(64, texts.implicitHeight + 24)

        Rectangle {
            id: bubble
            width: 36; height: 36; radius: 18
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            color: Qt.rgba(1, 1, 1, 0.07)
            Glyph { anchors.centerIn: parent; text: row.spec.icon || ""; size: 15 }
        }
        Column {
            id: texts
            anchors { left: bubble.right; leftMargin: 14; right: controls.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 2
            Txt { width: parent.width; text: row.spec.title || row.key; size: 14; weight: Font.DemiBold }
            Txt { width: parent.width; text: row.spec.description || ""; size: 12; sub: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        }
        Row {
            id: controls
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 10
            Pill {
                visible: row.changed
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 26
                fontSize: 11
                icon: "󰑓"
                text: "Reset"
                onClicked: { row.pending = row.spec.default; pendingTimer.restart(); Ui.reset([row.key]) }
                Probe { name: "reset-" + row.key }
            }
            Loader {
                id: control
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: row.spec.type === "bool" ? toggleC
                               : row.spec.type === "int" || row.spec.type === "number" ? sliderC
                               : row.spec.type === "enum" ? choiceC
                               : row.spec.type === "color" ? colorC
                               : row.spec.type === "keybind" ? keyC
                               : row.spec.type === "string" ? textC
                               : row.wide ? countC : null
            }
        }
    }
    Loader {
        id: editor
        visible: row.wide
        active: row.wide
        x: 64
        y: head.height
        width: row.width - 64 - 14
        sourceComponent: row.key === "keybinds.custom" ? customC : row.spec.type === "objectlist" ? jsonC : listC
    }

    Component {
        id: toggleC
        Toggle {
            checked: row.shown === true
            onToggled: row.write(!(row.shown === true))
            Probe { name: "setting-" + row.key }
        }
    }
    Component {
        id: sliderC
        Row {
            spacing: 12
            Slider {
                id: sl
                width: 200
                anchors.verticalCenter: parent.verticalCenter
                from: row.spec.min
                to: row.spec.max
                stepSize: row.spec.step || 1
                value: typeof row.shown === "number" ? row.shown : row.spec.default
                onMoved: v => Ui.set(row.key, v, true)
                onReleased: v => row.write(v)
                Probe { name: "setting-" + row.key }
            }
            Txt {
                width: 70
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: row.fmt(sl.shown)
                size: 13
                weight: Font.DemiBold
                font.family: Theme.mono
            }
        }
    }
    Component {
        id: choiceC
        Row {
            spacing: 6
            Repeater {
                model: row.spec.values || []
                delegate: Pill {
                    required property string modelData
                    implicitHeight: 30
                    fontSize: 12
                    text: modelData
                    active: row.shown === modelData
                    onClicked: row.write(modelData)
                    Probe { name: "setting-" + row.key + "=" + modelData }
                }
            }
        }
    }
    Component {
        id: textC
        Field {
            width: 260
            text: row.shown === undefined || row.shown === null ? "" : String(row.shown)
            mono: row.key.indexOf("apps.") === 0
            placeholder: row.spec.default === "" ? "empty = automatic" : String(row.spec.default)
            onAccepted: t => row.write(t)
            Probe { name: "setting-" + row.key }
        }
    }
    Component {
        id: colorC
        Row {
            spacing: 8
            readonly property var presets: ["#8ab4f8", "#a6e3a1", "#f9e2af", "#fab387", "#f38ba8", "#cba6f7", "#94e2d5", "#d4d4d4"]
            Repeater {
                model: parent.presets
                delegate: Rectangle {
                    required property string modelData
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    width: 22; height: 22; radius: 11
                    color: modelData
                    border.width: String(row.shown).toLowerCase() === modelData ? 2 : 0
                    border.color: "white"
                    TapHandler { onTapped: row.write(modelData) }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
            Field {
                width: 100
                mono: true
                text: String(row.shown)
                onAccepted: t => row.write(t.trim())
            }
        }
    }
    Component {
        id: countC
        Txt { text: (row.shown || []).length + " entries"; sub: true; size: 12 }
    }
    Component {
        id: listC
        ListEditor {
            value: Array.isArray(row.shown) ? row.shown : []
            allowed: row.spec.type === "list" ? row.spec.values : null
            sortable: row.spec.sortable !== false
            probePrefix: "setting-" + row.key + ":"
            onChangedList: l => row.write(l)
        }
    }
    // Tastenkürzel: doppelte Belegung wird gezeigt und nicht gespeichert
    function writeKey(combo) {
        const name = key.replace("keybinds.", "")
        const other = combo === "" ? "" : Ui.usedBy(name, combo)
        if (other !== "") { Ui.lastError = combo + " is already used by " + other + " – not saved"; return }
        Ui.lastError = ""
        write(combo)
    }
    Component {
        id: keyC
        KeyRecorder {
            value: typeof row.shown === "string" ? row.shown : ""
            required: row.spec.required === true
            modifiersOnly: /_mod$/.test(row.key)
            probe: "setting-" + row.key
            onPicked: combo => row.writeKey(combo)
        }
    }
    Component {
        id: customC
        CustomBinds {
            value: Array.isArray(row.shown) ? row.shown : []
            onChangedList: l => row.write(l)
        }
    }
    Component {
        id: jsonC
        Field {
            mono: true
            text: JSON.stringify(row.shown)
            onAccepted: t => { try { row.write(JSON.parse(t)) } catch (e) { Ui.lastError = row.key + ": not valid JSON" } }
        }
    }
}
