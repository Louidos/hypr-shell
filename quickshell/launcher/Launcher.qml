import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"
import "calc.js" as Calc

// Starter: mittiges Suchfeld im Glas-Look mit Ergebnisliste (SUPER+R, SUPER+Space, ALT+Space).
// Sucht Apps nach Name, Beschreibung und Stichworten, zuletzt benutzte zuerst; Pfeiltasten und Enter.
// Beginnt die Eingabe mit "=", wird gerechnet; Enter kopiert das Ergebnis in die Zwischenablage.
// Nur aktiv, wenn apps.launcher "builtin" ist – sonst starten die Kürzel den eigenen Befehl (z. B. rofi).
// Zuletzt benutzt: ~/.local/share/hypr-shell/launcher-recent.json (App-ID → Zeitpunkt).
Scope {
    id: la
    property string query: ""
    property int sel: 0
    property var recent: ({})
    readonly property bool calcMode: query.trim().indexOf("=") === 0
    readonly property string calcResult: calcMode ? Calc.rechne(query) : ""

    // höher = besser; 0 = passt nicht
    function score(e, q) {
        const n = (e.name || "").toLowerCase()
        let s = 0
        if (n.indexOf(q) === 0) s = 100
        else if (n.split(/[\s\-_.]+/).some(w => w.indexOf(q) === 0)) s = 80
        else if (n.indexOf(q) >= 0) s = 60
        else if (((e.genericName || "") + " " + (e.keywords || []).join(" ")).toLowerCase().indexOf(q) >= 0) s = 40
        else if ((e.comment || "").toLowerCase().indexOf(q) >= 0) s = 20
        if (s > 0 && la.recent[e.id]) s += 30
        return s
    }
    readonly property var results: {
        if (calcMode) return []
        const all = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        const q = query.trim().toLowerCase()
        const zuletzt = e => la.recent[e.id] || 0
        if (q === "") {
            return all.slice().sort((a, b) => (zuletzt(b) - zuletzt(a)) || a.name.localeCompare(b.name)).slice(0, 60)
        }
        return all.map(e => ({ e: e, s: score(e, q) })).filter(x => x.s > 0)
            .sort((a, b) => (b.s - a.s) || (zuletzt(b.e) - zuletzt(a.e)) || a.e.name.localeCompare(b.e.name))
            .slice(0, 60).map(x => x.e)
    }
    readonly property int count: calcMode ? 1 : results.length
    onQueryChanged: sel = 0

    function remember(id) {
        const r = Object.assign({}, recent)
        r[id] = Date.now()
        const ids = Object.keys(r).sort((a, b) => r[b] - r[a])
        for (let i = 50; i < ids.length; i++) delete r[ids[i]]
        recent = r
        store.setText(JSON.stringify(r))
    }
    function launch(e) {
        if (!e) return
        ov.hide()
        remember(e.id)
        e.execute()
    }
    function activate() {
        if (calcMode) {
            if (calcResult !== "") { Quickshell.execDetached(["wl-copy", calcResult]); ov.hide() }
            return
        }
        if (results.length > 0) launch(results[Math.max(0, Math.min(sel, results.length - 1))])
    }
    function setQuery(text) {
        query = text
        if (ov.item) ov.item.input.text = text
    }

    FileView {
        id: store
        path: Settings.dataDir + "/launcher-recent.json"
        printErrors: false
        // gemeinsam mit dem App-Raster: dort gestartete Apps zählen auch hier als zuletzt benutzt
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { const r = JSON.parse(text()); if (r && typeof r === "object") la.recent = r } catch (e) { } }
        onLoadFailed: la.recent = ({})
    }

    IpcHandler {
        target: "launcher"
        function open(): void { ov.show() }
        function close(): void { ov.hide() }
        function toggle(): void { ov.toggle() }
        // Eingabe setzen und das erste Ergebnis nennen (Rechner: das Ergebnis) – für Tests und Skripte
        function search(text: string): string { la.setQuery(text); return la.calcMode ? la.calcResult : (la.results.length > 0 ? la.results[0].name : "") }
        function calc(text: string): string { return Calc.rechne(text) }
    }

    Overlay {
        id: ov
        name: "launcher"
        ipc: false
        place: "center"
        margin: 0
        panelWidth: 640
        panelHeight: 76 + 7 * 56 + 14
        scroll: false
        glassOpacity: Theme.glassOpacity
        keyboardFocus: WlrKeyboardFocus.Exclusive
        onOpened: { la.query = ""; la.sel = 0; if (ov.item) ov.item.input.text = "" }

        content: Component {
            Item {
                id: root
                property alias input: field
                focus: true

                // ---- Suchfeld
                Rectangle {
                    id: box
                    x: 14; y: 14
                    width: parent.width - 28
                    height: 48
                    radius: Theme.corner(24)
                    color: Theme.field
                    border.width: 1
                    border.color: Theme.cardBorder
                    Glyph {
                        id: lens
                        anchors { left: parent.left; leftMargin: Theme.pad(18); verticalCenter: parent.verticalCenter }
                        text: la.calcMode ? "󰃬" : ""
                        size: 15
                        color: Theme.subtext
                    }
                    TextInput {
                        id: field
                        anchors { left: lens.right; leftMargin: Theme.pad(12); right: parent.right; rightMargin: Theme.pad(18); verticalCenter: parent.verticalCenter }
                        focus: true
                        color: Theme.text
                        font.family: Theme.sans
                        font.pixelSize: 16 * Theme.fontScale
                        clip: true
                        onTextChanged: la.query = text
                        Keys.onDownPressed: la.sel = Math.min(la.sel + 1, la.count - 1)
                        Keys.onUpPressed: la.sel = Math.max(la.sel - 1, 0)
                        Keys.onTabPressed: la.sel = la.count > 0 ? (la.sel + 1) % la.count : 0
                        Keys.onReturnPressed: la.activate()
                        Keys.onEnterPressed: la.activate()
                        Txt {
                            visible: field.text.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search apps, or = to calculate"
                            size: 16
                            sub: true
                        }
                    }
                }

                // ---- Rechner
                GlassCard {
                    visible: la.calcMode
                    x: 14
                    anchors { top: box.bottom; topMargin: Theme.pad(14) }
                    width: parent.width - 28
                    height: 72
                    color: Theme.cardHover
                    Column {
                        anchors { left: parent.left; leftMargin: Theme.pad(18); verticalCenter: parent.verticalCenter }
                        spacing: Theme.pad(2)
                        Txt {
                            text: la.calcResult !== "" ? "= " + la.calcResult : "…"
                            size: 22
                            heavy: true
                            font.family: Theme.mono
                            Probe { name: "launcher-calc" }
                        }
                        Txt { text: la.calcResult !== "" ? "Enter copies the result" : "Type a calculation, e.g. =12*8"; size: 12; sub: true }
                    }
                }

                // ---- Ergebnisse
                ListView {
                    id: list
                    visible: !la.calcMode
                    x: 14
                    anchors { top: box.bottom; topMargin: Theme.pad(14); bottom: parent.bottom; bottomMargin: Theme.pad(14) }
                    width: parent.width - 28
                    clip: true
                    spacing: 0
                    model: la.results
                    currentIndex: la.sel
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 56
                        radius: Theme.corner(16)
                        color: index === la.sel ? Theme.cardHover : (hov.hovered ? Theme.card : "transparent")
                        AppIcon {
                            id: ico
                            anchors { left: parent.left; leftMargin: Theme.pad(12); verticalCenter: parent.verticalCenter }
                            size: 32
                            icon: row.modelData.icon || ""
                            probe: row.index === 0 ? "launcher-first" : ""
                        }
                        Column {
                            anchors { left: ico.right; leftMargin: Theme.pad(14); right: parent.right; rightMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
                            spacing: Theme.pad(1)
                            Txt { width: parent.width; text: row.modelData.name; size: 14; strong: true }
                            Txt {
                                width: parent.width
                                visible: text !== ""
                                text: row.modelData.comment || row.modelData.genericName || ""
                                size: 12
                                sub: true
                            }
                        }
                        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: la.launch(row.modelData) }
                    }
                    Txt {
                        anchors.centerIn: parent
                        visible: la.results.length === 0
                        text: "No apps found"
                        sub: true
                    }
                }
            }
        }
    }
}
