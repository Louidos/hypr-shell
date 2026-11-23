import QtQuick
import Quickshell.Io
import "../common"

// Tab Performance: CPU, GPU, Datenträger, Netzwerk, Arbeitsspeicher (12 Spalten, 2 Zeilen).
// Aufbau wie die Vorlage: CPU/GPU mit Symbol im Ring, Modell, Temperatur mit Balken und der
// Auslastung in einem gewellten Abzeichen; Storage mit Ring und Gerät als Pille; Network mit
// gefüllter Verlaufslinie; Memory mit Ring. Alles läuft nur, solange dieser Tab offen ist.
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
    property var txHistory: []

    Usage { id: usage; running: true; interval: 1500 }

    function rate(b) {
        if (b < 1024) return b.toFixed(1) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
        return (b / 1048576).toFixed(1) + " MB/s"
    }
    function size(b) {
        if (b < 1048576) return (b / 1024).toFixed(0) + "KB"
        if (b < 1073741824) return (b / 1048576).toFixed(1) + "MB"
        return (b / 1073741824).toFixed(2) + "GB"
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
                    const t = perf.txHistory.slice(-59); t.push(perf.txRate); perf.txHistory = t
                }
            }
            perf.last = { t: now, rx: f[0], tx: f[8] }
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { route.reload(); dev.reload() }
    }

    // ---- Bausteine
    component Title: Txt {
        size: 17
        weight: Font.DemiBold
    }
    // gewelltes Abzeichen ("Cookie", Material 3 expressive)
    component Cookie: Canvas {
        id: ck
        property color fill: Theme.container
        property int bumps: 9
        onFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const g = getContext("2d")
            g.reset()
            const cx = width / 2, cy = height / 2, R = Math.min(width, height) / 2 - 2
            g.beginPath()
            for (let i = 0; i <= 180; i++) {
                const a = i / 180 * Math.PI * 2
                const r = R * (0.9 + 0.1 * Math.cos(a * ck.bumps))
                const x = cx + r * Math.cos(a), y = cy + r * Math.sin(a)
                if (i === 0) g.moveTo(x, y); else g.lineTo(x, y)
            }
            g.closePath()
            g.fillStyle = ck.fill
            g.fill()
        }
    }
    // CPU oder GPU: Symbol im Ring links, Name, Modell, Temperatur mit Balken, rechts "Usage"
    component Chipset: Cell {
        id: cc
        property string title: "CPU"
        property string icon: ""
        property string model: ""
        property var temp: null
        property real use: -1          // < 0: unbekannt ("–")
        property string extra: ""      // z. B. Grafikspeicher
        property string note: ""       // z. B. "Sleeping" statt Temperatur
        readonly property real bs: Math.min(height - 40, width * 0.3, 104)
        Item {
            id: ico
            x: 16; y: 16; width: 42; height: 42
            Ring { anchors.fill: parent; value: Math.max(0, cc.use); thickness: 3 }
            Glyph { anchors.centerIn: parent; text: cc.icon; size: 18 }
        }
        Column {
            anchors { left: ico.right; leftMargin: 12; right: blob.left; rightMargin: 10 }
            y: 16
            spacing: 2
            Txt { text: cc.title; size: 18; weight: Font.DemiBold; color: Theme.accent }
            Txt { width: parent.width; text: cc.model || "–"; size: 12 }
        }
        Row {
            x: 18; y: parent.height - 56
            spacing: 6
            Glyph { text: "󰔏"; size: 15; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: cc.note !== "" ? cc.note : (typeof cc.temp === "number" ? cc.temp + "°C" : "–")
                size: 14
            }
            Txt { visible: cc.extra !== ""; anchors.verticalCenter: parent.verticalCenter; text: "·  " + cc.extra; size: 12; sub: true }
        }
        Item {
            x: 18; y: parent.height - 28
            width: blob.x - 34; height: 6
            Rectangle { anchors.fill: parent; radius: 3; color: Theme.track }
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, (typeof cc.temp === "number" ? cc.temp : 0) / 100))
                height: parent.height
                radius: 3
                color: (cc.temp || 0) >= 85 ? Theme.warn : Theme.accent
                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
        Txt { anchors.horizontalCenter: blob.horizontalCenter; y: 12; text: "Usage"; size: 12; sub: true }
        Cookie {
            id: blob
            anchors { right: parent.right; rightMargin: 16 }
            y: 32 + (parent.height - 32 - height) / 2 - 6
            width: cc.bs; height: cc.bs
            Txt {
                anchors.centerIn: parent
                text: cc.use >= 0 ? Math.round(cc.use) + "%" : "–"
                size: cc.bs * 0.27
                weight: Font.DemiBold
                color: Theme.containerText
            }
        }
    }

    // ---- CPU (5×1 bei 1,0)
    Chipset {
        col: 1; row: 0; cs: 5; rs: 1
        title: "CPU"
        icon: "󰘚"
        model: perf.cpuInfo.model || ""
        temp: perf.cpuInfo.temp
        use: usage.cpu
        extra: perf.cpuInfo.cores ? perf.cpuInfo.cores + " threads" : ""
    }

    // ---- GPU (5×1 bei 6,0); eine schlafende NVIDIA-Karte wird nicht geweckt
    Chipset {
        col: 6; row: 0; cs: 5; rs: 1
        title: "GPU"
        icon: "󰍹"
        model: perf.gpu.name || ""
        temp: perf.gpu.temp
        use: perf.gpu.state === "sleeping" || typeof perf.gpu.util !== "number" ? -1 : perf.gpu.util
        note: perf.gpu.state === "sleeping" ? "Sleeping" : ""
        extra: perf.gpu.memTotal ? (perf.gpu.memUsed / 1024).toFixed(1) + " / " + (perf.gpu.memTotal / 1024).toFixed(1) + " GiB" : ""
    }

    // ---- Datenträger (4×1 bei 1,1): Ring "Used", Gerätename als Pille
    Cell {
        id: st
        col: 1; row: 1; cs: 4; rs: 1
        readonly property real rs2: Math.min(height - 36, 116)
        Item {
            id: sr
            x: 16; anchors.verticalCenter: parent.verticalCenter
            width: st.rs2; height: st.rs2
            Ring { anchors.fill: parent; value: usage.disk; thickness: 8; gapped: true; color: Theme.accent }
            Column {
                anchors.centerIn: parent
                Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: "󰋊"; size: 15; color: Theme.subtext }
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: usage.diskTotal > 0 ? Math.round(usage.disk) + "%" : "–"; size: st.rs2 * 0.2; weight: Font.DemiBold }
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Used"; size: 11; sub: true }
            }
        }
        Column {
            anchors { left: sr.right; leftMargin: 16; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 4
            Title { text: "Storage" }
            Txt { width: parent.width; text: usage.diskTotal > 0 ? usage.gib(usage.diskUsed) + " / " + usage.gib(usage.diskTotal) + " GiB" : "–"; size: 13; sub: true }
            Item { width: 1; height: 6 }
            Rectangle {
                width: Math.min(parent.width, dl.implicitWidth + 34)
                height: 32
                radius: 16
                color: Theme.container
                Row {
                    id: dl
                    anchors.centerIn: parent
                    spacing: 6
                    Glyph { text: "󰋊"; size: 14; color: Theme.containerText; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: usage.diskDevice || "disk"; size: 12; color: Theme.containerText; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    // ---- Netzwerk (4×1 bei 5,1): gefüllte Verlaufslinie, Download, Upload, Total
    Cell {
        id: net
        col: 5; row: 1; cs: 4; rs: 1
        Row {
            x: 16; y: 12
            spacing: 8
            Glyph { text: "󰓡"; size: 17; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Title { text: "Network" }
            Txt { text: perf.iface || "offline"; size: 10; sub: true; anchors.verticalCenter: parent.verticalCenter }
        }
        Canvas {
            id: graph
            x: 16; y: 40
            width: parent.width - 32
            height: Math.max(10, parent.height - 40 - 64)
            property var rx: perf.history
            property var tx: perf.txHistory
            onRxChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const g = getContext("2d")
                g.reset()
                const W = width, H = height
                const all = rx.concat(tx)
                const mx = Math.max(1024, Math.max.apply(null, all.length ? all : [1]))
                function linie(arr, col, fillA) {
                    if (arr.length < 2) return
                    g.beginPath()
                    for (let i = 0; i < arr.length; i++) {
                        const x = W - (arr.length - 1 - i) * (W / 59), y = H - (arr[i] / mx) * (H - 4)
                        if (i === 0) g.moveTo(x, y); else g.lineTo(x, y)
                    }
                    g.strokeStyle = col; g.lineWidth = 1.6; g.stroke()
                    g.lineTo(W, H); g.lineTo(W - (arr.length - 1) * (W / 59), H); g.closePath()
                    g.globalAlpha = fillA; g.fillStyle = col; g.fill(); g.globalAlpha = 1
                }
                g.strokeStyle = Theme.track; g.lineWidth = 1
                g.beginPath(); g.moveTo(0, H - 0.5); g.lineTo(W, H - 0.5); g.stroke()
                linie(tx, Theme.subtext, 0.12)
                linie(rx, Theme.accent, 0.25)
            }
        }
        Column {
            x: 16; width: parent.width - 32
            y: parent.height - 62
            spacing: 2
            Repeater {
                model: [
                    { icon: "󰇚", t: "Download", v: perf.iface ? perf.rate(perf.rxRate) : "–" },
                    { icon: "󰕒", t: "Upload", v: perf.iface ? perf.rate(perf.txRate) : "–" },
                    { icon: "󰋚", t: "Total", v: perf.iface ? "↓" + perf.size(perf.rxTotal) + "  ↑" + perf.size(perf.txTotal) : "–" }
                ]
                delegate: Item {
                    required property var modelData
                    width: parent.width; height: 19
                    Glyph { text: modelData.icon; size: 14; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                    Txt { x: 22; text: modelData.t; size: 12; sub: true; anchors.verticalCenter: parent.verticalCenter }
                    Txt { anchors.right: parent.right; text: modelData.v; size: 12; weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    // ---- Arbeitsspeicher (2×1 bei 9,1): Ring und belegt/gesamt
    Cell {
        id: mem
        col: 9; row: 1; cs: 2; rs: 1
        readonly property real rs2: Math.min(height - 70, width - 40, 96)
        Row {
            x: 16; y: 12
            spacing: 8
            Glyph { text: "󰍛"; size: 17; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Title { text: "Memory" }
        }
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 40
            width: mem.rs2; height: mem.rs2
            Ring { anchors.fill: parent; value: usage.mem; thickness: 7; gapped: true; color: Theme.accent }
            Column {
                anchors.centerIn: parent
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(usage.mem) + "%"; size: mem.rs2 * 0.22; weight: Font.DemiBold }
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Used"; size: 10; sub: true }
            }
        }
        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 24
            text: (usage.memUsed / 1048576).toFixed(1) + " / " + (usage.memTotal / 1048576).toFixed(1) + " GiB"
            size: 12
        }
    }
}
