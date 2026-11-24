import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Rückfrage des Missa-Agenten (Stufe ask): Glas-Karte oben in der Mitte, die den Befehl bzw. die Datei
// wörtlich zeigt. Enter erlaubt, Esc lehnt ab, nach 60 Sekunden ohne Antwort abgelehnt.
// Wird nur geladen, wenn der Missa-Agent eingeschaltet ist (shell.qml).
Scope {
    id: ma
    property var pending: []      // { id, tool, text, started }

    function answer(yes) {
        if (pending.length === 0) return
        const p = pending[0]
        Quickshell.execDetached([Settings.bin + "shell-missa-agent", "answer", p.id, yes ? "yes" : "no"])
        pending = pending.slice(1)
    }
    readonly property var current: pending.length > 0 ? pending[0] : null
    property int left: 60
    Timer {
        running: ma.current !== null
        interval: 1000
        repeat: true
        onTriggered: { ma.left = Math.max(0, 60 - Math.floor((Date.now() - ma.current.started) / 1000)); if (ma.left === 0) ma.answer(false) }
    }

    IpcHandler {
        target: "missaagent"
        function ask(id: string, tool: string, text: string): void {
            const p = ma.pending.slice(); p.push({ id: id, tool: tool, text: text, started: Date.now() }); ma.pending = p; ma.left = 60
        }
        function expire(id: string): void { ma.pending = ma.pending.filter(p => p.id !== id) }
        // für Tests
        function waiting(): string { return ma.current ? ma.current.tool + ": " + ma.current.text : "" }
        function allow(): void { ma.answer(true) }
        function deny(): void { ma.answer(false) }
    }

    // Notfall-Freigabe der Tastatur (SUPER+CTRL+Escape): eine offene Rückfrage gilt als abgelehnt
    Connections { target: Ui; function onReleased() { if (ma.current !== null) ma.answer(false) } }

    Overlay {
        name: "missa-ask"
        exclusive: false
        ipc: false
        place: "top"
        margin: 48
        panelWidth: 560
        panelHeight: 250
        localOpen: ma.current !== null
        layer: WlrLayer.Overlay
        keyboardFocus: WlrKeyboardFocus.Exclusive
        closeOnOutside: false
        closeOnEscape: false
        content: Component {
            Item {
                focus: true
                Keys.onReturnPressed: ma.answer(true)
                Keys.onEnterPressed: ma.answer(true)
                Keys.onEscapePressed: ma.answer(false)
                Column {
                    id: col
                    x: 20; y: 18
                    width: parent.width - 40
                    spacing: 12
                    Row {
                        spacing: 10
                        Glyph { text: "󰚩"; size: 18; color: Theme.warn; anchors.verticalCenter: parent.verticalCenter }
                        Txt { text: "Missa wants to " + (ma.current ? ma.current.tool.replace("rechner_", "").replace("_", " ") : ""); size: 15; weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle {
                        width: parent.width
                        height: code.implicitHeight + 20
                        radius: 12
                        color: Qt.rgba(0, 0, 0, 0.35)
                        Text {
                            id: code
                            x: 12; y: 10
                            width: parent.width - 24
                            text: ma.current ? ma.current.text : ""
                            wrapMode: Text.WrapAnywhere
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 13 * Theme.fontScale
                            maximumLineCount: 12
                            elide: Text.ElideRight
                        }
                    }
                    Item {
                        width: parent.width
                        height: 36
                        Txt { anchors.verticalCenter: parent.verticalCenter; text: "Declined in " + ma.left + " s"; size: 12; sub: true }
                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            Pill { implicitHeight: 34; text: "Deny  (Esc)"; onClicked: ma.answer(false) }
                            Pill { implicitHeight: 34; text: "Allow  (Enter)"; active: true; onClicked: ma.answer(true); Probe { name: "missa-allow" } }
                        }
                    }
                }
            }
        }
    }
}
