import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Verlauf der Zwischenablage (SUPER+SHIFT+V): die letzten Kopien (Text und Bilder, cliphist) mit Suche
// und Vorschau. Pfeiltasten wählen, Enter fügt den Eintrag im vorigen Fenster ein, Entf löscht ihn,
// "Clear all" leert den Verlauf. Gelesen wird nur, solange das Panel offen ist (shell-clipboard list).
Scope {
    id: cb
    property var entries: []
    property string query: ""
    property int sel: 0
    readonly property bool enabled: Settings.get("clipboard.enabled", true)
    readonly property var shown: {
        const q = query.trim().toLowerCase()
        return q === "" ? entries : entries.filter(e => e.text.toLowerCase().indexOf(q) >= 0)
    }
    onQueryChanged: sel = 0

    function reload() { listProc.running = true }
    function run(args, then) {
        const p = actionProc.createObject(cb, { command: [Settings.bin + "shell-clipboard"].concat(args) })
        p.exited.connect(() => { if (then) then(); p.destroy() })
        p.running = true
    }
    function paste(e) {
        if (!e) return
        ov.hide()
        Quickshell.execDetached([Settings.bin + "shell-clipboard", "paste", e.id])
    }
    function remove(e) {
        if (!e) return
        entries = entries.filter(x => x.id !== e.id)
        run(["delete", e.id], null)
    }
    function clearAll() {
        entries = []
        run(["clear"], null)
    }

    Process {
        id: listProc
        command: [Settings.bin + "shell-clipboard", "list"]
        stdout: StdioCollector { onStreamFinished: { try { cb.entries = JSON.parse(text) } catch (e) { cb.entries = [] } } }
    }
    Component { id: actionProc; Process { } }

    IpcHandler {
        target: "clipboard"
        function open(): void { if (cb.enabled) ov.show() }
        function close(): void { ov.hide() }
        function toggle(): void { if (cb.enabled) ov.toggle() }
        // für Tests: Anzahl Einträge und Text des ersten
        function count(): int { return cb.entries.length }
        function first(): string { return cb.entries.length > 0 ? cb.entries[0].text : "" }
        function clear(): void { cb.clearAll() }
    }

    Overlay {
        id: ov
        name: "clipboard"
        ipc: false
        place: "center"
        margin: 0
        panelWidth: 620
        panelHeight: 560
        scroll: false
        keyboardFocus: WlrKeyboardFocus.Exclusive
        onOpened: { cb.query = ""; cb.sel = 0; cb.reload() }

        content: Component {
            Item {
                focus: true

                Rectangle {
                    id: box
                    x: 14; y: 14
                    width: parent.width - 28 - clearBtn.width - 10
                    height: 44
                    radius: 22
                    color: Theme.field
                    border.width: 1
                    border.color: Theme.cardBorder
                    Glyph { id: lens; anchors { left: parent.left; leftMargin: Theme.pad(16); verticalCenter: parent.verticalCenter } text: "󰅍"; size: 14; color: Theme.subtext }
                    TextInput {
                        id: field
                        anchors { left: lens.right; leftMargin: Theme.pad(10); right: parent.right; rightMargin: Theme.pad(16); verticalCenter: parent.verticalCenter }
                        focus: true
                        color: Theme.text
                        font.family: Theme.sans
                        font.pixelSize: 14 * Theme.fontScale
                        clip: true
                        onTextChanged: cb.query = text
                        Keys.onDownPressed: cb.sel = Math.min(cb.sel + 1, cb.shown.length - 1)
                        Keys.onUpPressed: cb.sel = Math.max(cb.sel - 1, 0)
                        Keys.onReturnPressed: cb.paste(cb.shown[cb.sel])
                        Keys.onEnterPressed: cb.paste(cb.shown[cb.sel])
                        Keys.onDeletePressed: cb.remove(cb.shown[cb.sel])
                        Txt { visible: field.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "Search clipboard history"; size: 14; sub: true }
                    }
                }
                Pill {
                    id: clearBtn
                    anchors { right: parent.right; rightMargin: Theme.pad(14); verticalCenter: box.verticalCenter }
                    implicitHeight: 36
                    icon: "󰎟"
                    text: "Clear all"
                    onClicked: cb.clearAll()
                    Probe { name: "clipboard-clear" }
                }

                ListView {
                    id: list
                    x: 14
                    anchors { top: box.bottom; topMargin: Theme.pad(12); bottom: hint.top; bottomMargin: Theme.pad(8) }
                    width: parent.width - 28
                    clip: true
                    spacing: Theme.pad(6)
                    model: cb.shown
                    currentIndex: cb.sel
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isImage: modelData.image !== ""
                        width: list.width
                        height: isImage ? 96 : Math.min(84, txt.implicitHeight + 24)
                        radius: 14
                        color: index === cb.sel ? Theme.cardHover : (hov.hovered ? Theme.card : Theme.cardLevel(0.4))
                        border.width: 1
                        border.color: index === cb.sel ? Theme.glassBorder : "transparent"
                        Image {
                            id: prev
                            visible: row.isImage
                            anchors { left: parent.left; leftMargin: Theme.pad(10); top: parent.top; topMargin: Theme.pad(8); bottom: parent.bottom; bottomMargin: Theme.pad(8) }
                            width: 140
                            source: row.isImage ? "file://" + row.modelData.image : ""
                            fillMode: Image.PreserveAspectFit
                            horizontalAlignment: Image.AlignLeft
                            asynchronous: true
                            sourceSize.width: 280
                            Probe { name: row.index === 0 && row.isImage ? "clipboard-image" : "" }
                        }
                        Txt {
                            id: txt
                            anchors { left: row.isImage ? prev.right : parent.left; leftMargin: Theme.pad(14); right: del.left; rightMargin: Theme.pad(8); verticalCenter: parent.verticalCenter }
                            text: row.isImage ? "Image" : row.modelData.text
                            size: 13
                            sub: row.isImage
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                        IconButton {
                            id: del
                            anchors { right: parent.right; rightMargin: Theme.pad(8); verticalCenter: parent.verticalCenter }
                            width: 28; height: 28
                            flat: true
                            iconSize: 12
                            icon: "󰆴"
                            onClicked: cb.remove(row.modelData)
                        }
                        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: cb.paste(row.modelData) }
                    }
                    Txt {
                        anchors.centerIn: parent
                        visible: cb.shown.length === 0
                        text: cb.entries.length === 0 ? "Clipboard history is empty" : "Nothing found"
                        sub: true
                    }
                }
                Txt {
                    id: hint
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.pad(12) }
                    text: "Enter  paste   ·   Del  remove   ·   Esc  close"
                    size: 11
                    sub: true
                }
            }
        }
    }
}
