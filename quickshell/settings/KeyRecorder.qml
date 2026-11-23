import QtQuick
import "../common"

// Tastenkombination aufnehmen: Klick, dann die neue Kombination drücken (Esc bricht ab).
// Mit modifiersOnly nur Modifikatoren als Schalter (für Arbeitsflächen und Maus).
// picked(combo) meldet die neue Kombination ("" = keine Taste); prüfen und speichern macht der Aufrufer.
Row {
    id: kr
    property string value: ""
    property bool required: false
    property bool modifiersOnly: false
    property bool recording: false
    property string probe: ""
    signal picked(string combo)
    spacing: 6

    readonly property var mods: ["SUPER", "SHIFT", "CTRL", "ALT"]
    function hasMod(m) { return value.split("+").map(x => x.trim()).indexOf(m) >= 0 }
    function toggleMod(m) {
        const cur = mods.filter(x => hasMod(x))
        const next = cur.indexOf(m) >= 0 ? cur.filter(x => x !== m) : cur.concat([m])
        picked(mods.filter(x => next.indexOf(x) >= 0).join(" + "))
    }
    function keyName(e) {
        const k = e.key
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1)
        const m = {
            [Qt.Key_Space]: "Space", [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Tab]: "Tab",
            [Qt.Key_Print]: "Print", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down", [Qt.Key_Delete]: "Delete", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Home]: "Home",
            [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Insert]: "Insert",
            [Qt.Key_Comma]: "comma", [Qt.Key_Period]: "period", [Qt.Key_Minus]: "minus", [Qt.Key_Plus]: "plus",
            [Qt.Key_Slash]: "slash", [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Equal]: "equal"
        }
        return m[k] || ""
    }

    // ---- Kombination aufnehmen
    Pill {
        visible: !kr.modifiersOnly
        implicitHeight: 30
        fontSize: 12
        icon: kr.recording ? "󰑊" : "󰌌"
        text: kr.recording ? "Press keys … (Esc cancels)" : (kr.value === "" ? "No key" : kr.value)
        active: kr.recording
        onClicked: { kr.recording = true; catcher.forceActiveFocus() }
        Probe { name: kr.probe }
    }
    Item {
        id: catcher
        width: 1; height: 1
        Keys.onPressed: event => {
            event.accepted = true
            if (event.key === Qt.Key_Escape) { kr.recording = false; return }
            const name = kr.keyName(event)
            if (name === "") return      // nur ein Modifikator: auf die eigentliche Taste warten
            const m = []
            if (event.modifiers & Qt.MetaModifier) m.push("SUPER")
            if (event.modifiers & Qt.ShiftModifier) m.push("SHIFT")
            if (event.modifiers & Qt.ControlModifier) m.push("CTRL")
            if (event.modifiers & Qt.AltModifier) m.push("ALT")
            kr.recording = false
            kr.picked(m.concat([name]).join(" + "))
        }
        onActiveFocusChanged: if (!activeFocus) kr.recording = false
    }
    // ---- nur Modifikatoren
    Repeater {
        model: kr.modifiersOnly ? kr.mods : []
        delegate: Pill {
            required property string modelData
            implicitHeight: 30
            fontSize: 12
            text: modelData
            active: kr.hasMod(modelData)
            onClicked: kr.toggleMod(modelData)
        }
    }
    Pill {
        visible: !kr.required && kr.value !== "" && !kr.recording
        implicitHeight: 30
        fontSize: 12
        icon: "󰅖"
        text: kr.modifiersOnly ? "Off" : "Clear"
        onClicked: kr.picked("")
    }
}
