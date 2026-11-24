import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Tab Lab (nur mit lab.enabled und missa.enabled): Zustand des Homelabs über Missa-Core –
// VMs und IPs (/api/homelab), Messwerte und Erreichbarkeit (/api/server), Container (/api/container),
// Alarme (/api/alarme). Gelesen über shell-fetch (3 s Zeitlimit, Zwischenspeicher) nur, solange der Tab
// offen ist; ist Missa-Core nicht erreichbar, bleibt der letzte Stand mit Zeitpunkt stehen.
Item {
    id: lab
    property var res: ({ ok: false, error: "loading", data: null })
    readonly property var d: res.data || ({})
    readonly property var vms: d.homelab ? (d.homelab.vms || []) : []
    readonly property var werte: d.server ? (d.server.werte || []) : []
    readonly property var domains: d.server ? (d.server.erreichbarkeit || []) : []
    readonly property var container: {
        const l = []
        const h = d.container ? (d.container.hosts || {}) : {}
        for (const k in h) for (const c of (h[k].container || [])) l.push(c)
        return l.sort((a, b) => (a.zustand === "running") - (b.zustand === "running"))
    }
    readonly property var alarme: d.alarme ? (d.alarme.aktiv || []) : []

    function reload() { if (!proc.running) proc.running = true }
    Component.onCompleted: reload()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: lab.reload() }
    Process {
        id: proc
        command: [Settings.bin + "shell-fetch", "lab"]
        stdout: StdioCollector { onStreamFinished: { try { lab.res = JSON.parse(text) } catch (e) { } } }
    }

    // ---- ohne Einrichtung: kurze Anleitung statt Fehlern
    Column {
        visible: lab.res.error === "setup"
        anchors.centerIn: parent
        width: parent.width * 0.6
        spacing: Theme.pad(8)
        Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: "󰒋"; size: 34; color: Theme.subtext }
        Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: "The Lab tab reads your homelab through Missa-Core. Enter the Missa-Core address and the API key in Settings → Integrations."; size: 13; sub: true }
    }

    Row {
        visible: lab.res.error !== "setup"
        anchors.fill: parent
        spacing: Theme.pad(12)
        readonly property real cw: (width - 36) / 4

        component Box: GlassCard {
            property string title: ""
            property string icon: ""
            default property alias inner: body.data
            width: parent.cw
            height: parent.height
            Row {
                id: hdr
                x: 14; y: 12
                spacing: Theme.pad(8)
                Glyph { text: icon; size: 14 }
                Txt { text: title; size: 13; title: true }
            }
            Flickable {
                anchors { top: hdr.bottom; topMargin: Theme.pad(8); left: parent.left; leftMargin: Theme.pad(14); right: parent.right; rightMargin: Theme.pad(10); bottom: parent.bottom; bottomMargin: Theme.pad(10) }
                contentHeight: body.implicitHeight
                clip: true
                Column { id: body; width: parent.width; spacing: Theme.pad(4) }
            }
        }
        component Line: Row {
            property color dot: Theme.subtext
            property string text: ""
            property string side: ""
            width: parent ? parent.width : 0
            spacing: Theme.pad(6)
            Rectangle { width: 7; height: 7; radius: Theme.corner(3.5); color: dot; anchors.verticalCenter: parent.verticalCenter }
            Txt { width: parent.width - 13 - sideT.implicitWidth - 6; text: parent.text; size: 11 }
            Txt { id: sideT; text: parent.side; size: 11; sub: true }
        }

        Box {
            title: "VMs"
            icon: "󰍹"
            Repeater {
                model: lab.vms
                delegate: Line {
                    required property var modelData
                    dot: modelData.status === "running" ? "#5cc98a" : Theme.warn
                    text: modelData.name + "  " + (modelData.ips || []).join(", ")
                    side: modelData.cpus + " CPU · " + Math.round((modelData.ram_mb || 0) / 1024) + " GB"
                }
            }
            Probe { name: "lab-vms" }
        }
        Box {
            title: "Servers"
            icon: "󰒍"
            Repeater {
                model: lab.werte
                delegate: Line { required property var modelData; dot: (modelData.wert || 0) > 85 ? Theme.warn : "#5cc98a"; text: modelData.ziel + " " + modelData.metrik; side: modelData.wert + " " + (modelData.einheit || "") }
            }
            Repeater {
                model: lab.domains
                delegate: Line { required property var modelData; dot: modelData.status === "ok" ? "#5cc98a" : Theme.warn; text: modelData.domain; side: modelData.status === "ok" ? "ok" : (modelData.problem || modelData.status) }
            }
        }
        Box {
            title: "Containers"
            icon: "󰡨"
            Repeater {
                model: lab.container
                delegate: Line { required property var modelData; dot: modelData.zustand === "running" ? "#5cc98a" : Theme.warn; text: modelData.host + "/" + modelData.name; side: modelData.zustand }
            }
        }
        Box {
            title: "Alarms"
            icon: "󰀦"
            Txt { visible: lab.alarme.length === 0; text: "No active alarms"; size: 11; sub: true }
            Repeater {
                model: lab.alarme
                delegate: Txt { required property string modelData; width: parent.width; text: "• " + modelData; size: 11; color: Theme.warn; wrapMode: Text.Wrap }
            }
            Txt {
                width: parent.width
                visible: !lab.res.ok && lab.res.error !== "loading"
                text: "Missa-Core not reachable" + (lab.res.last_ok ? " · last update " + Qt.formatDateTime(new Date(lab.res.last_ok), "HH:mm") : "")
                size: 11
                sub: true
                wrapMode: Text.Wrap
            }
        }
    }
}
