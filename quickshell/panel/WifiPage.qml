import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Unterseite WLAN im Panel: Netze mit Stärke, Klick verbindet (mit Passwortfeld bei geschützten Netzen),
// das verbundene Netz lässt sich trennen. Liste über shell-net (nmcli), nur solange die Seite offen ist.
Column {
    id: wp
    property var panel
    property var nets: []
    property bool busy: false
    property string asking: ""      // SSID, für die gerade das Passwort abgefragt wird
    property string message: ""
    spacing: Theme.pad(6)

    function reload() { if (!listProc.running) listProc.running = true }
    function connect(ssid, pw) {
        busy = true
        message = "Connecting to " + ssid + " …"
        connectProc.command = [Settings.bin + "shell-net", "wifi", "connect", ssid]
        connectProc.stdinText = pw || ""
        connectProc.running = true
    }
    Component.onCompleted: reload()
    Timer { interval: 8000; running: true; repeat: true; onTriggered: wp.reload() }

    Process {
        id: listProc
        command: [Settings.bin + "shell-net", "wifi", "list"]
        stdout: StdioCollector { onStreamFinished: { try { wp.nets = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: connectProc
        property string stdinText: ""
        stdinEnabled: true
        onStarted: { write(stdinText + "\n"); stdinEnabled = false }
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {}
                try { r = JSON.parse(text) } catch (e) { }
                wp.busy = false
                wp.message = r.ok ? "" : (r.error || "Could not connect")
                wp.asking = ""
                wp.panel.refresh()
                wp.reload()
            }
        }
        onExited: stdinEnabled = true
    }
    Process {
        id: disconnectProc
        command: [Settings.bin + "shell-net", "wifi", "disconnect"]
        onExited: { wp.panel.refresh(); wp.reload() }
    }

    Txt { visible: wp.message !== ""; width: parent.width; text: wp.message; size: 12; color: wp.busy ? Theme.subtext : Theme.warn; wrapMode: Text.Wrap }
    Txt { visible: wp.nets.length === 0; text: listProc.running ? "Scanning …" : "No networks found"; size: 12; sub: true }

    Repeater {
        model: wp.nets
        delegate: GlassCard {
            id: net
            required property var modelData
            readonly property bool open: wp.asking === modelData.ssid
            width: wp.width
            height: open ? 104 : 48
            hoverable: true
            Item {
                width: parent.width
                height: 48
                Glyph {
                    id: bars
                    anchors { left: parent.left; leftMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
                    text: net.modelData.signal > 75 ? "󰤨" : net.modelData.signal > 50 ? "󰤥" : net.modelData.signal > 25 ? "󰤢" : "󰤟"
                    size: 16
                }
                Txt {
                    anchors { left: bars.right; leftMargin: Theme.pad(12); right: side.left; rightMargin: Theme.pad(8); verticalCenter: parent.verticalCenter }
                    text: net.modelData.ssid
                    size: 13
                    weight: net.modelData.active ? Theme.titleWeight : Theme.textWeight
                }
                Row {
                    id: side
                    anchors { right: parent.right; rightMargin: Theme.pad(10); verticalCenter: parent.verticalCenter }
                    spacing: Theme.pad(6)
                    Glyph { visible: net.modelData.secure; anchors.verticalCenter: parent.verticalCenter; text: "󰌾"; size: 11; color: Theme.subtext }
                    Txt { anchors.verticalCenter: parent.verticalCenter; text: net.modelData.signal + "%"; size: 11; sub: true }
                    Pill {
                        visible: net.modelData.active
                        implicitHeight: 26
                        fontSize: 11
                        text: "Disconnect"
                        onClicked: disconnectProc.running = true
                    }
                }
                TapHandler {
                    enabled: !net.modelData.active && !wp.busy
                    onTapped: {
                        if (net.modelData.secure) wp.asking = net.open ? "" : net.modelData.ssid
                        else wp.connect(net.modelData.ssid, "")
                    }
                }
            }
            Row {
                visible: net.open
                x: 12; y: 54
                spacing: Theme.pad(8)
                Rectangle {
                    width: net.width - 24 - joinBtn.width - 8
                    height: 36
                    radius: 18
                    color: Theme.field
                    border.width: 1
                    border.color: Theme.cardBorder
                    TextInput {
                        id: pw
                        anchors { left: parent.left; leftMargin: Theme.pad(14); right: parent.right; rightMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
                        echoMode: TextInput.Password
                        color: Theme.text
                        font.pixelSize: 12 * Theme.fontScale
                        clip: true
                        focus: net.open
                        onVisibleChanged: if (visible) forceActiveFocus()
                        Keys.onReturnPressed: wp.connect(net.modelData.ssid, text)
                        Keys.onEnterPressed: wp.connect(net.modelData.ssid, text)
                        Txt { visible: pw.text.length === 0; text: "Password"; size: 12; sub: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Pill {
                    id: joinBtn
                    implicitHeight: 36
                    active: true
                    text: "Connect"
                    onClicked: wp.connect(net.modelData.ssid, pw.text)
                }
            }
        }
    }
}
