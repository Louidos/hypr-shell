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
    property var st: ({ wifi: false, bluetooth: false, audio: false, dnd: false, gaming: false, awake: false, nightlight: null, profile: null })
    property string wantPage: ""
    // Schnellschalter aus panel.toggles ohne die, die der Rechner nicht hat (Zustand null)
    readonly property var toggles: Settings.get("panel.toggles", ["wifi", "bluetooth", "audio", "dnd", "gaming", "profile", "nightlight", "settings"])
        .filter(n => n === "settings" || st[n] !== null)
        // "Missa access" nur, wenn der Missa-Agent eingeschaltet ist
        .concat(Integrations.missaAgent && st.missa !== null && st.missa !== undefined ? ["missa"] : [])

    readonly property var screen: Settings.screenFor(Settings.get("desktop.screen", ""))
    readonly property string corner: Settings.get("panel.corner", "bottom-right")
    readonly property bool atBottom: corner.indexOf("bottom") === 0
    readonly property bool atRight: corner.indexOf("right") > 0
    readonly property int gap: 10

    function show() { wantPage = ""; ov.show() }
    // Panel direkt auf einer Unterseite öffnen (Klick auf WLAN, Bluetooth oder Ton in der Leiste)
    function showPage(name) { wantPage = name; ov.show(); if (ov.item) ov.item.page = name }

    IpcHandler {
        target: "panel"
        function open(): void { hc.show() }
        function close(): void { hc.hide() }
        function toggle(): void { if (hc.open) hc.hide(); else hc.show() }
        function page(name: string): void { hc.showPage(name) }
        // für Tests: gerade gezeigte Unterseite ("" = Übersicht)
        function current(): string { return hc.open && ov.item ? ov.item.page : "" }
        function toggles(): string { return hc.toggles.join(",") }
    }
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
        ipc: false
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
        // offen halten, solange getippt wird oder eine Unterseite (z. B. WLAN-Passwort) offen ist
        holdOpen: item ? (item.typing || item.page !== "") : false
        onOpened: { hc.refresh(); if (ov.item) ov.item.page = hc.wantPage }

        content: Component {
            PanelContent {
                panel: hc
            }
        }
    }
}
