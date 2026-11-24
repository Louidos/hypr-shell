import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Drei runde Glas-Kacheln am linken Rand: CPU, RAM, GPU – je ein Ring mit Symbol und Prozentzahl
// (Masse wie die Vorlage: 160 px breit, Ring 52 px). CPU und RAM kommen alle 2 s aus /proc, die GPU
// alle 3 s aus "shell-sysinfo gpu-usage". Schläft die NVIDIA-Karte (Hybrid-Grafik), steht "–" da –
// sie wird dafür nicht geweckt.
PanelWindow {
    id: w
    // Grösse nach der kürzeren Bildschirmseite (im Hochformat die Breite), 1080 = 1
    readonly property real sw: Settings.screenWidth(screen)
    readonly property real sh: Settings.screenHeight(screen)
    readonly property real k: Math.min(sw, sh) / 1080 * Ui.widget("resources", "scale", 1.0)
    property var gpu: ({ state: "unknown", util: null })
    readonly property real gpuUtil: gpu.state === "active" && typeof gpu.util === "number" ? gpu.util : -1

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "hypr-shell-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; left: true }
    // Position als Anteil des Bildschirms, nach einem Wechsel von Auflösung oder Ausrichtung auf den
    // Bildschirm begrenzt (die gespeicherte Position bleibt, das Widget ragt nur nie hinaus)
    margins {
        left: Math.round(Math.max(0, Math.min(Ui.widget("resources", "x", 0.015) * w.sw, w.sw - w.implicitWidth)))
        top: Math.round(Math.max(0, Math.min(Ui.widget("resources", "y", 0.56) * w.sh, w.sh - w.implicitHeight)))
    }
    implicitWidth: Math.ceil(col.implicitWidth)
    implicitHeight: Math.ceil(col.implicitHeight)
    mask: Region { }   // nimmt keine Klicks an (auch nicht im Bearbeiten-Modus: dort liegt eine eigene Fläche darüber)

    // Kacheln und Reihenfolge aus settings.json (desktop.resources.tiles: cpu, ram, gpu, disk)
    readonly property var tiles: Settings.get("desktop.resources.tiles", ["cpu", "ram", "gpu"])
    readonly property var tileInfo: ({
        cpu: { label: "CPU", icon: "\uf2db", value: () => usage.cpu },
        ram: { label: "RAM", icon: "󰍛", value: () => usage.mem },
        gpu: { label: "GPU", icon: "\uf26c", value: () => w.gpuUtil },
        disk: { label: "Disk", icon: "󰋊", value: () => usage.disk }
    })

    Usage { id: usage; running: w.visible; withDisk: w.tiles.indexOf("disk") >= 0 }

    Process {
        id: gpuProc
        command: [Settings.home + "/.local/bin/shell-sysinfo", "gpu-usage"]
        stdout: StdioCollector { onStreamFinished: { try { w.gpu = JSON.parse(text) } catch (e) { } } }
    }
    Timer {
        interval: 3000
        running: w.visible && w.tiles.indexOf("gpu") >= 0
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!gpuProc.running) gpuProc.running = true
    }

    Column {
        id: col
        spacing: Theme.pad(12) * w.k
        Probe { name: "desktop-resources"; visible: false }   // unsichtbar: kein Platz in der Spalte
        Repeater {
            model: w.tiles.filter(t => w.tileInfo[t] !== undefined).map(t => w.tileInfo[t])
            delegate: GlassPanel {
                id: tile
                required property var modelData
                readonly property real v: modelData.value()
                width: 160 * w.k
                height: 118 * w.k
                radius: Theme.panelRadius * w.k
                Ring {
                    id: ring
                    width: 52 * w.k
                    height: width
                    thickness: 5 * w.k
                    value: Math.max(1, tile.v)
                    color: "#F6F5F4"
                    trackColor: Qt.rgba(1, 1, 1, 0.12)
                    anchors { top: parent.top; right: parent.right; topMargin: Theme.pad(14) * w.k; rightMargin: Theme.pad(16) * w.k }
                }
                Glyph {
                    anchors.centerIn: ring
                    text: tile.modelData.icon
                    size: 15 * w.k
                    color: "#c8c8cc"
                }
                Column {
                    anchors { left: parent.left; bottom: parent.bottom; leftMargin: Theme.pad(18) * w.k; bottomMargin: Theme.pad(14) * w.k }
                    spacing: 0
                    Text {
                        text: tile.v < 0 ? "–" : Math.round(tile.v) + "%"
                        font.family: Theme.mono
                        font.pixelSize: 26 * w.k
                        font.weight: Theme.titleWeight
                        color: "#F6F5F4"
                    }
                    Text {
                        text: tile.modelData.label
                        font.family: Theme.mono
                        font.pixelSize: 12 * w.k
                        color: "#8a8a8f"
                    }
                }
            }
        }
    }
}
