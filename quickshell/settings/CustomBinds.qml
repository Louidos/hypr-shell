import QtQuick
import "../common"

// Eigene Tastenkürzel (keybinds.custom): Kombination + Befehl, löschen und hinzufügen.
Column {
    id: cb
    property var value: []
    property string newKeys: ""
    signal changedList(var list)
    spacing: Theme.pad(6)

    Repeater {
        model: cb.value
        delegate: Rectangle {
            id: del
            required property var modelData
            required property int index
            width: cb.width
            height: 40
            radius: 12
            color: Theme.cardSoft
            Row {
                anchors { left: parent.left; leftMargin: Theme.pad(10); verticalCenter: parent.verticalCenter }
                spacing: Theme.pad(12)
                Pill { clickable: false; implicitHeight: 28; fontSize: 12; icon: "󰌌"; text: del.modelData.keys }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: del.modelData.command; size: 13; font.family: Theme.mono; width: cb.width - 260 }
            }
            IconButton {
                anchors { right: parent.right; rightMargin: Theme.pad(6); verticalCenter: parent.verticalCenter }
                flat: true; width: 30; height: 30; iconSize: 13; icon: "󰆴"
                onClicked: cb.changedList(cb.value.filter((v, i) => i !== del.index))
            }
        }
    }
    Txt { visible: cb.value.length === 0; text: "No own shortcuts yet."; sub: true; size: 12 }
    Row {
        spacing: Theme.pad(8)
        KeyRecorder {
            anchors.verticalCenter: parent.verticalCenter
            value: cb.newKeys
            probe: "custom-keys"
            onPicked: combo => {
                const other = combo === "" ? "" : Ui.usedBy("custom#new", combo)
                if (other !== "") { Ui.lastError = combo + " is already used by " + other + " – pick another one"; return }
                Ui.lastError = ""
                cb.newKeys = combo
            }
        }
        Field { id: cmd; width: Math.max(140, Math.min(260, cb.width - 320)); mono: true; placeholder: "Command, e.g. firefox"; commitOnBlur: false }
        Pill {
            icon: "󰐕"
            text: "Add"
            onClicked: {
                const c = cmd.input.text.trim()
                if (cb.newKeys === "" || c === "") { Ui.lastError = "Press a key combination and type a command first"; return }
                cb.changedList(cb.value.concat([{ keys: cb.newKeys, command: c }]))
                cb.newKeys = ""; cmd.input.text = ""
            }
        }
    }
}
