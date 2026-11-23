import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"
import "zuordnung.js" as Z

// Dock: schwebende Glas-Leiste mit angehefteten und laufenden Programmen, ein Fenster pro Bildschirm
// (dock.monitor). Fensteränderungen kommen als Ereignisse über ToplevelManager (Wayland
// foreign-toplevel), es wird nichts im Takt abgefragt. dock.enabled = false: kein Fenster, keine Abfrage.
Scope {
    id: dock

    readonly property bool on: Settings.get("dock.enabled", true) === true
    // sichtbar (shell-quickshell ipc dock show|hide|toggle)
    property bool shown: true

    // ---- Werte (alle in settings/schema.json, Grenzen dort; hier nur noch einmal abgesichert)
    function num(k, d, lo, hi) {
        const v = Number(Settings.get(k, d))
        return isNaN(v) ? d : Math.max(lo, Math.min(hi, v))
    }
    readonly property string position: ["bottom", "top", "left", "right"].indexOf(Settings.get("dock.position", "bottom")) >= 0
        ? Settings.get("dock.position", "bottom") : "bottom"
    readonly property bool vertical: position === "left" || position === "right"
    readonly property int margin: num("dock.margin", 10, 0, 100)
    readonly property int iconSize: num("dock.icon_size", 48, 16, 128)
    readonly property int iconMin: Math.min(iconSize, num("dock.icon_min_size", 24, 16, 64))
    readonly property int padding: num("dock.padding", 8, 0, 40)
    readonly property int spacing: num("dock.spacing", 6, 0, 40)
    readonly property int radius: num("dock.radius", 22, 0, 100)
    readonly property real maxLength: num("dock.max_length", 90, 20, 100) / 100
    readonly property bool reserve: Settings.get("dock.mode", "floating") === "reserve"
    readonly property bool topLayer: Settings.get("dock.layer", "top") !== "bottom"
    readonly property bool blur: Settings.get("dock.blur", true) === true
    readonly property real glassOpacity: {
        const v = num("dock.glass_opacity", -1, -1, 1)
        return v < 0 ? Theme.glassOpacity : v
    }
    readonly property int borderWidth: num("dock.border_width", 1, 0, 6)
    readonly property string labels: Settings.get("dock.labels", "hover")
    readonly property string indicator: Settings.get("dock.indicator", "dot")
    readonly property bool showRunning: Settings.get("dock.show_running", true) === true
    readonly property bool showTrash: Settings.get("dock.trash", true) === true

    function farbe(v, auto) { return /^#[0-9a-fA-F]{6}$/.test(String(v)) ? String(v) : auto }
    readonly property color glassColor: {
        const m = Settings.get("dock.color_mode", "wallpaper"), o = glassOpacity
        if (m === "light") return Qt.rgba(0.95, 0.95, 0.96, o)
        if (m === "dark") return Qt.rgba(0.055, 0.055, 0.065, o)
        if (m === "custom") { const c = Qt.color(farbe(Settings.get("dock.custom_color", "#1e1e2e"), "#1e1e2e")); return Qt.rgba(c.r, c.g, c.b, o) }
        // wallpaper: Glas der Panels, leicht in der Fläche des Hintergrundbilds getönt
        const c = Qt.color(Theme.mix(Theme.c.surface, "#0e0e10", 0.45)); return Qt.rgba(c.r, c.g, c.b, o)
    }
    readonly property bool lightGlass: Settings.get("dock.color_mode", "wallpaper") === "light"
    readonly property color borderColor: farbe(Settings.get("dock.border_color", "auto"), "") !== ""
        ? farbe(Settings.get("dock.border_color", "auto"), "#ffffff")
        : (lightGlass ? Qt.rgba(0, 0, 0, 0.12) : Theme.glassBorder)
    readonly property color indicatorColor: farbe(Settings.get("dock.indicator_color", "auto"), "") !== ""
        ? farbe(Settings.get("dock.indicator_color", "auto"), "#ffffff")
        : (lightGlass ? "#202024" : Theme.accent)
    readonly property string shadow: Settings.get("dock.shadow", "medium")

    // ---- Bildschirme laut dock.monitor (unbekannter Name: erster Bildschirm)
    readonly property var screens: {
        if (!on) return []
        const m = String(Settings.get("dock.monitor", "all")), l = Quickshell.screens
        if (m === "all") return l
        const f = l.filter(s => s.name === m)
        if (f.length > 0) return f
        return l.length > 0 ? [l[0]] : []
    }

    // ---- Desktop-Einträge und Zuordnung Fenster → Programm
    readonly property var entries: on ? DesktopEntries.applications.values : []
    readonly property var entryList: entries.map(e => ({
        id: e.id, name: e.name, icon: e.icon, execString: e.execString,
        startupClass: e.startupClass !== undefined ? e.startupClass : "", ref: e
    }))
    function byId(id) {
        const e = DesktopEntries.byId(id) || DesktopEntries.byId(String(id).toLowerCase())
        if (!e) return null
        return { id: e.id, name: e.name, icon: e.icon, execString: e.execString, startupClass: e.startupClass || "", ref: e }
    }
    // Zwischenspeicher appId → Eintrag (neu, wenn sich die Einträge ändern)
    property var cache: ({})
    onEntryListChanged: cache = ({})
    function entryForApp(appId) {
        const k = String(appId || "")
        if (cache[k] !== undefined) return cache[k]
        const e = Z.finde(k, entryList, byId)
        cache[k] = e
        return e
    }
    // angehefteter Eintrag (desktop_id): genau, sonst Heuristik von Quickshell
    function entryForPin(id) {
        if (!id) return null
        const e = byId(id)
        if (e) return e
        const h = DesktopEntries.heuristicLookup(id)
        return h ? { id: h.id, name: h.name, icon: h.icon, execString: h.execString, startupClass: h.startupClass || "", ref: h } : null
    }

    // ---- Ordner und Papierkorb: nur bei Änderung der Liste abgefragt
    readonly property var items: {
        const v = Settings.get("dock.items", [])
        return Array.isArray(v) ? v.filter(i => i && typeof i === "object") : []
    }
    readonly property var folderPaths: items.filter(i => i.type === "folder" && i.path).map(i => String(i.path))
    property var folders: ({})
    property var trash: ({ available: false, full: false })
    Process {
        id: existsProc
        command: [Settings.bin + "shell-dock", "exists"].concat(dock.folderPaths)
        stdout: StdioCollector { onStreamFinished: { try { dock.folders = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: trashProc
        command: [Settings.bin + "shell-dock", "trash"]
        stdout: StdioCollector { onStreamFinished: { try { dock.trash = JSON.parse(text) } catch (e) { } } }
    }
    function refreshFiles() {
        if (!on) return
        if (folderPaths.length > 0 && !existsProc.running) existsProc.running = true
        if (!trashProc.running) trashProc.running = true
    }
    onFolderPathsChanged: refreshFiles()
    onOnChanged: refreshFiles()
    Component.onCompleted: refreshFiles()

    // ---- laufende Fenster (Ereignisse von ToplevelManager)
    readonly property var toplevels: on ? ToplevelManager.toplevels.values : []
    readonly property bool perMonitor: Settings.get("dock.running_per_monitor", false) === true

    function onScreen(t, screen) {
        if (!screen) return true
        const s = t.screens || []
        if (s.length === 0) return true
        for (let i = 0; i < s.length; i++) if (s[i] && s[i].name === screen.name) return true
        return false
    }

    // Modell für einen Bildschirm: Liste von {kind, key, name, icon, entry, path, windows, pinned}
    function model(screen) {
        const pins = []
        const byKey = {}
        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            if (it.type === "app") {
                const e = entryForPin(it.desktop_id)
                if (!e) continue                                      // nicht installiert: fehlt still
                const k = Z.schluessel("", e)
                if (byKey[k]) continue
                const o = { kind: "app", key: k, name: e.name, icon: e.icon, entry: e, path: "", windows: [], pinned: true, desktopId: e.id }
                byKey[k] = o; pins.push(o)
            } else if (it.type === "folder") {
                const p = String(it.path || "")
                if (p === "" || dock.folders[p] !== true) continue    // fehlt der Ordner: fehlt der Eintrag
                const n = p.replace(/\/+$/, "").split("/").pop() || p
                pins.push({ kind: "folder", key: "folder:" + p, name: n, icon: /download/i.test(n) ? "folder-download" : "folder", path: p, windows: [], pinned: true })
            } else if (it.type === "separator") {
                pins.push({ kind: "separator", key: "sep:" + i, windows: [] })
            } else if (it.type === "trash") {
                if (!showTrash || dock.trash.available !== true) continue
                pins.push({ kind: "trash", key: "trash", name: "Trash", icon: dock.trash.full ? "user-trash-full" : "user-trash", windows: [], pinned: true })
            } else if (it.type === "launcher") {
                pins.push({ kind: "launcher", key: "launcher", name: "Apps", icon: "view-app-grid-symbolic", windows: [], pinned: true })
            }
        }
        // Fenster den Einträgen zuordnen; nicht angeheftete als eigene Einträge
        const running = []
        const tl = toplevels
        for (let i = 0; i < tl.length; i++) {
            const t = tl[i]
            if (!t || (perMonitor && !onScreen(t, screen))) continue
            const e = entryForApp(t.appId)
            const k = Z.schluessel(t.appId, e)
            let o = byKey[k]
            if (!o) {
                if (!showRunning) continue
                o = e ? { kind: "app", key: k, name: e.name, icon: e.icon, entry: e, path: "", windows: [], pinned: false, desktopId: e.id }
                      : { kind: "window", key: k, name: t.title || t.appId || "Window", icon: String(t.appId || "").toLowerCase(), entry: null, path: "", windows: [], pinned: false, desktopId: "" }
                byKey[k] = o; running.push(o)
            }
            o.windows.push(t)
        }
        // laufende rechts von den angehefteten Programmen, vor dem ersten Trenner danach
        let at = pins.length
        let seenApp = false
        for (let i = 0; i < pins.length; i++) {
            if (pins[i].kind === "app" || pins[i].kind === "launcher") seenApp = true
            else if (seenApp && pins[i].kind !== "app") { at = i; break }
        }
        const all = pins.slice(0, at).concat(running, pins.slice(at))
        // Trenner nur zwischen zwei Einträgen, nie doppelt, nie am Rand
        const out = []
        for (let i = 0; i < all.length; i++) {
            if (all[i].kind === "separator") {
                if (out.length === 0 || out[out.length - 1].kind === "separator") continue
            }
            out.push(all[i])
        }
        while (out.length > 0 && out[out.length - 1].kind === "separator") out.pop()
        return out
    }

    // ---- Bedienung
    function launch(it) {
        if (it.entry && it.entry.ref) {
            it.entry.ref.execute()
            return true
        }
        return false
    }
    function activate(it) {
        if (!it) return
        if (it.kind === "folder") { Quickshell.execDetached([Settings.bin + "shell-dock", "open", it.path]); return }
        if (it.kind === "trash") { Quickshell.execDetached([Settings.bin + "shell-dock", "open-trash"]); trashCheck.restart(); return }
        if (it.kind === "launcher") { Quickshell.execDetached([Settings.bin + "shell-quickshell", "ipc", "launcher", "toggle"]); return }
        const w = it.windows || []
        if (w.length === 0) { launch(it); return }
        // läuft: Fenster nach vorn holen; ist eines davon schon vorn, zum nächsten
        let a = -1
        for (let i = 0; i < w.length; i++) if (w[i].activated) { a = i; break }
        const next = a >= 0 ? w[(a + 1) % w.length] : w[0]
        next.activate()
    }
    Timer { id: trashCheck; interval: 3000; onTriggered: dock.refreshFiles() }

    // ---- ein Dock pro Bildschirm
    Variants {
        model: dock.screens
        DockWindow {
            required property var modelData
            screen: modelData
            dock: dock
        }
    }

    // ---- shell-quickshell ipc dock …
    property var windows: []          // alle DockWindow (für Tests)
    IpcHandler {
        target: "dock"
        function toggle(): void { dock.shown = !dock.shown }
        function open(): void { dock.shown = true }
        function close(): void { dock.shown = false }
        // "show" ist in qs ipc vergeben: shell-quickshell übersetzt "ipc dock show" in "open"
        function hide(): void { dock.shown = false }
        function focus(): void { dock.shown = true }
        // für Tests: Zuordnung eines Fensters (app_id/class) zu einem Desktop-Eintrag ("" = keiner)
        function resolve(appId: string): string { const e = dock.entryForApp(appId); return e ? String(e.id) : "" }
        // für Tests: Einträge des ersten Docks, z. B. "app:kitty*,separator,folder:~/Downloads,trash"
        function items(): string {
            const m = dock.model(dock.screens.length > 0 ? dock.screens[0] : null)
            return m.map(o => (o.kind === "app" ? "app:" + o.desktopId : o.kind === "folder" ? "folder:" + o.path : o.kind === "window" ? "window:" + o.key.slice(4) : o.kind)
                + (o.windows.length > 0 ? "*" + o.windows.length : "")).join(",")
        }
        function count(): int { return dock.windows.length }
        // für Tests: Lage des ersten Docks als JSON (x, y, width, height relativ zum Bildschirm)
        function geometry(): string { return dock.windows.length > 0 ? JSON.stringify(dock.windows[0].geometry()) : "{}" }
        function visible(): bool { return dock.on && dock.shown }
    }
}
