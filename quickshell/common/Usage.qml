import QtQuick
import Quickshell.Io

// Auslastung von CPU, Arbeitsspeicher und Datenträger (/).
// Liest /proc direkt (kein Prozess pro Abfrage); läuft nur, solange running = true.
Item {
    id: u
    property bool running: true
    property int interval: 2000
    property bool withDisk: true

    property real cpu: 0
    property real memUsed: 0      // KiB
    property real memTotal: 0     // KiB
    readonly property real mem: memTotal > 0 ? 100 * memUsed / memTotal : 0
    property real diskUsed: 0     // Bytes
    property real diskTotal: 0
    property string diskDevice: ""
    readonly property real disk: diskTotal > 0 ? 100 * diskUsed / diskTotal : 0

    property var last: null

    function gib(bytes) { return (bytes / 1073741824).toFixed(1) }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = f[3] + (f[4] || 0)
            const total = f.reduce((a, b) => a + b, 0)
            if (u.last && total > u.last.total) u.cpu = 100 * (1 - (idle - u.last.idle) / (total - u.last.total))
            u.last = { idle: idle, total: total }
        }
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text()
            const val = k => { const m = t.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")); return m ? Number(m[1]) : 0 }
            u.memTotal = val("MemTotal")
            u.memUsed = u.memTotal - val("MemAvailable")
        }
    }
    Process {
        id: df
        command: ["df", "-B1", "--output=source,used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n")
                if (l.length < 2) return
                const p = l[1].trim().split(/\s+/)
                u.diskDevice = p[0].replace("/dev/", "")
                u.diskUsed = Number(p[1])
                u.diskTotal = Number(p[2])
            }
        }
    }
    Timer {
        interval: u.interval
        running: u.running
        repeat: true
        triggeredOnStart: true
        onTriggered: { stat.reload(); meminfo.reload() }
    }
    Timer {
        interval: 30000
        running: u.running && u.withDisk
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!df.running) df.running = true
    }
}
