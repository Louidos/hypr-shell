import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "fit.js" as F

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
//
// Grösse: panelWidth/panelHeight sind der Entwurf (bei 1080–1440 Pixeln kürzerer Bildschirmseite
// genau so gross). Auf dem Bildschirm des Panels wird der Entwurf mit dem Grössenfaktor (ScreenFit)
// skaliert und auf den freien Platz begrenzt: ohne Leiste und reserviertes Dock, mit Rand. Zu breit:
// der Inhalt bekommt die schmalere Breite (fitWidth). Zu hoch: der Inhalt rollt (scroll: true) oder
// bekommt die kleinere Höhe (scroll: false, für Inhalte, die selbst rollen; fitHeight).
Scope {
    id: ov

    property string name: ""
    property string place: "center"
    property string animation: place === "center" ? "fade" : (place.indexOf("-") > 0 ? "grow" : "slide")
    property real panelWidth: 600
    property real panelHeight: 400
    // zu hoher Inhalt rollt (false: der Inhalt bekommt die begrenzte Höhe und rollt selbst)
    property bool scroll: true
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
    // Grössen-Hilfe für den Bildschirm dieses Panels und der Grössenfaktor (überschreibbar)
    readonly property var fit: fitter
    property real uiScale: fitter.factor
    readonly property bool portrait: fitter.portrait
    property Component content: null
    // Schliessen, wenn die Maus das Panel verlässt (ms, -1 = nie); idleDelay: ohne Mausbesuch nach dem
    // Öffnen; holdOpen hält das Panel offen (z. B. während getippt wird)
    property int leaveDelay: -1
    property int idleDelay: -1
    property bool holdOpen: false
    // nimmt keine Klicks an (z. B. die Lautstärke-Anzeige)
    property bool clickThrough: false

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

    // als Panel anmelden (Ui.openPanel öffnet nur angemeldete Namen); verschwindet das Overlay, während
    // es offen ist (z. B. Missa wird abgeschaltet), wird Ui.panel frei
    Component.onCompleted: if (exclusive && name !== "") Ui.registerPanel(name)
    Component.onDestruction: { if (exclusive && name !== "") { Ui.unregisterPanel(name); Ui.setPanelArea(name, null) } Ui.setKeyboard(ov.namespace, false) }
    // offen, aber kein Fenster zu sehen (Bildschirm abgesteckt, kein Bildschirm): nach 1.5 s zu, damit
    // Ui.panel nicht hängen bleibt (das Dock nähme sonst keine Klicks mehr an)
    Timer {
        running: ov.open && !win.visible
        interval: 1500
        onTriggered: if (ov.open && !win.visible) ov.hide()
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

    ScreenFit { id: fitter; screen: ov.screen; forPanel: true }
    readonly property real k: uiScale > 0 ? uiScale : 1
    // Leiste und reserviertes Dock an den Kanten, an denen das Panel liegt (Bildschirmpixel)
    readonly property bool fillV: fill && (atLeft || atRight)
    readonly property bool fillH: fill && (atTop || atBottom)
    readonly property real insetTop: atTop || fillV ? fitter.top : 0
    readonly property real insetBottom: atBottom || fillV ? fitter.bottom : 0
    readonly property real insetLeft: atLeft || fillH ? fitter.left : 0
    readonly property real insetRight: atRight || fillH ? fitter.right : 0
    // freier Platz für das Panel (Bildschirmpixel); in der Mitte gleich viel Abstand oben und unten
    readonly property real gap: Math.max(8, margin)
    // Platz für das Leuchten des Rands (theme.border.glow) rund um Kantenpanels: ohne ihn läge der
    // Schein ausserhalb des Fensters (Ecken und Mitte haben dafür schon den Rand margin)
    readonly property real glowRoom: glass && Theme.glow && animation === "slide" ? Math.ceil(Theme.glowSize) : 0
    readonly property real roomW: fillH ? fitter.availWidth : fitter.availWidth - 2 * gap
    readonly property real roomH: place === "center"
        ? fitter.height - 2 * Math.max(fitter.top, fitter.bottom) - 2 * gap
        : fitter.availHeight - 2 * gap
    readonly property var fitted: F.panel(panelWidth, panelHeight, roomW, roomH, k)
    // Breite und Höhe, die der Inhalt bekommt (Entwurfseinheiten, vor dem Faktor)
    readonly property real fitWidth: fitted.w
    readonly property real fitHeight: fitted.h
    readonly property bool scrolls: scroll && fitted.scroll

    // Endlage der Fläche auf dem Bildschirm (ohne Animation), für das Dock (dock.when_panel_open):
    // überdeckt das offene Panel das Dock, fährt es weg oder legt sich dahinter
    readonly property var area: {
        if (!exclusive || !open || !win.visible || !ov.screen || clickThrough) return null
        const sw = fitter.width, sh = fitter.height, ww = win.width, wh = win.height
        const wx = win.anchors.left ? 0 : win.anchors.right ? sw - ww : (sw - ww) / 2
        const wy = win.anchors.top ? 0 : win.anchors.bottom ? sh - wh : (sh - wh) / 2
        const fw = body.fw, fh = body.fh
        const bx = animation === "grow" ? (atRight ? ww - fw - margin - insetRight : margin + insetLeft)
                 : animation === "fade" ? (ww - fw) / 2 : body.x0
        const by = animation === "grow" ? (atBottom ? wh - fh - margin - insetBottom : margin + insetTop)
                 : animation === "fade" ? (wh - fh) / 2 : body.y0
        return { screen: ov.screen.name, x: Math.round(wx + bx), y: Math.round(wy + by), width: Math.round(fw), height: Math.round(fh) }
    }
    onAreaChanged: if (exclusive && name !== "") Ui.setPanelArea(name, area)

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
        implicitWidth: ov.fitWidth * ov.k + (edge ? ((ov.atLeft || ov.atRight) ? ov.margin : 0) : 2 * ov.margin)
                       + ov.insetLeft + ov.insetRight + 2 * ov.glowRoom
        implicitHeight: ov.fitHeight * ov.k + (edge ? ((ov.atTop || ov.atBottom) ? ov.margin : 0) : 2 * ov.margin)
                        + ov.insetTop + ov.insetBottom + 2 * ov.glowRoom
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: ov.layer
        WlrLayershell.namespace: ov.namespace
        // Tastatur nur, solange das Panel offen UND sichtbar ist (nie bei einer unsichtbaren Fläche)
        readonly property bool wantsKeys: ov.open && visible && !ov.clickThrough && ov.keyboardFocus !== WlrKeyboardFocus.None
        WlrLayershell.keyboardFocus: wantsKeys ? ov.keyboardFocus : WlrKeyboardFocus.None
        onWantsKeysChanged: Ui.setKeyboard(ov.namespace, wantsKeys)
        mask: ov.clickThrough ? noInput : bodyInput
        Region { id: noInput }
        Region { id: bodyInput; item: body }

        onVisibleChanged: if (visible) keys.forceActiveFocus()

        // Leuchten des Rands (theme.border.glow): neben der Fläche statt darin, weil die Fläche beim
        // Wachsen aus der Ecke abschneidet (clip); folgt Lage, Grösse und Einblenden der Fläche
        Item {
            x: body.x; y: body.y; width: body.width; height: body.height
            opacity: body.opacity; scale: body.scale
            visible: ov.glass
            Glow { radius: body.radius }
        }
        Rectangle {
            id: body
            // Grösse auf dem Bildschirm (Bildschirmpixel)
            readonly property real fw: ov.fillH ? win.width - ov.insetLeft - ov.insetRight - 2 * ov.glowRoom : ov.fitWidth * ov.k
            readonly property real fh: ov.fillV ? win.height - 2 * ov.margin - ov.insetTop - ov.insetBottom - 2 * ov.glowRoom : ov.fitHeight * ov.k
            // Endlage im Fenster
            readonly property real x0: ov.animation === "slide"
                ? (ov.atLeft ? ov.margin + ov.insetLeft : ov.fillH ? ov.insetLeft : 0) + ov.glowRoom
                : (win.width - width) / 2
            readonly property real y0: ov.animation === "slide"
                ? (ov.atTop ? ov.margin + ov.insetTop : ov.atBottom ? 0 : ov.fillV ? ov.margin + ov.insetTop : 0) + ov.glowRoom
                : (win.height - height) / 2

            width: ov.animation === "grow" ? fw * (0.55 + 0.45 * win.t) : fw
            height: ov.animation === "grow" ? Math.max(1, fh * win.t) : fh
            x: ov.animation === "grow" ? (ov.atRight ? win.width - width - ov.margin - ov.insetRight : ov.margin + ov.insetLeft)
             : ov.animation === "slide" && (ov.atLeft || ov.atRight) ? x0 + (1 - win.t) * (fw + 24) * (ov.atLeft ? -1 : 1)
             : x0
            y: ov.animation === "grow" ? (ov.atBottom ? win.height - height - ov.margin - ov.insetBottom : ov.margin + ov.insetTop)
             : ov.animation === "slide" && (ov.atTop || ov.atBottom) ? y0 + (1 - win.t) * (fh + 24) * (ov.atTop ? -1 : 1)
             : y0
            opacity: ov.animation === "grow" ? Math.min(1, win.t * 3) : ov.animation === "fade" ? win.t : Math.min(1, win.t * 2)
            scale: ov.animation === "fade" ? 0.97 + 0.03 * win.t : 1
            radius: ov.animation === "grow" ? Math.min(ov.radius, Math.min(width, height) / 2) : ov.radius
            color: ov.glass ? Theme.glass(ov.glassOpacity) : "transparent"
            border.width: ov.glass ? Theme.borderWidth : 0
            border.color: Theme.glassBorder
            clip: ov.animation === "grow"

            // Lage auf dem Bildschirm für tests/bildschirmgroessen.sh (nur mit HYPR_SHELL_TEST=1)
            Probe { name: ov.name !== "" ? "overlay-" + ov.name : "" }

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
                // Inhalt in Entwurfseinheiten, mit dem Grössenfaktor skaliert; beim Wachsen aus der
                // Ecke bleibt er an der Ecke verankert
                width: body.fw / ov.k
                height: body.fh / ov.k
                scale: ov.k
                transformOrigin: Item.TopLeft
                x: ov.animation === "grow" && ov.atRight ? body.width - body.fw : 0
                y: ov.animation === "grow" && ov.atBottom ? body.height - body.fh : 0
                Keys.onEscapePressed: if (ov.closeOnEscape) ov.hide()

                // passt der Inhalt nicht in die Höhe, rollt er (statt abgeschnitten zu werden)
                Flickable {
                    id: scroller
                    anchors.fill: parent
                    interactive: ov.scrolls
                    clip: ov.scrolls
                    contentWidth: width
                    contentHeight: ov.scrolls ? ov.panelHeight : height
                    boundsBehavior: Flickable.StopAtBounds
                    onHeightChanged: if (!ov.scrolls) contentY = 0

                    Loader {
                        id: loader
                        width: scroller.width
                        height: scroller.contentHeight
                        focus: true
                        active: !ov.lazy || ov.open || win.t > 0.001
                        sourceComponent: ov.content
                        onLoaded: if (ov.open) keys.forceActiveFocus()
                    }
                }
            }
        }
    }
}
