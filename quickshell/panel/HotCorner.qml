import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Hot-Corner-Panel: berührt die Maus die Ecke (Standard unten rechts, 6 px), wächst ein
// schmales Glas-Panel heraus (gemeinsamer Baustein Overlay). Auch mit SUPER+A. Schliesst, wenn die
// Maus das Panel verlässt, mit Esc, beim Klick daneben oder wenn ein anderes Panel aufgeht.
Scope {
    id: hc
    readonly property bool open: ov.open
    property var st: ({ wifi: false, bluetooth: false, dnd: false, gaming: false, awake: false })

    readonly property var screen: Settings.screenFor(Settings.get("desktop.screen", ""))
    readonly property string corner: Settings.get("panel.corner", "bottom-right")
    readonly property bool atBottom: corner.indexOf("bottom") === 0
    readonly property bool atRight: corner.indexOf("right") > 0
    readonly property int gap: 10

    function show() { ov.show() }
    function hide() { ov.hide() }
    function refresh() { if (!stateProc.running) stateProc.running = true }
    // Befehl ausführen; closeFirst schliesst das Panel vorher (z. B. für Screenshots)
    function run(args, closeFirst) {
        if (closeFirst) hide()
        Quickshell.execDetached(["bash", "-c", "sleep \"$1\"; shift; \"$@\"", "_", closeFirst ? "0.45" : "0"].concat(args))
        soon.restart()
    }
    function toggle(name) {
        const s = Object.assign({}, st); s[name] = !s[name]; st = s   // sofort zeigen, echter Zustand folgt
        run([Settings.home + "/.local/bin/shell-toggle", name], false)
    }

    Process {
        id: stateProc
        command: [Settings.home + "/.local/bin/shell-toggle", "status"]
        stdout: StdioCollector { onStreamFinished: { try { hc.st = JSON.parse(text) } catch (e) { } } }
    }
    Timer { interval: 2000; running: hc.open; repeat: true; onTriggered: hc.refresh() }
    Timer { id: soon; interval: 700; onTriggered: hc.refresh() }

    // ---- Auslösebereich in der Ecke (Ebene "top": liegt unter Vollbild-Spielen)
    PanelWindow {
        screen: hc.screen
        visible: hc.screen !== null && !hc.open && Settings.get("panel.enabled", true)
        anchors { bottom: hc.atBottom; top: !hc.atBottom; right: hc.atRight; left: !hc.atRight }
        implicitWidth: Settings.get("panel.trigger", 6)
        implicitHeight: Settings.get("panel.trigger", 6)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hypr-shell-corner"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: hc.show()
        }
    }

    // ---- das Panel: die Form wächst aus der Ecke (bleibt dabei gerundet), der Inhalt bleibt an der
    // Ecke verankert. Ohne Mausbesuch nach dem Öffnen (SUPER+A) schliesst es erst nach einer Weile;
    // panel.close_on_leave / panel.close_delay aus settings.json
    Overlay {
        id: ov
        name: "panel"
        place: hc.corner
        animation: "grow"
        screen: hc.screen
        margin: hc.gap
        panelWidth: Settings.get("panel.width", 420)
        panelHeight: item ? item.implicitHeight : 400
        radius: Settings.get("panel.radius", Theme.panelRadius)
        glassOpacity: Settings.get("panel.opacity", 0.44)
        keyboardFocus: WlrKeyboardFocus.OnDemand
        leaveDelay: Settings.get("panel.close_on_leave", true) ? Settings.get("panel.close_delay", 400) : -1
        idleDelay: Settings.get("panel.close_on_leave", true) ? 4000 : -1
        holdOpen: item ? item.typing : false
        onOpened: hc.refresh()

        content: Component {
            PanelContent {
                panel: hc
            }
        }
    }
}
