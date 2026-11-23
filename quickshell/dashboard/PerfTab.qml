import QtQuick
import Quickshell.Io
import "../common"

// Tab Performance: CPU, GPU, Datenträger, Netzwerk, Arbeitsspeicher (12 Spalten, 2 Zeilen).
// Alles läuft nur, solange dieser Tab offen ist.
Grid12 {
    id: perf
    rows: 2
    property var cpuInfo: ({})
    property var gpu: ({})
    property string iface: ""
    property real rxRate: 0
    property real txRate: 0
    property real rxTotal: 0
    property real txTotal: 0
    property var last: null
    property var history: []

    Usage { id: usage; running: true; interval: 1500 }

    function rate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s"
        if (b >= 1024) return (b / 1024).toFixed(0) + " KB/s"
        return Math.round(b) + " B/s"
    }
    function size(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB"
        return (b / 1048576).toFixed(0) + " MB"
    }

    Process {
        id: cpuProc
        command: [Settings.home + "/.local/bin/shell-sysinfo", "cpu"]
        stdout: StdioCollector { onStreamFinished: { try { perf.cpuInfo = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: gpuProc
        command: [Settings.home + "/.local/bin/shell-sysinfo", "gpu"]
        stdout: StdioCollector { onStreamFinished: { try { perf.gpu = JSON.parse(text) } catch (e) { } } }
    }
    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { if (!cpuProc.running) cpuProc.running = true; if (!gpuProc.running) gpuProc.running = true }
    }

    // Netzwerk: Standard-Schnittstelle aus /proc/net/route, Zähler aus /proc/net/dev
    FileView {
        id: route
        path: "/proc/net/route"
        onLoaded: {
            const l = text().split("\n")
            for (let i = 1; i < l.length; i++) {
                const p = l[i].trim().split(/\s+/)
                if (p.length > 2 && p[1] === "00000000") { perf.iface = p[0]; return }
            }
            perf.iface = ""
        }
    }
    FileView {
        id: dev
        path: "/proc/net/dev"
        onLoaded: {
            if (!perf.iface) return
            const m = text().match(new RegExp("^\\s*" + perf.iface + ":\\s*(.*)$", "m"))
            if (!m) return
            const f = m[1].trim().split(/\s+/).map(Number)
            const now = Date.now()
            perf.rxTotal = f[0]; perf.txTotal = f[8]
            if (perf.last) {
                const dt = (now - perf.last.t) / 1000
                if (dt > 0) {
                    perf.rxRate = Math.max(0, (f[0] - perf.last.rx) / dt)
                    perf.txRate = Math.max(0, (f[8] - perf.last.tx) / dt)
                    const h = perf.history.slice(-59); h.push(perf.rxRate); perf.history = h
                }
            }
            perf.last = { t: now, rx: f[0], tx: f[8] }
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { route.reload(); dev.reload() }
    }

    component Head: Row {
        property string icon
        property string title
        spacing: 8
        Glyph { text: parent.icon; size: 16; color: Theme.subtext }
        Txt { text: parent.title; size: 12; sub: true; weight: Font.DemiBold }
    }
    component Bar: Rectangle {
        property real value: 0
        height: 6
        radius: 3
        color: Theme.track
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, parent.value)) / 100
            height: parent.height
            radius: 3
            color: Theme.text
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
    }

    // ---- CPU (5×1 bei 1,0)
    Cell {
        col: 1; row: 0; cs: 5; rs: 1
        Column {
            anchors { fill: parent; margins: 18 }
            spacing: 10
            Head { icon: ""; title: "CPU" }
            Txt { width: parent.width; text: perf.cpuInfo.model || "–"; size: 15; weight: Font.Bold }
            Row {
                spacing: 18
                Txt { text: Math.round(usage.cpu) + "%"; size: 28; weight: Font.Bold }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Txt { text: perf.cpuInfo.temp !== undefined && perf.cpuInfo.temp !== null ? perf.cpuInfo.temp + " °C" : "– °C"; size: 13 }
                    Txt { text: (perf.cpuInfo.cores || "–") + " threads"; size: 11; sub: true }
                }
            }
            Bar { width: parent.width; value: usage.cpu }
        }
    }

    // ---- GPU (5×1 bei 6,0)
    Cell {
        col: 6; row: 0; cs: 5; rs: 1
        Column {
            anchors { fill: parent; margins: 18 }
            spacing: 10
            Head { icon: "󰢮"; title: "GPU" }
            Txt { width: parent.width; text: perf.gpu.name || "–"; size: 15; weight: Font.Bold }
            Row {
                spacing: 18
                Txt {
                    text: perf.gpu.state === "sleeping" ? "Sleeping"
                        : perf.gpu.temp !== undefined && perf.gpu.temp !== null ? perf.gpu.temp + " °C" : "– °C"
                    size: 28; weight: Font.Bold
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Txt {
                        text: perf.gpu.memTotal ? "VRAM " + (perf.gpu.memUsed / 1024).toFixed(1) + " / " + (perf.gpu.memTotal / 1024).toFixed(1) + " GiB"
                            : perf.gpu.state === "sleeping" ? "power saving" : "VRAM –"
                        size: 13
                    }
                    Txt { text: perf.gpu.util !== undefined && perf.gpu.util !== null ? perf.gpu.util + "% load" : ""; size: 11; sub: true }
                }
            }
            Bar { width: parent.width; value: perf.gpu.memTotal ? 100 * perf.gpu.memUsed / perf.gpu.memTotal : 0 }
        }
    }

    // ---- Datenträger (4×1 bei 1,1)
    Cell {
        col: 1; row: 1; cs: 4; rs: 1
        Head { anchors { left: parent.left; top: parent.top; margins: 18 } icon: ""; title: "Storage" }
        Item {
            id: diskRing
            width: 84; height: 84
            anchors { left: parent.left; leftMargin: 18; bottom: parent.bottom; bottomMargin: 18 }
            Ring { anchors.fill: parent; value: usage.disk; thickness: 6 }
            Txt { anchors.centerIn: parent; text: Math.round(usage.disk) + "%"; size: 16; weight: Font.Bold }
        }
        Column {
            anchors { left: diskRing.right; leftMargin: 18; right: parent.right; rightMargin: 14; verticalCenter: diskRing.verticalCenter }
            spacing: 4
            Txt { text: usage.gib(usage.diskUsed) + " / " + usage.gib(usage.diskTotal) + " GiB"; size: 16; weight: Font.Bold }
            Txt { width: parent.width; text: usage.diskDevice || "–"; sub: true; size: 12 }
        }
    }

    // ---- Netzwerk (4×1 bei 5,1)
    Cell {
        col: 5; row: 1; cs: 4; rs: 1
        Head { id: netHead; anchors { left: parent.left; top: parent.top; margins: 18 } icon: "󰖩"; title: perf.iface ? "Network · " + perf.iface : "Network · offline" }
        Canvas {
            id: spark
            anchors { left: parent.left; right: parent.right; top: netHead.bottom; margins: 18; topMargin: 10 }
            height: 46
            property var data: perf.history
            onDataChanged: requestPaint()
            onPaint: {
                const g = getContext("2d")
                g.reset()
                const d = data, n = d.length
                if (n < 2) return
                const max = Math.max(1024, Math.max.apply(null, d))
                g.strokeStyle = Theme.text
                g.lineWidth = 1.6
                g.beginPath()
                for (let i = 0; i < n; i++) {
                    const x = width * i / 59, y = height - 2 - (height - 4) * d[i] / max
                    if (i === 0) g.moveTo(x, y); else g.lineTo(x, y)
                }
                g.stroke()
            }
        }
        Row {
            anchors { left: parent.left; bottom: parent.bottom; margins: 18 }
            spacing: 22
            Column {
                Txt { text: "↓ " + perf.rate(perf.rxRate); size: 14; weight: Font.Bold }
                Txt { text: perf.size(perf.rxTotal) + " total"; size: 11; sub: true }
            }
            Column {
                Txt { text: "↑ " + perf.rate(perf.txRate); size: 14; weight: Font.Bold }
                Txt { text: perf.size(perf.txTotal) + " total"; size: 11; sub: true }
            }
        }
    }

    // ---- Arbeitsspeicher (2×1 bei 9,1)
    Cell {
        col: 9; row: 1; cs: 2; rs: 1
        Head { id: memHead; anchors { left: parent.left; top: parent.top; margins: 16 } icon: ""; title: "Memory" }
        Item {
            width: 72; height: 72
            anchors { horizontalCenter: parent.horizontalCenter; top: memHead.bottom; topMargin: 10 }
            Ring { anchors.fill: parent; value: usage.mem; thickness: 6 }
            Txt { anchors.centerIn: parent; text: Math.round(usage.mem) + "%"; size: 14; weight: Font.Bold }
        }
        Txt {
            anchors { bottom: parent.bottom; bottomMargin: 14; horizontalCenter: parent.horizontalCenter }
            text: (usage.memUsed / 1048576).toFixed(1) + " / " + (usage.memTotal / 1048576).toFixed(1) + " GiB"
            size: 11
            sub: true
        }
    }
}
