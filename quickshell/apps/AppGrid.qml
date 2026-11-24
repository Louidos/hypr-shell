import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// App-Raster (wie Start-Menü/Launchpad): alle Apps als Symbole im Glas-Raster, oben Suche, Kategorien,
// Favoriten und zuletzt benutzte Apps. Öffnen: SUPER allein antippen, Knopf im Dock, Logo in der Leiste
// oder "shell-quickshell ipc apps toggle".
//   Tippen sucht sofort, Pfeile wählen, Enter startet, Esc schliesst, Menü-Taste/SHIFT+F10 = Menü.
//   Rechtsklick: im Dock anheften/lösen, Favorit an/aus, neues Fenster.
// Nach dem Start schliesst das Raster und gibt die Tastatur frei (Overlay: Tastatur nur, solange offen).
// Zuletzt benutzt: dieselbe Datei wie der Starter (launcher-recent.json), Favoriten: appraster.favoriten.
Scope {
    id: ag
    readonly property bool on: Settings.get("appraster.enabled", true) === true
    readonly property bool showCategories: Settings.get("appraster.kategorien", true) === true
    readonly property int recentMax: Math.max(0, Number(Settings.get("appraster.zuletzt", 8)) || 0)
    readonly property var favorites: {
        const v = Settings.get("appraster.favoriten", [])
        return Array.isArray(v) ? v.map(String).filter(x => x !== "") : []
    }

    property string query: ""
    property string category: "all"
    property int sel: 0
    property var recent: ({})
    // Menü (Rechtsklick): App und Lage
    property var menuApp: null
    property real menuX: 0
    property real menuY: 0

    // ---- Kategorien nach freedesktop (Hauptkategorien), feste Reihenfolge
    readonly property var catNames: ({ internet: "Internet", office: "Office", media: "Media", graphics: "Graphics",
                                       games: "Games", development: "Development", education: "Education",
                                       science: "Science", settings: "Settings", system: "System",
                                       utilities: "Utilities", other: "Other" })
    readonly property var catOrder: ["internet", "office", "media", "graphics", "games", "development", "education",
                                     "science", "utilities", "settings", "system", "other"]
    function categoryOf(e) {
        const c = (e.categories || []).map(String)
        const has = n => c.indexOf(n) >= 0
        if (has("Game")) return "games"
        if (has("Development")) return "development"
        if (has("AudioVideo") || has("Audio") || has("Video")) return "media"
        if (has("Graphics")) return "graphics"
        if (has("Network")) return "internet"
        if (has("Office")) return "office"
        if (has("Education")) return "education"
        if (has("Science")) return "science"
        if (has("Settings")) return "settings"
        if (has("System")) return "system"
        if (has("Utility")) return "utilities"
        return "other"
    }

    readonly property var apps: DesktopEntries.applications.values.filter(e => e && !e.noDisplay)
        .slice().sort((a, b) => String(a.name).localeCompare(String(b.name)))
    function byId(id) {
        const l = ag.apps
        for (let i = 0; i < l.length; i++) if (l[i].id === id) return l[i]
        return null
    }
    readonly property var categories: {
        const seen = {}
        for (let i = 0; i < apps.length; i++) seen[categoryOf(apps[i])] = true
        return catOrder.filter(c => seen[c])
    }
    readonly property var favoriteApps: favorites.map(id => byId(id)).filter(e => e !== null)
    readonly property var recentApps: {
        if (recentMax <= 0) return []
        return apps.filter(e => recent[e.id] && favorites.indexOf(e.id) < 0)
            .sort((a, b) => recent[b.id] - recent[a.id]).slice(0, recentMax)
    }
    // Favoriten und Zuletzt nur ohne Suche in "All"
    readonly property bool home: query.trim() === "" && category === "all"

    // höher = besser; 0 = passt nicht (wie im Starter)
    function score(e, q) {
        const n = String(e.name || "").toLowerCase()
        let s = 0
        if (n.indexOf(q) === 0) s = 100
        else if (n.split(/[\s\-_.]+/).some(w => w.indexOf(q) === 0)) s = 80
        else if (n.indexOf(q) >= 0) s = 60
        else if ((String(e.genericName || "") + " " + (e.keywords || []).join(" ")).toLowerCase().indexOf(q) >= 0) s = 40
        else if (String(e.comment || "").toLowerCase().indexOf(q) >= 0) s = 20
        if (s > 0 && ag.recent[e.id]) s += 30
        return s
    }
    readonly property var results: {
        const q = query.trim().toLowerCase()
        const l = category === "all" ? apps
                : category === "favorites" ? favoriteApps
                : apps.filter(e => categoryOf(e) === category)
        if (q === "") return l
        const zuletzt = e => ag.recent[e.id] || 0
        return l.map(e => ({ e: e, s: score(e, q) })).filter(x => x.s > 0)
            .sort((a, b) => (b.s - a.s) || (zuletzt(b.e) - zuletzt(a.e)) || String(a.e.name).localeCompare(String(b.e.name)))
            .map(x => x.e)
    }
    onQueryChanged: sel = 0
    onCategoryChanged: sel = 0

    // ---- zuletzt benutzt: gemeinsam mit dem Starter
    function remember(id) {
        const r = Object.assign({}, recent)
        r[id] = Date.now()
        const ids = Object.keys(r).sort((a, b) => r[b] - r[a])
        for (let i = 50; i < ids.length; i++) delete r[ids[i]]
        recent = r
        store.setText(JSON.stringify(r))
    }
    FileView {
        id: store
        path: Settings.dataDir + "/launcher-recent.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { const r = JSON.parse(text()); if (r && typeof r === "object") ag.recent = r } catch (e) { } }
        onLoadFailed: ag.recent = ({})
    }

    // ---- Aktionen
    function launch(e) {
        if (!e) return ""
        const n = String(e.name)
        menuApp = null
        ov.hide()            // zuerst zu: die Tastatur ist frei, bevor die App ihr Fenster zeigt
        remember(e.id)
        e.execute()
        return n
    }
    function launchSelected() { return results.length > 0 ? launch(results[Math.max(0, Math.min(sel, results.length - 1))]) : "" }
    // "New window": Aktion new-window der App, sonst die App noch einmal starten
    function newWindow(e) {
        if (!e) return
        const acts = e.actions || []
        for (let i = 0; i < acts.length; i++) {
            if (/^new[-_]?window$/i.test(String(acts[i].id))) { menuApp = null; ov.hide(); remember(e.id); acts[i].execute(); return }
        }
        launch(e)
    }
    function isFavorite(id) { return favorites.indexOf(id) >= 0 }
    function toggleFavorite(id) {
        if (!id) return false
        const l = favorites.slice()
        const i = l.indexOf(id)
        if (i >= 0) l.splice(i, 1); else l.push(id)
        Ui.set("appraster.favoriten", l)
        return i < 0
    }
    readonly property var dockItems: {
        const v = Settings.get("dock.items", [{"type": "app", "desktop_id": "org.gnome.Nautilus", "path": ""}, {"type": "app", "desktop_id": "kitty", "path": ""}, {"type": "app", "desktop_id": "firefox", "path": ""}, {"type": "separator", "desktop_id": "", "path": ""}, {"type": "folder", "desktop_id": "", "path": "~/Downloads"}, {"type": "separator", "desktop_id": "", "path": ""}, {"type": "trash", "desktop_id": "", "path": ""}])
        return Array.isArray(v) ? v.filter(i => i && typeof i === "object") : []
    }
    function isPinned(id) { return dockItems.some(i => i.type === "app" && i.desktop_id === id) }
    // im Dock anheften (hinter der letzten App) oder lösen – derselbe Wert wie im Dock (dock.items)
    function togglePin(id) {
        if (!id) return false
        const l = dockItems.slice()
        const i = l.findIndex(x => x.type === "app" && x.desktop_id === id)
        if (i >= 0) { l.splice(i, 1); Ui.set("dock.items", l); return false }
        let at = 0
        for (let k = 0; k < l.length; k++) if (l[k].type === "app" || l[k].type === "launcher") at = k + 1
        l.splice(at, 0, { type: "app", desktop_id: id, path: "" })
        Ui.set("dock.items", l)
        return true
    }
    function menuEntries(e) {
        if (!e) return []
        return [
            { text: "Open", icon: "󰐊", run: () => ag.launch(e) },
            { text: "New window", icon: "󰖯", run: () => ag.newWindow(e) },
            { text: ag.isPinned(e.id) ? "Remove from Dock" : "Pin to Dock", icon: ag.isPinned(e.id) ? "󰐄" : "󰐃",
              run: () => { ag.togglePin(e.id); ag.menuApp = null } },
            { text: ag.isFavorite(e.id) ? "Remove from favorites" : "Add to favorites", icon: ag.isFavorite(e.id) ? "󰓒" : "󰓎",
              run: () => { ag.toggleFavorite(e.id); ag.menuApp = null } }
        ]
    }
    function openMenu(e, x, y) { menuApp = e; menuX = x; menuY = y }

    function setQuery(text) {
        query = text
        if (ov.item) ov.item.input.text = text
    }
    function move(d) {
        if (results.length === 0) return
        sel = Math.max(0, Math.min(results.length - 1, sel + d))
    }

    IpcHandler {
        target: "apps"
        enabled: ag.on
        function open(): void { ov.show() }
        function close(): void { ov.hide() }
        function toggle(): void { ov.toggle() }
        // Suche setzen und die erste App nennen (für Tests und Skripte)
        function search(text: string): string { ag.setQuery(text); return ag.results.length > 0 ? String(ag.results[0].name) : "" }
        function category(name: string): string { ag.category = name; return ag.results.map(e => e.id).join("|") }
        function categories(): string { return ag.categories.join("|") }
        // "open:Auswahl:Anzahl:Kategorie" bzw. "closed"
        function state(): string { return ov.open ? "open:" + ag.sel + ":" + ag.results.length + ":" + ag.category : "closed" }
        function select(index: int): void { ag.sel = index }
        function launch(): string { return ag.launchSelected() }
        function favorite(id: string): bool { return ag.toggleFavorite(id) }
        function favorites(): string { return ag.favoriteApps.map(e => e.id).join("|") }
        function recent(): string { return ag.recentApps.map(e => e.id).join("|") }
        function pin(id: string): bool { return ag.togglePin(id) }
        // für Tests: so, wie das Raster dock.items gerade sieht (nach einer Änderung kurz verzögert)
        function pinned(id: string): bool { return ag.isPinned(id) }
        // Menü der gewählten App: Einträge, "|" getrennt
        function menu(): string {
            const e = ag.results[ag.sel]
            if (!e) return ""
            ag.openMenu(e, 200, 200)
            return ag.menuEntries(e).map(m => m.text).join("|")
        }
    }

    Overlay {
        id: ov
        name: "apps"
        ipc: false
        place: "center"
        margin: 0
        panelWidth: 860
        panelHeight: 640
        scroll: false
        glassOpacity: Theme.glassOpacity
        keyboardFocus: WlrKeyboardFocus.Exclusive
        onOpened: { ag.query = ""; ag.category = "all"; ag.sel = 0; ag.menuApp = null; if (ov.item) ov.item.input.text = "" }
        onClosed: ag.menuApp = null

        content: Component {
            Item {
                id: root
                property alias input: field
                focus: true
                readonly property real cell: 116

                // ---- Suchfeld
                Rectangle {
                    id: box
                    x: 18; y: 18
                    width: parent.width - 36
                    height: 46
                    radius: 23
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Theme.cardBorder
                    Glyph {
                        id: lens
                        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                        text: ""
                        size: 15
                        color: Theme.subtext
                    }
                    TextInput {
                        id: field
                        anchors { left: lens.right; leftMargin: 12; right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        focus: true
                        color: Theme.text
                        font.family: Theme.sans
                        font.pixelSize: 16 * Theme.fontScale
                        clip: true
                        onTextChanged: ag.query = text
                        Keys.onPressed: event => {
                            const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth))
                            if (ag.menuApp && event.key === Qt.Key_Escape) { ag.menuApp = null; event.accepted = true }
                            else if (event.key === Qt.Key_Right) { ag.move(1); event.accepted = true }
                            else if (event.key === Qt.Key_Left) { ag.move(-1); event.accepted = true }
                            else if (event.key === Qt.Key_Down) { ag.move(cols); event.accepted = true }
                            else if (event.key === Qt.Key_Up) { ag.move(-cols); event.accepted = true }
                            else if (event.key === Qt.Key_Tab) { ag.move(1); event.accepted = true }
                            else if (event.key === Qt.Key_Backtab) { ag.move(-1); event.accepted = true }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { ag.launchSelected(); event.accepted = true }
                            else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
                                const it = grid.currentItem
                                if (it && ag.results[ag.sel]) {
                                    const p = it.mapToItem(root, it.width / 2, it.height / 2)
                                    ag.openMenu(ag.results[ag.sel], p.x, p.y)
                                }
                                event.accepted = true
                            }
                        }
                        Txt {
                            visible: field.text.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Type to search apps"
                            size: 16
                            sub: true
                        }
                    }
                }

                // ---- Kategorien
                Flickable {
                    id: chips
                    visible: ag.showCategories
                    x: 18
                    anchors { top: box.bottom; topMargin: 12 }
                    width: parent.width - 36
                    height: visible ? 30 : 0
                    contentWidth: chipRow.width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: chipRow
                        spacing: 6
                        Repeater {
                            model: ["all"].concat(ag.favoriteApps.length > 0 ? ["favorites"] : []).concat(ag.categories)
                            delegate: Pill {
                                required property string modelData
                                text: modelData === "all" ? "All" : modelData === "favorites" ? "Favorites" : (ag.catNames[modelData] || modelData)
                                active: ag.category === modelData
                                onClicked: ag.category = modelData
                            }
                        }
                    }
                }

                // ---- Raster (oben Favoriten und zuletzt benutzt, wenn nichts gesucht wird)
                GridView {
                    id: grid
                    x: 18
                    anchors { top: chips.bottom; topMargin: 12; bottom: parent.bottom; bottomMargin: 14 }
                    width: parent.width - 36
                    clip: true
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / root.cell)))
                    cellHeight: root.cell
                    model: ag.results
                    currentIndex: ag.sel
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                    boundsBehavior: Flickable.StopAtBounds
                    header: Column {
                        width: grid.width
                        visible: ag.home
                        height: ag.home ? implicitHeight : 0
                        spacing: 6
                        Repeater {
                            model: ag.home ? [{ title: "Favorites", list: ag.favoriteApps }, { title: "Recent", list: ag.recentApps }].filter(s => s.list.length > 0) : []
                            delegate: Column {
                                required property var modelData
                                width: grid.width
                                spacing: 4
                                Txt { text: modelData.title; size: 12; sub: true; weight: Font.DemiBold; leftPadding: 6 }
                                Flow {
                                    width: parent.width
                                    Repeater {
                                        model: modelData.list
                                        delegate: AppTile {
                                            id: ht
                                            required property var modelData
                                            entry: modelData
                                            width: grid.cellWidth
                                            height: root.cell
                                            favorite: ag.isFavorite(modelData.id)
                                            onLaunch: ag.launch(modelData)
                                            onNewWindow: ag.newWindow(modelData)
                                            onMenu: (x, y) => { const p = ht.mapToItem(root, x, y); ag.openMenu(modelData, p.x, p.y) }
                                        }
                                    }
                                }
                            }
                        }
                        Item {
                            visible: ag.favoriteApps.length > 0 || ag.recentApps.length > 0
                            width: grid.width; height: visible ? 26 : 0
                            Txt { anchors.bottom: parent.bottom; text: "All apps"; size: 12; sub: true; weight: Font.DemiBold; leftPadding: 6 }
                        }
                    }
                    delegate: AppTile {
                        id: gt
                        required property var modelData
                        required property int index
                        entry: modelData
                        width: grid.cellWidth
                        height: grid.cellHeight
                        selected: index === ag.sel
                        favorite: ag.isFavorite(modelData.id)
                        onHovered: ag.sel = index
                        onLaunch: ag.launch(modelData)
                        onNewWindow: ag.newWindow(modelData)
                        onMenu: (x, y) => { const p = gt.mapToItem(root, x, y); ag.openMenu(modelData, p.x, p.y) }
                        Probe { name: gt.index === 0 ? "apps-first" : "" }
                    }
                    Txt {
                        anchors.centerIn: parent
                        visible: ag.results.length === 0
                        text: "No apps found"
                        sub: true
                    }
                }

                // ---- Menü (Rechtsklick, Menü-Taste)
                MouseArea {
                    anchors.fill: parent
                    visible: ag.menuApp !== null
                    onClicked: ag.menuApp = null
                }
                Rectangle {
                    id: menu
                    visible: ag.menuApp !== null
                    width: 220
                    height: menuCol.height + 12
                    x: Math.min(Math.max(8, ag.menuX), root.width - width - 8)
                    y: Math.min(Math.max(8, ag.menuY), root.height - height - 8)
                    radius: Theme.cardRadius
                    color: Theme.glass(0.95)
                    border.width: Theme.borderWidth
                    border.color: Theme.cardBorder
                    Column {
                        id: menuCol
                        x: 6; y: 6
                        width: parent.width - 12
                        Repeater {
                            model: ag.menuEntries(ag.menuApp)
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: menuCol.width
                                height: 34
                                radius: 8
                                color: mh.hovered ? Theme.cardHover : "transparent"
                                Glyph { id: mi; x: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.icon; size: 14; color: Theme.subtext }
                                Txt {
                                    anchors.left: mi.right
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.modelData.text
                                    size: 13
                                }
                                HoverHandler { id: mh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: parent.modelData.run() }
                                Probe { name: "apps-menu-" + parent.index }
                            }
                        }
                    }
                }
            }
        }
    }
}
