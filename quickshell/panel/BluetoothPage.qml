import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Unterseite Bluetooth im Panel: gekoppelte und neue Geräte mit Akkustand; koppeln, verbinden,
// trennen. "Search" sucht 8 Sekunden nach neuen Geräten. Über shell-net (bluetoothctl).
Column {
    id: bp
    property var panel
    property var devices: []
    property string busy: ""
    property string message: ""
    spacing: Theme.pad(6)

    function reload() { if (!listProc.running) listProc.running = true }
    function act(what, mac) {
        busy = mac
        message = ""
        actProc.command = [Settings.bin + "shell-net", "bt", what, mac]
        actProc.running = true
    }
    Component.onCompleted: reload()
    Timer { interval: 6000; running: true; repeat: true; onTriggered: bp.reload() }

    Process {
        id: listProc
        command: [Settings.bin + "shell-net", "bt", "list"]
        stdout: StdioCollector { onStreamFinished: { try { bp.devices = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: scanProc
        command: [Settings.bin + "shell-net", "bt", "scan"]
        stdout: StdioCollector { onStreamFinished: { try { bp.devices = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: actProc
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {}
                try { r = JSON.parse(text) } catch (e) { }
                bp.message = r.ok ? "" : (r.error || "Did not work")
                bp.busy = ""
                bp.panel.refresh()
                bp.reload()
            }
        }
    }

    Row {
        spacing: Theme.pad(8)
        Pill {
            implicitHeight: 30
            fontSize: 11
            icon: "󰂰"
            text: scanProc.running ? "Searching …" : "Search for devices"
            onClicked: if (!scanProc.running) scanProc.running = true
        }
    }
    Txt { visible: bp.message !== ""; width: parent.width; text: bp.message; size: 12; color: Theme.warn; wrapMode: Text.Wrap }
    Txt { visible: bp.devices.length === 0; text: "No devices"; size: 12; sub: true }

    Repeater {
        model: bp.devices
        delegate: GlassCard {
            id: dev
            required property var modelData
            width: bp.width
            height: 48
            Glyph {
                id: ico
                anchors { left: parent.left; leftMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
                text: dev.modelData.connected ? "󰂱" : "󰂯"
                size: 16
            }
            Column {
                anchors { left: ico.right; leftMargin: Theme.pad(12); right: btn.left; rightMargin: Theme.pad(8); verticalCenter: parent.verticalCenter }
                Txt { width: parent.width; text: dev.modelData.name; size: 13; weight: dev.modelData.connected ? Theme.titleWeight : Theme.textWeight }
                Txt {
                    width: parent.width
                    text: (dev.modelData.connected ? "Connected" : dev.modelData.paired ? "Paired" : "New")
                          + (dev.modelData.battery !== null ? "  ·  󰁹 " + dev.modelData.battery + "%" : "")
                    size: 11
                    sub: true
                }
            }
            Pill {
                id: btn
                anchors { right: parent.right; rightMargin: Theme.pad(10); verticalCenter: parent.verticalCenter }
                implicitHeight: 28
                fontSize: 11
                text: bp.busy === dev.modelData.mac ? "…" : dev.modelData.connected ? "Disconnect" : dev.modelData.paired ? "Connect" : "Pair"
                onClicked: if (bp.busy === "") bp.act(dev.modelData.connected ? "disconnect" : dev.modelData.paired ? "connect" : "pair", dev.modelData.mac)
            }
        }
    }
}
