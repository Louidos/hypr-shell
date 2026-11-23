import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Hot-Corner-Panel: berührt die Maus die Ecke (Standard unten rechts, 6 px), wächst ein
// schmales Glas-Panel heraus. Auch mit SUPER+A. Schliesst, wenn die Maus das Panel verlässt.
Scope {
    id: hc
    property bool open: false
    property bool entered: false
    property var st: ({ wifi: false, bluetooth: false, dnd: false, gaming: false, awake: false })

    readonly property var screen: Settings.screenFor(Settings.get("desktop.screen", ""))
    readonly property string corner: Settings.get("panel.corner", "bottom-right")
    readonly property bool atBottom: corner.indexOf("bottom") === 0
    readonly property bool atRight: corner.indexOf("right") > 0
    readonly property int gap: 10

    function show() { entered = false; open = true; refresh() }
    function hide() { open = false }
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

    IpcHandler {
        target: "panel"
        function open(): void { hc.show() }
        function toggle(): void { if (hc.open) hc.hide(); else hc.show() }
        function close(): void { hc.hide() }
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

    // ---- das Panel
    PanelWindow {
        id: win
        property real t: hc.open ? 1 : 0
        Behavior on t {
            NumberAnimation { duration: hc.open ? 480 : 260; easing.type: hc.open ? Easing.OutQuint : Easing.InCubic }
        }
        readonly property real pw: Settings.get("panel.width", 420)
        readonly property real ph: content.implicitHeight

        screen: hc.screen
        visible: hc.screen !== null && (hc.open || t > 0.001)
        anchors { bottom: hc.atBottom; top: !hc.atBottom; right: hc.atRight; left: !hc.atRight }
        implicitWidth: pw + 2 * hc.gap
        implicitHeight: ph + 2 * hc.gap
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hypr-shell-panel"
        WlrLayershell.keyboardFocus: hc.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        mask: Region { item: shape }

        // die Form wächst aus der Ecke (bleibt dabei gerundet)
        GlassPanel {
            id: shape
            width: win.pw * (0.55 + 0.45 * win.t)
            height: Math.max(1, win.ph * win.t)
            x: hc.atRight ? parent.width - width - hc.gap : hc.gap
            y: hc.atBottom ? parent.height - height - hc.gap : hc.gap
            radius: Math.min(Settings.get("panel.radius", Theme.panelRadius), Math.min(width, height) / 2)
            glassOpacity: Settings.get("panel.opacity", 0.44)
            clip: true
            opacity: Math.min(1, win.t * 3)

            HoverHandler {
                id: hov
                onHoveredChanged: {
                    if (hovered) { hc.entered = true; leaveTimer.stop() }
                    else if (hc.open) leaveTimer.restart()
                }
            }

            // Inhalt bleibt an der Ecke verankert, während die Form ihn freigibt
            PanelContent {
                id: content
                width: win.pw
                x: hc.atRight ? shape.width - win.pw : 0
                y: hc.atBottom ? shape.height - win.ph : 0
                panel: hc
                Keys.onEscapePressed: hc.hide()
            }
        }
        // ohne Mausbesuch nach dem Öffnen (SUPER+A) erst nach einer Weile schliessen
        Timer { id: leaveTimer; interval: hc.entered ? 400 : 4000; onTriggered: if (!hov.hovered && !content.typing) hc.hide() }
        Connections {
            target: hc
            function onOpenChanged() { if (hc.open) leaveTimer.restart(); else leaveTimer.stop() }
        }
    }
}
