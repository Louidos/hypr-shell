import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import "../common"
import "verstecken.js" as V

// Ein Dock auf einem Bildschirm: Layer-Shell-Fenster an der Kante (dock.position), das Glas mittig
// mit dock.margin Abstand. Die Eingabefläche (mask) ist genau das sichtbare Glas, Klicks daneben
// gehen an die Fenster darunter. Zu viele Einträge: Symbole werden bis dock.icon_min_size kleiner,
// danach lässt sich das Dock mit dem Mausrad verschieben; länger als dock.max_length wird es nie.
PanelWindow {
    id: win
    property var dock
    readonly property var d: dock
    readonly property var dockWindow: win

    // Modell als Schlüssel (für ScriptModel: gleiche Schlüssel behalten ihre Symbole) + Daten
    readonly property var entries: d ? d.model(screen) : []
    readonly property var keys: entries.map(o => o.key)
    readonly property var byKey: {
        const m = {}
        for (let i = 0; i < entries.length; i++) m[entries[i].key] = entries[i]
        return m
    }

    // ---- Masse
    readonly property bool vertical: d.vertical
    readonly property string pos: d.position
    readonly property real screenLen: vertical ? Settings.screenHeight(screen) : Settings.screenWidth(screen)
    readonly property int nIcons: entries.filter(o => o.kind !== "separator").length
    readonly property int nSeps: entries.length - nIcons
    readonly property int sepW: 1 + d.spacing
    function lengthFor(s) { return nIcons * s + Math.max(0, entries.length - 1) * d.spacing + nSeps * sepW + 2 * d.padding }
    readonly property real maxBody: Math.floor(screenLen * d.maxLength)
    // Symbolgrösse mit dem Grössenfaktor dieses Bildschirms (1 im üblichen Bereich, 4K mit
    // Skalierung 1 grösser, 1280×720 etwas kleiner)
    ScreenFit { id: fitter; screen: win.screen }
    readonly property int baseIcon: Math.round(d.iconSize * fitter.factor)
    readonly property int baseMin: Math.min(baseIcon, Math.round(d.iconMin * fitter.factor))
    readonly property int icon: nIcons === 0 ? baseIcon
        : Math.max(baseMin, Math.min(baseIcon, Math.floor((maxBody - lengthFor(0)) / nIcons)))
    readonly property real contentLen: lengthFor(icon)
    readonly property bool scrolls: contentLen > maxBody + 0.5
    readonly property real bodyLen: Math.min(maxBody, contentLen)
    readonly property int labelRoom: d.labels === "always" ? 16 : 0
    readonly property int thickness: icon + 2 * d.padding + labelRoom
    readonly property int radius: Math.min(d.radius, Math.floor(thickness / 2))
    readonly property int shadowPad: d.shadow === "none" ? 0 : d.shadow === "soft" ? 12 : d.shadow === "medium" ? 18 : 26
    readonly property int tipRoom: d.labels === "hover" ? (vertical ? 240 : 44) : 0
    // Vergrösserung (nicht, wenn das Dock scrollt): Platz dafür ist im Fenster schon reserviert,
    // damit sich die Fenstergrösse beim Darüberfahren nicht ändert
    readonly property bool magnify: d.magnify && !scrolls
    readonly property real magExtra: magnify ? icon * (d.magnifyFactor - 1) : 0
    readonly property int outward: Math.max(tipRoom + magExtra, shadowPad)
    readonly property int sideRoom: Math.max(shadowPad, vertical ? 24 : 80) + Math.ceil(magExtra * 1.5)

    // Maus entlang des Docks (Fensterkoordinaten, -1 = nicht darüber); Mitte der Symbole in der
    // Grundgrösse, gemessen ab der Mitte des Fensters (bleibt beim Wachsen stehen)
    property real mouseAlong: -1
    readonly property var baseCenters: {
        const m = {}
        let x = d.padding
        for (let i = 0; i < shownKeys.length; i++) {
            const o = byKey[shownKeys[i]]
            const w = o && o.kind === "separator" ? sepW : icon
            m[shownKeys[i]] = x + w / 2 - contentLen / 2
            x += w + d.spacing
        }
        return m
    }
    // für Tests: Maus n Schritte über die ganze Länge führen, alle Symbole neu rechnen lassen
    function sweep(n) {
        const t0 = Date.now()
        const center = (vertical ? height : width) / 2
        for (let i = 0; i <= n; i++) {
            mouseAlong = center - contentLen / 2 + contentLen * i / Math.max(1, n)
            for (let j = 0; j < row.children.length; j++) { const c = row.children[j]; if (c.mag !== undefined) c.width }
        }
        mouseAlong = -1
        return Date.now() - t0
    }
    function magFor(key) {
        if (!magnify || mouseAlong < 0 || dragKey !== "" || baseCenters[key] === undefined) return 1
        const center = (vertical ? height : width) / 2
        const dist = Math.abs(mouseAlong - (center + baseCenters[key])) / (icon + d.spacing)
        const r = d.magnifyRange + 0.5
        if (dist >= r) return 1
        return 1 + (d.magnifyFactor - 1) * (Math.cos(Math.PI * dist / r) + 1) / 2
    }

    function geometry() {
        return { x: Math.round(body.x), y: Math.round(body.y), width: Math.round(body.width), height: Math.round(body.height),
                 windowWidth: width, windowHeight: height, icon: icon, scrolls: scrolls, radius: radius, hidden: hidden }
    }
    Component.onCompleted: { const l = d.windows.slice(); l.push(win); d.windows = l }
    Component.onDestruction: { if (d) d.windows = d.windows.filter(w => w !== win) }

    anchors {
        bottom: pos === "bottom"
        top: pos === "top"
        left: pos === "left"
        right: pos === "right"
    }
    implicitWidth: vertical ? d.margin + thickness + outward : Math.min(screenLen, bodyLen + 2 * sideRoom)
    implicitHeight: vertical ? Math.min(screenLen, bodyLen + 2 * sideRoom) : d.margin + thickness + outward
    // Vollbild oder Gaming-Modus (dock.hide_on_fullscreen): kein Dock, auch die Kante zeigt es nicht
    readonly property bool fullscreenHere: {
        if (!d.hideOnFullscreen) return false
        if (Ui.gaming) return true
        if (monitor && monitor.activeWorkspace && monitor.activeWorkspace.hasFullscreen === true) return true
        const tl = d.toplevels
        // ohne Hyprland (oder ohne hasFullscreen): ein Vollbild-Fenster auf diesem Bildschirm; unter
        // Hyprland nur das aktive, weil ein Vollbild auf einer anderen Arbeitsfläche nicht stört
        for (let i = 0; i < tl.length; i++)
            if (tl[i] && tl[i].fullscreen && (!Ui.hyprland || tl[i].activated) && d.onScreen(tl[i], screen)) return true
        return false
    }
    visible: d.on && d.shown && !fullscreenHere
    color: "transparent"
    // reserve: Fenster weichen aus. Leiste auf derselben Kante (dock.avoid_bar): das Dock beachtet
    // deren reservierten Platz (exclusive zone 0 = nichts reservieren, aber anderen ausweichen)
    exclusionMode: d.reserve || (d.avoidBar && d.barSameEdge) ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: d.reserve ? d.margin + thickness : 0
    readonly property string exclusionText: d.reserve ? "reserve" : d.avoidBar && d.barSameEdge ? "avoid" : "ignore"
    WlrLayershell.layer: d.topLayer ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "hypr-shell-dock"
    WlrLayershell.keyboardFocus: keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // ist ein Panel offen (Dashboard, Starter, Power-Menü …), nimmt das Dock keine Eingaben an
    readonly property bool inputOn: Ui.panel === "" || Ui.panel === "settings"
    mask: !inputOn ? noRegion : hidden ? edgeRegion : bodyRegion
    Region { id: bodyRegion; item: body }
    Region { id: edgeRegion; item: edgeStrip }
    Region { id: noRegion }

    // ---- Verstecken (dock.autohide): never, always (Maus geht), smart (ein Fenster überdeckt das Dock).
    // Versteckt bleibt ein schmaler, unsichtbarer Streifen an der Kante; Mauskontakt dort blendet
    // nach dock.show_delay_ms ein. Menü, Fensterliste, Ziehen, Tastatur und die offene Seite "Dock"
    // der Einstellungen halten es sichtbar.
    property bool hovering: false
    property bool revealed: false
    property bool hidden: false
    readonly property bool keepVisible: hovering || revealed || keyboard || popupOpen || dragKey !== ""
        || (Ui.settingsOpen && Ui.settingsPage === "dock")
    // Fläche des Docks auf dem Bildschirm (für smart)
    readonly property var screenRect: {
        const sx = screen ? screen.x : 0, sy = screen ? screen.y : 0
        const sw = Settings.screenWidth(screen), sh = Settings.screenHeight(screen)
        const wx = pos === "left" ? 0 : pos === "right" ? sw - width : (sw - width) / 2
        const wy = pos === "top" ? 0 : pos === "bottom" ? sh - height : (sh - height) / 2
        return { x: sx + wx + body.x, y: sy + wy + body.y, width: body.width, height: body.height }
    }
    readonly property var monitor: {
        if (!Ui.hyprland || !screen) return null
        const l = Hyprland.monitors.values
        for (let i = 0; i < l.length; i++) if (l[i].name === screen.name) return l[i]
        return null
    }
    readonly property bool overlapped: d.autohide === "smart" && Ui.hyprland && monitor !== null
        && V.ueberdeckt(screenRect, V.ausHyprland(Hyprland.toplevels.values, screen.name,
                        monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined))
    readonly property bool shouldHide: !keepVisible && (d.autohide === "always" || (d.autohide === "smart" && overlapped))
    onShouldHideChanged: {
        if (shouldHide) hideTimer.restart()
        else { hideTimer.stop(); if (!revealed || keepVisible) hidden = false }
    }
    onHoveringChanged: if (!hovering) revealed = false
    Timer { id: hideTimer; interval: win.d.hideDelay; onTriggered: if (win.shouldHide) win.hidden = true }
    Timer { id: showTimer; interval: win.d.showDelay; onTriggered: { win.revealed = true; win.hidden = false } }
    // Kante: schmaler Streifen über die Länge des Docks (nur versteckt ein Auslöser)
    Item {
        id: edgeStrip
        readonly property int t: 2
        x: win.vertical ? (win.pos === "left" ? 0 : win.width - t) : body.x
        y: win.vertical ? body.y : (win.pos === "top" ? 0 : win.height - t)
        width: win.vertical ? t : body.width
        height: win.vertical ? body.height : t
        MouseArea {
            anchors.fill: parent
            enabled: win.hidden
            hoverEnabled: true
            onEntered: showTimer.restart()
            onExited: showTimer.stop()
        }
    }
    // Die untere Kante gehört dem Dock, solange es dort versteckt ist oder über die Kante kam
    readonly property bool ownsEdge: pos === "bottom" && (hidden || revealed)

    // ---- Ziehen: Vorschau der neuen Reihenfolge, beim Loslassen speichern bzw. lösen
    property string dragKey: ""
    property int dragTo: -1
    property bool dragOut: false
    property point dragPos: Qt.point(0, 0)
    readonly property var shownKeys: {
        if (dragKey === "" || dragTo < 0 || dragOut) return keys
        const l = keys.filter(k => k !== dragKey)
        l.splice(Math.min(dragTo, l.length), 0, dragKey)
        return l
    }
    // Index in der Liste ohne den gezogenen Eintrag für einen Punkt im Fenster
    function dropIndex(p) {
        const local = row.mapFromItem(win.contentItem, p.x, p.y)
        const ks = keys.filter(k => k !== dragKey)
        let n = 0
        for (let i = 0; i < row.children.length; i++) {
            const c = row.children[i]
            if (!c.item || c.item.key === dragKey) continue
            const mid = vertical ? c.y + c.height / 2 : c.x + c.width / 2
            if ((vertical ? local.y : local.x) > mid) n++
        }
        return Math.min(n, ks.length)
    }
    function dragMove(key, p) {
        dragKey = key
        dragPos = p
        const b = body.mapToItem(win.contentItem, 0, 0)
        const away = pos === "bottom" ? b.y - p.y : pos === "top" ? p.y - (b.y + body.height)
                   : pos === "left" ? p.x - (b.x + body.width) : b.x - p.x
        const side = vertical ? Math.max(b.y - p.y, p.y - (b.y + body.height)) : Math.max(b.x - p.x, p.x - (b.x + body.width))
        dragOut = away > 50 || side > 50
        dragTo = dropIndex(p)
    }
    function dragEnd() {
        const it = byKey[dragKey]
        if (it) {
            if (dragOut) { if (it.pinned) d.unpin(it) }
            else {
                const order = shownKeys
                const i = order.indexOf(dragKey)
                const old = keys.indexOf(dragKey)
                if (i >= 0 && i !== old) {
                    // vor den Nachfolger bzw. hinter den Vorgänger in der neuen Reihenfolge
                    if (i + 1 < order.length) d.move(it, byKey[order[i + 1]], false)
                    else d.move(it, byKey[order[i - 1]], true)
                }
            }
        }
        dragKey = ""; dragTo = -1; dragOut = false
    }
    // Symbol am Mauszeiger beim Ziehen
    AppIcon {
        visible: win.dragKey !== ""
        z: 10
        size: win.icon
        width: win.icon; height: win.icon
        x: win.dragPos.x - win.icon / 2
        y: win.dragPos.y - win.icon / 2
        icon: win.byKey[win.dragKey] ? win.byKey[win.dragKey].icon : ""
        opacity: win.dragOut ? 0.45 : 0.9
    }

    // ---- Popups: Menü, Fensterliste, neueste Dateien
    property Item popupTarget: null
    property var popupRows: []
    property string popupMode: ""
    // Eintrag, zu dem das Popup gehört, und wie viele Fenster er beim Öffnen hatte
    property string popupKey: ""
    property int popupWindows: 0
    readonly property bool popupOpen: popupMode !== ""
    function openPopup(target, mode, rows, key) {
        if (!rows || rows.length === 0) { closePopup(); return }
        popupTarget = target; popupRows = rows; popupMode = mode
        popupKey = key || ""
        popupWindows = key && byKey[key] ? (byKey[key].windows || []).length : 0
        popup.selected = keyboard && mode === "menu" ? 0 : -1
    }
    function closePopup() { popupMode = ""; popupRows = []; popupTarget = null; popupKey = ""; popupWindows = 0 }
    // Ein Programm wurde geschlossen (oder geöffnet): Fensterliste ohne geschlossene Fenster (unter
    // zwei Fenstern zu), Menü eines Eintrags, dessen Fenster sich geändert haben, zu; das Symbol des
    // Popups ist weg (nicht angeheftetes Programm beendet) → zu. Die Tastatur-Auswahl springt auf
    // einen Eintrag, den es noch gibt. So bleibt kein Verweis auf ein geschlossenes Fenster übrig.
    function pruneClosed() {
        if (popupMode === "windows") {
            const r = popupRows.filter(x => d.alive(x.toplevel))
            if (r.length < 2) closePopup()
            else if (r.length !== popupRows.length) popupRows = r
        } else if (popupMode === "menu" && popupKey !== "") {
            const it = byKey[popupKey]
            if (!it || (it.windows || []).length !== popupWindows) closePopup()
        }
        if (keyboard && selectable.indexOf(selectedKey) < 0) selectedKey = selectable.length > 0 ? selectable[0] : ""
    }
    // nach jeder Änderung der Fenster (ToplevelManager) – erst wenn alle Bindungen den neuen Stand
    // haben (Qt.callLater), sonst prüfte die Bereinigung noch die alte Liste
    onEntriesChanged: Qt.callLater(win.pruneClosed)
    Connections { target: win.d; function onToplevelsChanged() { Qt.callLater(win.pruneClosed) } }
    onPopupTargetChanged: if (popupOpen && popupTarget === null) closePopup()
    // für Tests: Verweise auf Fenster, die es nicht mehr gibt (muss immer 0 sein)
    function staleRefs() {
        let n = 0
        for (let i = 0; i < popupRows.length; i++) if (popupRows[i].toplevel && !d.alive(popupRows[i].toplevel)) n++
        if (popupKey !== "" && !byKey[popupKey]) n++
        return n
    }
    DockPopup {
        id: popup
        // eigener Name: im Popup heissen die Eigenschaften selbst "win" und "dock"
        dock: dockWindow.d
        win: dockWindow
        target: dockWindow.popupTarget
        rows: dockWindow.popupRows
        mode: dockWindow.popupMode
        visible: dockWindow.popupOpen && dockWindow.popupTarget !== null && dockWindow.visible
        onDone: dockWindow.closePopup()
    }
    // Fensterliste schliesst, wenn die Maus weder auf dem Symbol noch auf der Liste ist
    property bool hoverAny: false
    Timer {
        id: popupLeave
        interval: 350
        running: win.popupMode === "windows" && !win.hoverAny && !popup.hovered
        onTriggered: win.closePopup()
    }
    function menu(item, target) {
        openPopup(target, "menu", d.menuFor(item), item ? item.key : "")
    }
    function windowList(item, target) {
        const w = item ? (item.windows || []).filter(t => d.alive(t)) : []
        if (w.length < 2) return
        openPopup(target, "windows", w.map(t => ({ text: t.title || item.name, appIcon: item.icon, toplevel: t,
                                                    run: () => { if (d.alive(t)) t.activate() } })), item.key)
    }
    property var filesFor: null
    Process {
        id: recentProc
        property Item target: null
        stdout: StdioCollector {
            onStreamFinished: {
                let l = []
                try { l = JSON.parse(text) } catch (e) { }
                win.openPopup(recentProc.target, "files", l.map(f => ({ text: f.name, icon: "󰈔",
                    run: () => Quickshell.execDetached([Settings.bin + "shell-dock", "file", f.path]) })))
            }
        }
    }
    function recentFiles(item, target) {
        recentProc.target = target
        recentProc.command = [Settings.bin + "shell-dock", "recent", item.path]
        recentProc.running = true
    }

    // ---- Tastatur (SUPER+B): Pfeile wählen, Enter startet, Menü/SHIFT+F10 öffnet das Menü, Esc verlässt
    property bool keyboard: false
    property string selectedKey: ""
    readonly property var selectable: keys.filter(k => byKey[k] && byKey[k].kind !== "separator")
    function startKeyboard() {
        keyboard = true
        if (selectable.indexOf(selectedKey) < 0) selectedKey = selectable.length > 0 ? selectable[0] : ""
        keys0.forceActiveFocus()
    }
    function stopKeyboard() { keyboard = false; closePopup() }
    function itemFor(key) {
        for (let i = 0; i < row.children.length; i++) if (row.children[i].item && row.children[i].item.key === key) return row.children[i]
        return null
    }
    function handleKey(k, shift) {
        if (!keyboard) return false
        const back = vertical ? "Up" : "Left", fwd = vertical ? "Down" : "Right"
        if (popupMode === "menu") {
            if (k === "Up" || k === back) popup.selected = Math.max(0, popup.selected - 1)
            else if (k === "Down" || k === fwd) popup.selected = Math.min(popupRows.length - 1, popup.selected + 1)
            else if (k === "Return" || k === "Enter" || k === "Space") popup.run(popup.selected)
            else if (k === "Escape") closePopup()
            else return false
            return true
        }
        const i = selectable.indexOf(selectedKey)
        if (k === back) selectedKey = selectable[Math.max(0, i - 1)] || selectedKey
        else if (k === fwd) selectedKey = selectable[Math.min(selectable.length - 1, i + 1)] || selectedKey
        else if (k === "Home") selectedKey = selectable[0] || ""
        else if (k === "End") selectedKey = selectable[selectable.length - 1] || ""
        else if (k === "Return" || k === "Enter" || k === "Space") { d.activate(byKey[selectedKey]); d.leaveFocus() }
        else if (k === "Menu" || (k === "F10" && shift)) { const t = itemFor(selectedKey); if (t) menu(byKey[selectedKey], t.iconItem) }
        else if (k === "Escape") d.leaveFocus()
        else return false
        return true
    }
    // für Tests: Taste wie von der Tastatur
    function testKey(name) {
        if (name !== "") handleKey(name === "ShiftF10" ? "F10" : name, name === "ShiftF10")
        if (!keyboard) return "off"
        const it = byKey[selectedKey]
        const shown = it && it.desktopId ? "app:" + it.desktopId : selectedKey
        return "on:" + shown + (popupMode !== "" ? ":" + popupMode : "")
    }
    Item {
        id: keys0
        focus: win.keyboard
        Keys.onPressed: event => {
            const names = {}
            names[Qt.Key_Left] = "Left"; names[Qt.Key_Right] = "Right"; names[Qt.Key_Up] = "Up"; names[Qt.Key_Down] = "Down"
            names[Qt.Key_Return] = "Return"; names[Qt.Key_Enter] = "Enter"; names[Qt.Key_Space] = "Space"
            names[Qt.Key_Menu] = "Menu"; names[Qt.Key_F10] = "F10"; names[Qt.Key_Escape] = "Escape"
            names[Qt.Key_Home] = "Home"; names[Qt.Key_End] = "End"
            const n = names[event.key]
            if (n && win.handleKey(n, (event.modifiers & Qt.ShiftModifier) !== 0)) event.accepted = true
        }
    }

    // Name des Symbols unter der Maus (dock.labels = hover), ausserhalb des Glases
    property var hoverItem: null
    property string hoverText: ""
    Rectangle {
        id: tip
        visible: win.d.labels === "hover" && win.hoverItem !== null && win.hoverText !== "" && !win.hidden
        readonly property point c: win.hoverItem ? win.hoverItem.mapToItem(win.contentItem, win.hoverItem.width / 2, win.hoverItem.height / 2) : Qt.point(0, 0)
        width: tipText.implicitWidth + 20
        height: tipText.implicitHeight + 10
        radius: height / 2
        color: Theme.glass(0.82)
        border.width: 1
        border.color: Theme.glassBorder
        x: win.vertical ? (win.pos === "left" ? Math.max(body.x + body.width, c.x + half) + 8 : Math.min(body.x, c.x - half) - width - 8)
                        : Math.max(2, Math.min(win.width - width - 2, c.x - width / 2))
        readonly property real half: win.hoverItem ? (win.vertical ? win.hoverItem.width : win.hoverItem.height) / 2 : 0
        y: win.vertical ? Math.max(2, Math.min(win.height - height - 2, c.y - height / 2))
                        : (win.pos === "bottom" ? Math.min(body.y, c.y - half) - height - 8 : Math.max(body.y + body.height, c.y + half) + 8)
        Txt {
            id: tipText
            anchors.centerIn: parent
            text: win.hoverText
            size: 12
        }
    }

    Item {
        id: body
        // Länge: wächst mit den vergrösserten Symbolen mit (nach beiden Seiten gleich)
        readonly property real len: win.scrolls ? win.bodyLen : Math.max(win.bodyLen, (win.vertical ? row.height : row.width) + 2 * win.d.padding)
        width: win.vertical ? win.thickness : len
        Probe { name: "dock-body" }
        height: win.vertical ? len : win.thickness
        x: win.pos === "left" ? win.d.margin : win.pos === "right" ? parent.width - win.d.margin - width : Math.round((parent.width - width) / 2)
        y: win.pos === "top" ? win.d.margin : win.pos === "bottom" ? parent.height - win.d.margin - height : Math.round((parent.height - height) / 2)
        // versteckt: hinaus über die Kante gleiten
        readonly property real away: win.hidden ? win.thickness + win.d.margin + win.shadowPad + 4 : 0
        transform: Translate {
            x: win.pos === "left" ? -body.away : win.pos === "right" ? body.away : 0
            y: win.pos === "top" ? -body.away : win.pos === "bottom" ? body.away : 0
            Behavior on x { NumberAnimation { duration: win.d.animMs; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: win.d.animMs; easing.type: Easing.OutCubic } }
        }
        HoverHandler {
            id: bodyHover
            onHoveredChanged: win.hovering = hovered
            onPointChanged: {
                if (!hovered) { win.mouseAlong = -1; return }
                const p = body.mapToItem(win.contentItem, point.position.x, point.position.y)
                win.mouseAlong = win.vertical ? p.y : p.x
            }
        }

        // Schatten: einige weiche Ränder um das Glas (ohne Effekt-Modul, läuft mit jedem Qt)
        Repeater {
            model: win.shadowPad > 0 ? 4 : 0
            Rectangle {
                required property int index
                readonly property real grow: (index + 1) * win.shadowPad / 4
                x: -grow; y: -grow + (win.pos === "top" ? 0 : win.shadowPad / 6)
                width: body.width + 2 * grow; height: body.height + 2 * grow
                radius: win.radius + grow
                color: "transparent"
                border.width: win.shadowPad / 4 + 1
                border.color: Qt.rgba(0, 0, 0, (win.d.shadow === "strong" ? 0.16 : win.d.shadow === "medium" ? 0.11 : 0.07) * (1 - index / 4))
            }
        }

        // Maus kommt aufs Dock: Ordner und Papierkorb neu prüfen (statt im Takt)
        HoverHandler { onHoveredChanged: if (hovered) win.d.refreshFiles(); else win.mouseAlong = -1 }

        Rectangle {
            id: glass
            anchors.fill: parent
            radius: win.radius
            color: win.d.glassColor
            border.width: win.d.borderWidth
            border.color: win.d.borderColor
            // Bildwechsel: Glas und Rand färben sanft um
            Behavior on color { ColorAnimation { duration: 400 } }
            Behavior on border.color { ColorAnimation { duration: 400 } }
        }

        Flickable {
            id: flick
            anchors.fill: parent
            clip: win.scrolls
            interactive: win.scrolls
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: win.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
            contentWidth: row.width + 2 * win.d.padding
            contentHeight: row.height + 2 * win.d.padding
            // Mausrad verschiebt ein volles Dock (auch quer zur Richtung)
            WheelHandler {
                enabled: win.scrolls
                onWheel: event => {
                    const delta = (event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x) / 2
                    if (win.vertical) flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - delta))
                    else flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - delta))
                }
            }

            Grid {
                id: row
                // Platzhalter-Animation beim Umsortieren
                move: Transition { NumberAnimation { properties: "x,y"; duration: win.d.animMs; easing.type: Easing.OutCubic } }
                // vergrösserte Symbole wachsen von der Kante weg
                verticalItemAlignment: win.pos === "top" ? Grid.AlignTop : win.pos === "bottom" ? Grid.AlignBottom : Grid.AlignVCenter
                horizontalItemAlignment: win.pos === "left" ? Grid.AlignLeft : win.pos === "right" ? Grid.AlignRight : Grid.AlignHCenter
                x: win.vertical && win.pos === "right" ? body.width - win.d.padding - width : win.d.padding
                y: !win.vertical && win.pos === "bottom" ? body.height - win.d.padding - height : win.d.padding
                columns: win.vertical ? 1 : Math.max(1, win.keys.length)
                rows: win.vertical ? Math.max(1, win.keys.length) : 1
                spacing: win.d.spacing
                Repeater {
                    model: ScriptModel { values: win.shownKeys }
                    DockItem {
                        required property var modelData
                        required property int index
                        // eigener Name: im Symbol heissen die Eigenschaften selbst "win" und "dock"
                        item: dockWindow.byKey[modelData] || null
                        dock: dockWindow.d
                        win: dockWindow
                        size: dockWindow.icon
                        selected: dockWindow.keyboard && dockWindow.selectedKey === modelData
                        dragging: dockWindow.dragKey === modelData
                    }
                }
            }
        }
    }
}
