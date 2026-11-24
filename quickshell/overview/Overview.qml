import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Fenster-Übersicht (SUPER+Tab): Raster der Arbeitsflächen mit ihren Fenstern an der richtigen Stelle.
// Vorschaubilder der Fenster (unter Hyprland, ScreencopyView), sonst App-Symbol und Titel.
// Klick wechselt zum Fenster, Ziehen auf eine andere Arbeitsfläche verschiebt es, Tippen filtert nach
// Titel (Enter springt zum ersten Treffer). Daten: shell-overview data (hyprctl -j), nur bei offenem Panel.
Scope {
    id: ow
    property var snap: ({ clients: [], workspaces: [], monitors: [], active: 1 })
    property string query: ""
    readonly property var wsIds: {
        const ids = []
        const n = Math.max(Settings.get("bar.workspaces", 4), 1)
        for (let i = 1; i <= n; i++) ids.push(i)
        for (const c of snap.clients) if (c.workspace && c.workspace.id > 0 && ids.indexOf(c.workspace.id) < 0) ids.push(c.workspace.id)
        for (const w of snap.workspaces) if (w.id > 0 && ids.indexOf(w.id) < 0) ids.push(w.id)
        return ids.sort((a, b) => a - b).slice(0, 10)
    }
    // Hochformat: höchstens zwei Arbeitsflächen nebeneinander
    readonly property int cols: Math.max(1, ov.portrait ? Math.min(2, wsIds.length) : wsIds.length <= 4 ? wsIds.length : Math.ceil(wsIds.length / 2))
    readonly property int rows: Math.ceil(wsIds.length / cols)
    readonly property var screen: Settings.screenFor(Settings.get("desktop.screen", ""))
    readonly property real sw: Settings.screenWidth(screen)
    readonly property real sh: Settings.screenHeight(screen)
    // Kacheln so gross, dass alle auf den freien Platz passen (Entwurfseinheiten des Overlay)
    readonly property real roomW: ov.roomW / ov.k
    readonly property real roomH: ov.roomH / ov.k
    readonly property real cellW: Math.max(80, Math.min(360, (roomW - 48 - (cols - 1) * 14) / cols,
        ((roomH - 24 - 44 - 18 - 24 - (rows - 1) * 14) / rows - 30) * sw / sh))
    readonly property real cellH: cellW * sh / sw

    function matches(c) {
        const q = query.trim().toLowerCase()
        return q === "" || (c.title || "").toLowerCase().indexOf(q) >= 0 || (c.class || "").toLowerCase().indexOf(q) >= 0
    }
    function clientsOn(id) { return snap.clients.filter(c => c.workspace && c.workspace.id === id) }
    function monitorOf(id) {
        const w = snap.workspaces.find(x => x.id === id)
        const mid = w ? w.monitorID : (snap.monitors.length > 0 ? snap.monitors[0].id : 0)
        const m = snap.monitors.find(x => x.id === mid) || snap.monitors[0]
        if (!m) return { x: 0, y: 0, w: sw, h: sh }
        const s = m.scale || 1
        return { x: m.x || 0, y: m.y || 0, w: (m.width || sw) / s, h: (m.height || sh) / s }
    }
    function focus(c) {
        ov.hide()
        Quickshell.execDetached([Settings.bin + "shell-overview", "focus", c.address])
    }
    function move(c, id) {
        if (!c.workspace || c.workspace.id === id) return
        Quickshell.execDetached([Settings.bin + "shell-overview", "move", c.address, String(id)])
        // sofort zeigen, die echten Daten folgen
        const d = Object.assign({}, snap)
        d.clients = snap.clients.map(x => x.address === c.address ? Object.assign({}, x, { workspace: { id: id, name: String(id) } }) : x)
        snap = d
        refresh.restart()
    }
    function reload() { dataProc.running = true }

    Process {
        id: dataProc
        command: [Settings.bin + "shell-overview", "data"]
        stdout: StdioCollector { onStreamFinished: { try { ow.snap = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: refresh; interval: 400; onTriggered: ow.reload() }

    IpcHandler {
        target: "overview"
        function open(): void { ov.show() }
        function close(): void { ov.hide() }
        function toggle(): void { ov.toggle() }
        // für Tests: "Arbeitsfläche:Titel" je Fenster, wie die Übersicht sie zeigt
        function windows(): string { return ow.snap.clients.map(c => c.workspace.id + ":" + c.title).join("\n") }
        function focusFirst(): void { const c = ow.snap.clients.find(x => ow.matches(x)); if (c) ow.focus(c) }
        function moveFirst(id: int): void { if (ow.snap.clients.length > 0) ow.move(ow.snap.clients[0], id) }
        function filter(text: string): int { ow.query = text; return ow.snap.clients.filter(c => ow.matches(c)).length }
    }

    Overlay {
        id: ov
        name: "overview"
        ipc: false
        place: "center"
        margin: 0
        screen: ow.screen
        panelWidth: ow.cols * ow.cellW + (ow.cols - 1) * 14 + 48
        panelHeight: 24 + 44 + 18 + ow.rows * (ow.cellH + 30) + (ow.rows - 1) * 14 + 24
        keyboardFocus: WlrKeyboardFocus.Exclusive
        onOpened: { ow.query = ""; ow.reload() }

        content: Component {
            Item {
                id: root
                focus: true
                property var dragged: null
                property point dragPos: Qt.point(0, 0)

                Rectangle {
                    id: box
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.pad(24) }
                    width: Math.min(420, parent.width - 48)
                    height: 44
                    radius: 22
                    color: Theme.field
                    border.width: 1
                    border.color: Theme.cardBorder
                    Glyph { id: lens; anchors { left: parent.left; leftMargin: Theme.pad(16); verticalCenter: parent.verticalCenter } text: ""; size: 13; color: Theme.subtext }
                    TextInput {
                        id: field
                        anchors { left: lens.right; leftMargin: Theme.pad(10); right: parent.right; rightMargin: Theme.pad(16); verticalCenter: parent.verticalCenter }
                        focus: true
                        color: Theme.text
                        font.family: Theme.sans
                        font.pixelSize: 14 * Theme.fontScale
                        clip: true
                        onTextChanged: ow.query = text
                        Keys.onReturnPressed: { const c = ow.snap.clients.find(x => ow.matches(x)); if (c) ow.focus(c) }
                        Keys.onEnterPressed: { const c = ow.snap.clients.find(x => ow.matches(x)); if (c) ow.focus(c) }
                        Txt { visible: field.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "Type to filter windows"; size: 14; sub: true }
                    }
                }

                Grid {
                    id: grid
                    anchors { horizontalCenter: parent.horizontalCenter; top: box.bottom; topMargin: Theme.pad(18) }
                    columns: ow.cols
                    spacing: Theme.pad(14)
                    Repeater {
                        id: cells
                        model: ow.wsIds
                        delegate: Column {
                            id: cell
                            required property int modelData
                            readonly property int wsId: modelData
                            property alias frameItem: frame
                            readonly property var mon: ow.monitorOf(wsId)
                            readonly property bool hot: root.dragged !== null && frame.contains(frame.mapFromItem(root, root.dragPos.x, root.dragPos.y))
                            spacing: Theme.pad(6)
                            Rectangle {
                                id: frame
                                width: ow.cellW
                                height: ow.cellH
                                radius: 14
                                clip: true
                                color: cell.hot ? Theme.cardHover : Theme.card
                                border.width: ow.snap.active === cell.wsId || cell.hot ? 2 : 1
                                border.color: ow.snap.active === cell.wsId ? Theme.accent : (cell.hot ? Theme.text : Theme.cardBorder)
                                Repeater {
                                    model: ow.clientsOn(cell.wsId)
                                    delegate: Rectangle {
                                        id: win
                                        required property var modelData
                                        readonly property real k: ow.cellW / cell.mon.w
                                        readonly property bool hit: ow.matches(modelData)
                                        x: Math.max(0, ((modelData.at ? modelData.at[0] : 0) - cell.mon.x) * k)
                                        y: Math.max(0, ((modelData.at ? modelData.at[1] : 0) - cell.mon.y) * k)
                                        width: Math.max(24, (modelData.size ? modelData.size[0] : 400) * k)
                                        height: Math.max(18, (modelData.size ? modelData.size[1] : 300) * k)
                                        radius: 8
                                        color: Qt.rgba(1, 1, 1, wh.hovered ? 0.16 : 0.09)
                                        border.width: 1
                                        border.color: Theme.glassBorder
                                        opacity: (hit ? 1 : 0.25) * (root.dragged === modelData ? 0.4 : 1)
                                        z: modelData.floating ? 2 : 1
                                        Column {
                                            anchors.centerIn: parent
                                            width: parent.width - 8
                                            spacing: Theme.pad(2)
                                            AppIcon {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                size: Math.min(28, win.height * 0.45)
                                                icon: (win.modelData.class || "").toLowerCase()
                                            }
                                            Txt {
                                                width: parent.width
                                                visible: win.height > 44
                                                horizontalAlignment: Text.AlignHCenter
                                                text: win.modelData.title || win.modelData.class || ""
                                                size: 10
                                            }
                                        }
                                        // Vorschau des Fensterinhalts (nur unter Hyprland; sonst bleibt Symbol und Titel)
                                        Loader {
                                            anchors.fill: parent
                                            active: Ui.hyprland
                                            source: "Preview.qml"
                                            onLoaded: item.address = win.modelData.address
                                        }
                                        HoverHandler { id: wh; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: ow.focus(win.modelData) }
                                        DragHandler {
                                            target: null
                                            onActiveChanged: {
                                                if (active) root.dragged = win.modelData
                                                else {
                                                    const p = root.dragPos
                                                    for (let i = 0; i < cells.count; i++) {
                                                        const c = cells.itemAt(i)
                                                        const f = c.frameItem
                                                        if (f.contains(f.mapFromItem(root, p.x, p.y))) { ow.move(win.modelData, c.wsId); break }
                                                    }
                                                    root.dragged = null
                                                }
                                            }
                                            onCentroidChanged: if (active) root.dragPos = win.mapToItem(root, centroid.position.x, centroid.position.y)
                                        }
                                    }
                                }
                            }
                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Workspace " + cell.wsId + (ow.clientsOn(cell.wsId).length > 0 ? "  ·  " + ow.clientsOn(cell.wsId).length : "")
                                size: 12
                                sub: ow.snap.active !== cell.wsId
                                strong: ow.snap.active === cell.wsId
                            }
                        }
                    }
                }

                // gezogenes Fenster folgt der Maus
                Rectangle {
                    visible: root.dragged !== null
                    x: root.dragPos.x - width / 2
                    y: root.dragPos.y - height / 2
                    width: 120; height: 34
                    radius: 10
                    color: Theme.pill
                    Txt {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                        text: root.dragged ? (root.dragged.title || root.dragged.class || "") : ""
                        size: 11
                        color: Theme.pillText
                    }
                }
            }
        }
    }
}
