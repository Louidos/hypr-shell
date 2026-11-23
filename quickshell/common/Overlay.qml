import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Gemeinsamer Baustein für alle Panels (Dashboard, Hot-Corner-Panel, Einstellungs-App, Starter, …):
// Name (IPC-Ziel und Eintrag in Ui.panel), Ort, Lader, Esc, Klick daneben, Schliessen beim Verlassen
// und eine einheitliche Animation.
//
//   place:     center | top | bottom | left | right | top-left | top-right | bottom-left | bottom-right
//   animation: slide (gleitet von der Kante herein), grow (wächst aus der Ecke), fade (Mitte)
//
// Immer nur ein Panel offen: exclusive = true (Standard) heisst, das Panel ist genau dann offen, wenn
// Ui.panel seinen Namen trägt – öffnet man ein anderes, schliesst dieses von selbst.
// Der Inhalt (content) wird erst beim Öffnen geladen und nach dem Schliessen wieder entladen; alles,
// was darin abfragt (Timer, Prozesse), läuft also nur, solange das Panel offen ist.
// "shell-quickshell ipc <name> open|close|toggle" öffnet und schliesst (ipc: false = eigene Befehle).
Scope {
    id: ov

    property string name: ""
    property string place: "center"
    property string animation: place === "center" ? "fade" : (place.indexOf("-") > 0 ? "grow" : "slide")
    property real panelWidth: 600
    property real panelHeight: 400
    // Abstand zur Bildschirmkante (bei center: Rand um die Fläche)
    property real margin: 12
    // über die ganze Höhe (Kanten links/rechts) bzw. Breite (oben/unten)
    property bool fill: false
    property bool glass: true
    property real radius: Theme.panelRadius
    property real glassOpacity: Theme.glassOpacity
    property bool exclusive: true
    property bool closeOnEscape: true
    property bool closeOnOutside: true
    property bool ipc: true
    property bool lazy: true
    property int keyboardFocus: WlrKeyboardFocus.Exclusive
    property int layer: WlrLayer.Top
    property string namespace: "hypr-shell-" + name
    property var screen: Settings.screenFor(Settings.get("desktop.screen", ""))
    property Component content: null
    // Schliessen, wenn die Maus das Panel verlässt (ms, -1 = nie); idleDelay: ohne Mausbesuch nach dem
    // Öffnen; holdOpen hält das Panel offen (z. B. während getippt wird)
    property int leaveDelay: -1
    property int idleDelay: -1
    property bool holdOpen: false

    // nicht exklusive Überlagerungen (Anzeigen, Karten) öffnen über localOpen
    property bool localOpen: false
    readonly property bool open: exclusive ? Ui.panel === name : localOpen
    readonly property alias t: win.t
    readonly property alias window: win
    readonly property var item: loader.item
    property bool entered: false
    signal opened()
    signal closed()

    function show() {
        if (exclusive) Ui.openPanel(name)
        else localOpen = true
    }
    function hide() {
        if (exclusive) Ui.closePanel(name)
        else localOpen = false
    }
    function toggle() { if (open) hide(); else show() }

    onOpenChanged: {
        if (open) {
            entered = false
            if (idleDelay >= 0) leaveTimer.restart()
            opened()
        } else {
            leaveTimer.stop()
            closed()
        }
    }

    IpcHandler {
        target: ov.name
        enabled: ov.ipc && ov.name !== ""
        function open(): void { ov.show() }
        function close(): void { ov.hide() }
        function toggle(): void { ov.toggle() }
    }

    // Klick daneben schliesst (Hyprland: Fokus-Griff, der sich beim Klick ausserhalb löst)
    HyprlandFocusGrab {
        active: ov.closeOnOutside && ov.open && win.visible && Ui.hyprland
        windows: [win]
        onCleared: ov.hide()
    }

    Timer {
        id: leaveTimer
        interval: ov.entered ? Math.max(0, ov.leaveDelay) : Math.max(0, ov.idleDelay)
        onTriggered: if (ov.open && !hov.hovered && !ov.holdOpen && (ov.entered ? ov.leaveDelay : ov.idleDelay) >= 0) ov.hide()
    }

    readonly property bool atTop: place === "top" || place.indexOf("top-") === 0
    readonly property bool atBottom: place === "bottom" || place.indexOf("bottom-") === 0
    readonly property bool atLeft: place === "left" || place.indexOf("-left") > 0
    readonly property bool atRight: place === "right" || place.indexOf("-right") > 0

    PanelWindow {
        id: win
        property real t: ov.open ? 1 : 0
        readonly property int inMs: ov.animation === "fade" ? 320 : ov.animation === "grow" ? 480 : 460
        readonly property int outMs: ov.animation === "fade" ? 180 : ov.animation === "grow" ? 260 : 280
        Behavior on t {
            NumberAnimation {
                duration: ov.open ? win.inMs : win.outMs
                easing.type: ov.animation === "fade" ? Easing.OutCubic : (ov.open ? Easing.OutQuint : Easing.InCubic)
            }
        }

        screen: ov.screen
        visible: ov.screen !== null && (ov.open || t > 0.001)
        anchors {
            top: ov.atTop || (ov.fill && (ov.atLeft || ov.atRight) && !ov.atBottom)
            bottom: ov.atBottom || (ov.fill && (ov.atLeft || ov.atRight) && !ov.atTop)
            left: ov.atLeft || (ov.fill && (ov.atTop || ov.atBottom) && !ov.atRight)
            right: ov.atRight || (ov.fill && (ov.atTop || ov.atBottom) && !ov.atLeft)
        }
        // Kantenpanels: Abstand zur Kante innerhalb des Fensters (wie bisher beim Dashboard);
        // Ecken: Abstand ringsum; Mitte: Rand ringsum
        readonly property bool edge: ov.animation === "slide"
        implicitWidth: ov.panelWidth + (edge ? ((ov.atLeft || ov.atRight) ? ov.margin : 0) : 2 * ov.margin)
        implicitHeight: ov.panelHeight + (edge ? ((ov.atTop || ov.atBottom) ? ov.margin : 0) : 2 * ov.margin)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: ov.layer
        WlrLayershell.namespace: ov.namespace
        WlrLayershell.keyboardFocus: ov.open ? ov.keyboardFocus : WlrKeyboardFocus.None
        mask: Region { item: body }

        onVisibleChanged: if (visible) keys.forceActiveFocus()

        Rectangle {
            id: body
            readonly property real fw: ov.fill && (ov.atTop || ov.atBottom) ? win.width : ov.panelWidth
            readonly property real fh: ov.fill && (ov.atLeft || ov.atRight) ? win.height - 2 * ov.margin : ov.panelHeight
            // Endlage im Fenster
            readonly property real x0: ov.animation === "slide" ? (ov.atLeft ? ov.margin : 0) : (win.width - width) / 2
            readonly property real y0: ov.animation === "slide"
                ? (ov.atTop ? ov.margin : ov.atBottom ? 0 : ov.margin)
                : (win.height - height) / 2

            width: ov.animation === "grow" ? fw * (0.55 + 0.45 * win.t) : fw
            height: ov.animation === "grow" ? Math.max(1, fh * win.t) : fh
            x: ov.animation === "grow" ? (ov.atRight ? win.width - width - ov.margin : ov.margin)
             : ov.animation === "slide" && (ov.atLeft || ov.atRight) ? x0 + (1 - win.t) * (fw + 24) * (ov.atLeft ? -1 : 1)
             : x0
            y: ov.animation === "grow" ? (ov.atBottom ? win.height - height - ov.margin : ov.margin)
             : ov.animation === "slide" && (ov.atTop || ov.atBottom) ? y0 + (1 - win.t) * (fh + 24) * (ov.atTop ? -1 : 1)
             : y0
            opacity: ov.animation === "grow" ? Math.min(1, win.t * 3) : ov.animation === "fade" ? win.t : Math.min(1, win.t * 2)
            scale: ov.animation === "fade" ? 0.97 + 0.03 * win.t : 1
            radius: ov.animation === "grow" ? Math.min(ov.radius, Math.min(width, height) / 2) : ov.radius
            color: ov.glass ? Theme.glass(ov.glassOpacity) : "transparent"
            border.width: ov.glass ? 1 : 0
            border.color: Theme.glassBorder
            clip: ov.animation === "grow"

            HoverHandler {
                id: hov
                onHoveredChanged: {
                    if (hovered) { ov.entered = true; leaveTimer.stop() }
                    else if (ov.open && ov.leaveDelay >= 0) leaveTimer.restart()
                }
            }

            FocusScope {
                id: keys
                focus: true
                // beim Wachsen aus der Ecke bleibt der Inhalt an der Ecke verankert
                width: body.fw
                height: body.fh
                x: ov.animation === "grow" && ov.atRight ? body.width - body.fw : 0
                y: ov.animation === "grow" && ov.atBottom ? body.height - body.fh : 0
                Keys.onEscapePressed: if (ov.closeOnEscape) ov.hide()

                Loader {
                    id: loader
                    anchors.fill: parent
                    focus: true
                    active: !ov.lazy || ov.open || win.t > 0.001
                    sourceComponent: ov.content
                    onLoaded: if (ov.open) keys.forceActiveFocus()
                }
            }
        }
    }
}
