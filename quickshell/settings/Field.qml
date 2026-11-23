import QtQuick
import "../common"

// Eingabefeld im Glas-Look. accepted(text) kommt bei Enter oder wenn das Feld den Fokus verliert
// und sich der Text geändert hat.
Rectangle {
    id: f
    property string text: ""
    property string placeholder: ""
    property bool mono: false
    property alias input: inp
    property bool commitOnBlur: true
    signal accepted(string text)

    implicitWidth: 220
    implicitHeight: 34
    radius: 12
    color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    border.color: inp.activeFocus ? Qt.rgba(1, 1, 1, 0.35) : Theme.cardBorder

    function commit() { if (inp.text !== f.text) f.accepted(inp.text) }

    TextInput {
        id: inp
        anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
        text: f.text
        color: Theme.text
        font.family: f.mono ? Theme.mono : Theme.sans
        font.pixelSize: 13 * Theme.fontScale
        clip: true
        selectByMouse: true
        onAccepted: f.commit()
        onActiveFocusChanged: if (!activeFocus && f.commitOnBlur) f.commit()
        Keys.onEscapePressed: event => { if (inp.text !== f.text) { inp.text = f.text; event.accepted = true } else event.accepted = false }
        Txt { visible: inp.text.length === 0 && !inp.activeFocus; text: f.placeholder; sub: true; size: 13 }
    }
    // neuer Wert von aussen (z. B. nach Undo): Feld nachführen, solange man nicht tippt
    onTextChanged: if (!inp.activeFocus) { inp.text = text; inp.cursorPosition = 0 }
    // lange Texte (Pfade) vom Anfang her zeigen
    Component.onCompleted: inp.cursorPosition = 0
}
