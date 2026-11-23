import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../common"

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
    readonly property real screenLen: vertical ? (screen ? screen.height : 1080) : (screen ? screen.width : 1920)
    readonly property int nIcons: entries.filter(o => o.kind !== "separator").length
    readonly property int nSeps: entries.length - nIcons
    readonly property int sepW: 1 + d.spacing
    function lengthFor(s) { return nIcons * s + Math.max(0, entries.length - 1) * d.spacing + nSeps * sepW + 2 * d.padding }
    readonly property real maxBody: Math.floor(screenLen * d.maxLength)
    readonly property int icon: nIcons === 0 ? d.iconSize
        : Math.max(d.iconMin, Math.min(d.iconSize, Math.floor((maxBody - lengthFor(0)) / nIcons)))
    readonly property real contentLen: lengthFor(icon)
    readonly property bool scrolls: contentLen > maxBody + 0.5
    readonly property real bodyLen: Math.min(maxBody, contentLen)
    readonly property int labelRoom: d.labels === "always" ? 16 : 0
    readonly property int thickness: icon + 2 * d.padding + labelRoom
    readonly property int radius: Math.min(d.radius, Math.floor(thickness / 2))
    readonly property int shadowPad: d.shadow === "none" ? 0 : d.shadow === "soft" ? 12 : d.shadow === "medium" ? 18 : 26
    readonly property int tipRoom: d.labels === "hover" ? (vertical ? 240 : 44) : 0
    readonly property int outward: Math.max(tipRoom, shadowPad)
    readonly property int sideRoom: Math.max(shadowPad, vertical ? 24 : 80)

    function geometry() {
        return { x: Math.round(body.x), y: Math.round(body.y), width: Math.round(body.width), height: Math.round(body.height),
                 windowWidth: width, windowHeight: height, icon: icon, scrolls: scrolls, radius: radius }
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
    visible: d.on && d.shown
    color: "transparent"
    exclusionMode: d.reserve ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: d.reserve ? d.margin + thickness : 0
    WlrLayershell.layer: d.topLayer ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "hypr-shell-dock"
    WlrLayershell.keyboardFocus: keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: body }

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
    readonly property bool popupOpen: popupMode !== ""
    function openPopup(target, mode, rows) {
        if (!rows || rows.length === 0) { closePopup(); return }
        popupTarget = target; popupRows = rows; popupMode = mode
        popup.selected = keyboard && mode === "menu" ? 0 : -1
    }
    function closePopup() { popupMode = ""; popupRows = []; popupTarget = null }
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
        openPopup(target, "menu", d.menuFor(item))
    }
    function windowList(item, target) {
        const w = item ? (item.windows || []) : []
        if (w.length < 2) return
        openPopup(target, "windows", w.map(t => ({ text: t.title || item.name, appIcon: item.icon, toplevel: t, run: () => t.activate() })))
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
        visible: win.d.labels === "hover" && win.hoverItem !== null && win.hoverText !== ""
        readonly property point c: win.hoverItem ? win.hoverItem.mapToItem(win.contentItem, win.hoverItem.width / 2, win.hoverItem.height / 2) : Qt.point(0, 0)
        width: tipText.implicitWidth + 20
        height: tipText.implicitHeight + 10
        radius: height / 2
        color: Theme.glass(0.82)
        border.width: 1
        border.color: Theme.glassBorder
        x: win.vertical ? (win.pos === "left" ? body.x + body.width + 10 : body.x - width - 10)
                        : Math.max(2, Math.min(win.width - width - 2, c.x - width / 2))
        y: win.vertical ? Math.max(2, Math.min(win.height - height - 2, c.y - height / 2))
                        : (win.pos === "bottom" ? body.y - height - 10 : body.y + body.height + 10)
        Txt {
            id: tipText
            anchors.centerIn: parent
            text: win.hoverText
            size: 12
        }
    }

    Item {
        id: body
        width: win.vertical ? win.thickness : win.bodyLen
        height: win.vertical ? win.bodyLen : win.thickness
        x: win.pos === "left" ? win.d.margin : win.pos === "right" ? parent.width - win.d.margin - width : Math.round((parent.width - width) / 2)
        y: win.pos === "top" ? win.d.margin : win.pos === "bottom" ? parent.height - win.d.margin - height : Math.round((parent.height - height) / 2)

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
        HoverHandler { onHoveredChanged: if (hovered) win.d.refreshFiles() }

        Rectangle {
            id: glass
            anchors.fill: parent
            radius: win.radius
            color: win.d.glassColor
            border.width: win.d.borderWidth
            border.color: win.d.borderColor
            Behavior on color { ColorAnimation { duration: 400 } }
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
                x: win.d.padding
                y: win.d.padding
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
