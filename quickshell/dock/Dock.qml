import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common"
import "zuordnung.js" as Z
import "verstecken.js" as V

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
    // Animationen: dock.anim_ms; aus bei 0, im Gaming-Modus und wenn die Animationen von hypr-shell aus sind
    readonly property int animMs: Ui.gaming || Settings.get("look.animations.enabled", true) !== true ? 0 : num("dock.anim_ms", 180, 0, 1000)
    readonly property bool magnify: Settings.get("dock.magnify", true) === true
    readonly property real magnifyFactor: num("dock.magnify_factor", 1.6, 1.0, 2.5)
    readonly property int magnifyRange: num("dock.magnify_range", 2, 1, 5)
    readonly property bool bounce: Settings.get("dock.bounce_on_launch", true) === true && animMs > 0
    readonly property string autohide: ["never", "always", "smart"].indexOf(Settings.get("dock.autohide", "smart")) >= 0 ? Settings.get("dock.autohide", "smart") : "smart"
    readonly property int showDelay: num("dock.show_delay_ms", 150, 0, 2000)
    readonly property int hideDelay: num("dock.hide_delay_ms", 400, 0, 5000)
    // Symbolstil: original, mono, theme (Effekt nur, wenn Qt ihn kann)
    readonly property string iconStyle: Settings.get("dock.icon_style", "original")
    readonly property var monoEffect: { const c = Qt.createComponent("DockIconMono.qml"); return c.status === Component.Ready ? c : null }
    readonly property var themeEffect: { const c = Qt.createComponent("DockIconTheme.qml"); return c.status === Component.Ready ? c : null }
    readonly property var iconEffect: iconStyle === "mono" ? monoEffect : iconStyle === "theme" ? themeEffect : null
    readonly property bool launcherButton: Settings.get("dock.launcher_button", false) === true
    readonly property bool badges: Settings.get("dock.badges", true) === true
    readonly property bool previews: Settings.get("dock.previews", true) === true

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
    property bool existsAgain: false
    Process {
        id: existsProc
        stdout: StdioCollector { onStreamFinished: { try { dock.folders = JSON.parse(text) } catch (e) { } } }
        onExited: if (dock.existsAgain) { dock.existsAgain = false; dock.refreshFiles() }
    }
    Process {
        id: trashProc
        command: [Settings.bin + "shell-dock", "trash"]
        stdout: StdioCollector { onStreamFinished: { try { dock.trash = JSON.parse(text) } catch (e) { } } }
    }
    function refreshFiles() {
        if (!on) return
        if (folderPaths.length > 0) {
            if (existsProc.running) existsAgain = true
            else { existsProc.command = [Settings.bin + "shell-dock", "exists"].concat(folderPaths); existsProc.running = true }
        }
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
                const o = { kind: "app", key: k, name: e.name, icon: e.icon, entry: e, path: "", windows: [], pinned: true, desktopId: e.id, src: i }
                byKey[k] = o; pins.push(o)
            } else if (it.type === "folder") {
                const p = String(it.path || "")
                if (p === "" || dock.folders[p] !== true) continue    // fehlt der Ordner: fehlt der Eintrag
                const n = p.replace(/\/+$/, "").split("/").pop() || p
                if (byKey["folder:" + p]) continue
                const fo = { kind: "folder", key: "folder:" + p, name: n, icon: /download/i.test(n) ? "folder-download" : "folder", path: p, windows: [], pinned: true, src: i }
                byKey[fo.key] = fo; pins.push(fo)
            } else if (it.type === "separator") {
                pins.push({ kind: "separator", key: "sep:" + i, windows: [], pinned: true, src: i })
            } else if (it.type === "trash") {
                if (!showTrash || dock.trash.available !== true || byKey.trash) continue
                byKey.trash = { kind: "trash", key: "trash", name: "Trash", icon: dock.trash.full ? "user-trash-full" : "user-trash", windows: [], pinned: true, src: i }
                pins.push(byKey.trash)
            } else if (it.type === "launcher") {
                if (byKey.launcher) continue
                byKey.launcher = { kind: "launcher", key: "launcher", name: "Apps", icon: "view-app-grid-symbolic", windows: [], pinned: true, src: i }
                pins.push(byKey.launcher)
            }
        }
        // Startknopf links (dock.launcher_button), wenn er nicht schon in der Liste steht
        if (launcherButton && !byKey.launcher) {
            byKey.launcher = { kind: "launcher", key: "launcher", name: "Apps", icon: "view-app-grid-symbolic", windows: [], pinned: true, src: -1 }
            pins.unshift(byKey.launcher)
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
                o = e ? { kind: "app", key: k, name: e.name, icon: e.icon, entry: e, path: "", windows: [], pinned: false, desktopId: e.id, src: -1 }
                      : { kind: "window", key: k, name: t.appId || "Window", icon: String(t.appId || "").toLowerCase(), entry: null, path: "", windows: [], pinned: false, desktopId: "", src: -1 }
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
        if (it && it.entry && it.entry.ref) {
            it.entry.ref.execute()
            launched(it.key)
            return true
        }
        return false
    }
    signal launched(string key)
    function activate(it) {
        if (!it) return
        if (it.kind === "folder") { Quickshell.execDetached([Settings.bin + "shell-dock", "open", it.path]); return }
        if (it.kind === "trash") { Quickshell.execDetached([Settings.bin + "shell-dock", "open-trash"]); trashCheck.restart(); return }
        if (it.kind === "launcher") { Quickshell.execDetached([Settings.bin + "shell-quickshell", "ipc", "launcher", "toggle"]); return }
        readBadge(it)
        const w = it.windows || []
        if (w.length === 0) { launch(it); return }
        // läuft: Fenster nach vorn holen; ist eines davon schon vorn, zum nächsten
        let a = -1
        for (let i = 0; i < w.length; i++) if (w[i].activated) { a = i; break }
        const next = a >= 0 ? w[(a + 1) % w.length] : w[0]
        next.activate()
    }
    // Mausrad über einem Symbol: zwischen den Fenstern der App wechseln
    function cycle(it, step) {
        const w = it ? (it.windows || []) : []
        if (w.length === 0) return
        let a = -1
        for (let i = 0; i < w.length; i++) if (w[i].activated) { a = i; break }
        w[((a < 0 ? 0 : a + step) % w.length + w.length) % w.length].activate()
    }
    // Mittelklick / "New window": Aktion "new-window" der App, sonst die App noch einmal starten
    function newWindow(it) {
        if (!it || !it.entry || !it.entry.ref) return
        const acts = it.entry.ref.actions || []
        for (let i = 0; i < acts.length; i++) {
            if (/^new[-_]?window$/i.test(String(acts[i].id))) { acts[i].execute(); launched(it.key); return }
        }
        launch(it)
    }
    // "Close all": Fenster normal schliessen (wie Klick aufs X), nie Prozesse beenden
    function closeAll(it) {
        const w = it ? (it.windows || []).slice() : []
        for (let i = 0; i < w.length; i++) w[i].close()
    }
    function readBadge(it) {
        if (!it || !it.entry) return
        Ui.notificationsRead([String(it.entry.id).replace(/\.desktop$/, ""), String(it.entry.name)])
    }
    // Zähler für ein Symbol (dock.badges): Desktop-Eintrag, sonst App-Name
    function badgeFor(it) {
        if (!badges || !it || !it.entry) return 0
        const c = Ui.notifCounts || {}
        const id = String(it.entry.id).toLowerCase().replace(/\.desktop$/, "")
        const parts = id.split(".")
        return c[id] || c[String(it.entry.name).toLowerCase()] || c[parts[parts.length - 1]] || 0
    }

    // ---- Einträge ändern: immer auf dock.items, sodass versteckte Einträge (fehlendes Programm,
    // fehlender Ordner) an ihrem Platz bleiben; gespeichert über shell-set (atomar)
    function itemFor(it) {
        if (it.kind === "app" || it.kind === "window") return { type: "app", desktop_id: it.desktopId || "", path: "" }
        if (it.kind === "folder") return { type: "folder", desktop_id: "", path: it.path }
        return { type: it.kind, desktop_id: "", path: "" }
    }
    function save(list) { Ui.set("dock.items", list) }
    function canPin(it) { return it && !it.pinned && it.kind === "app" && it.desktopId !== "" }
    function pin(it, beforeSrc) {
        if (!canPin(it)) return false
        const l = items.slice()
        let at = beforeSrc >= 0 ? beforeSrc : -1
        if (at < 0) { at = 0; for (let i = 0; i < l.length; i++) if (l[i].type === "app" || l[i].type === "launcher") at = i + 1 }
        l.splice(at, 0, itemFor(it))
        save(l)
        return true
    }
    function unpin(it) {
        if (!it || !it.pinned || it.src < 0) return false
        const l = items.slice()
        l.splice(it.src, 1)
        save(l)
        return true
    }
    // Eintrag "it" vor (after = false) bzw. hinter (after = true) "target" setzen
    function move(it, target, after) {
        if (!it || !target || it.key === target.key) return false
        if (!it.pinned) {
            if (!canPin(it)) return false
            return pin(it, target.pinned && target.src >= 0 ? target.src + (after ? 1 : 0) : -1)
        }
        if (it.src < 0) return false
        const l = items.slice()
        const x = l.splice(it.src, 1)[0]
        let t
        if (target.pinned && target.src >= 0) {
            t = target.src > it.src ? target.src - 1 : target.src
            if (after) t++
        } else {
            // Ziel ist ein laufendes, nicht angeheftetes Programm: hinter die angehefteten Programme
            t = 0
            for (let i = 0; i < l.length; i++) if (l[i].type === "app" || l[i].type === "launcher") t = i + 1
        }
        l.splice(Math.max(0, Math.min(l.length, t)), 0, x)
        save(l)
        return true
    }
    // Ordner vorschlagen (Nextcloud, Missa), nie automatisch anheften
    readonly property var suggestions: {
        const s = []
        if (Integrations.nextcloud) s.push({ name: "Nextcloud", path: String(Settings.get("nextcloud.mount_path", "~/Nextcloud")) })
        if (Integrations.missa) s.push({ name: "Missa", path: String(Settings.get("missa.folder", "~/Missa")) })
        return s.filter(x => !items.some(i => i.type === "folder" && i.path === x.path))
    }
    function addFolder(path) {
        const l = items.slice()
        let at = l.length
        for (let i = 0; i < l.length; i++) if (l[i].type === "trash") { at = i; break }
        l.splice(at, 0, { type: "folder", desktop_id: "", path: path })
        save(l)
    }
    property bool trashArmed: false
    Timer { id: trashDisarm; interval: 4000; onTriggered: dock.trashArmed = false }
    function emptyTrash() {
        if (!trashArmed) { trashArmed = true; trashDisarm.restart(); return false }
        trashArmed = false
        Quickshell.execDetached([Settings.bin + "shell-dock", "empty-trash"])
        trashCheck.restart()
        return true
    }

    // Menü eines Eintrags: Liste von { text, icon, run }
    function menuFor(it) {
        const m = []
        if (!it || it.kind === "separator") return m
        if (it.kind === "app" || it.kind === "window") {
            if (it.entry) {
                m.push({ text: "New window", icon: "󰖲", run: () => dock.newWindow(it) })
                const acts = it.entry.ref ? (it.entry.ref.actions || []) : []
                for (let i = 0; i < acts.length; i++) {
                    if (/^new[-_]?window$/i.test(String(acts[i].id))) continue
                    const a = acts[i]
                    m.push({ text: String(a.name), icon: "󰐊", run: () => { a.execute(); dock.launched(it.key) } })
                }
            }
            if (it.pinned) m.push({ text: "Remove from Dock", icon: "󰐄", run: () => dock.unpin(it) })
            else if (canPin(it)) m.push({ text: "Keep in Dock", icon: "󰐃", run: () => dock.pin(it, -1) })
            if ((it.windows || []).length > 0) m.push({ text: (it.windows.length > 1 ? "Close all" : "Close"), icon: "󰅖", run: () => dock.closeAll(it) })
        } else if (it.kind === "folder") {
            m.push({ text: "Open", icon: "󰉋", run: () => dock.activate(it) })
            m.push({ text: "Remove from Dock", icon: "󰐄", run: () => dock.unpin(it) })
        } else if (it.kind === "trash") {
            m.push({ text: "Open", icon: "󰩹", run: () => dock.activate(it) })
            if (trash.full) m.push({ text: trashArmed ? "Click again to empty" : "Empty trash", icon: "󰗨", keep: true, run: () => dock.emptyTrash() })
        } else if (it.kind === "launcher") {
            m.push({ text: "Open launcher", icon: "󰀻", run: () => dock.activate(it) })
            if (it.src >= 0) m.push({ text: "Remove from Dock", icon: "󰐄", run: () => dock.unpin(it) })
        }
        if (it.kind === "folder" || it.kind === "trash")
            for (let i = 0; i < suggestions.length; i++) {
                const sg = suggestions[i]
                m.push({ text: "Add " + sg.name + " folder", icon: "󰉗", run: () => dock.addFolder(sg.path) })
            }
        return m
    }
    Timer { id: trashCheck; interval: 3000; onTriggered: dock.refreshFiles() }

    // ---- Tastatur (SUPER+B): das Dock auf dem Bildschirm mit dem Fokus bekommt die Tastatur
    property var focusWin: null
    function focusDock() {
        shown = true
        let w = windows.length > 0 ? windows[0] : null
        const name = Ui.hyprland && Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (let i = 0; i < windows.length; i++) if (windows[i].screen && windows[i].screen.name === name) w = windows[i]
        focusWin = w
        if (w) w.startKeyboard()
    }
    function leaveFocus() { if (focusWin) focusWin.stopKeyboard(); focusWin = null }

    // ---- smart: Fensterflächen von Hyprland nur bei Fenster-Ereignissen neu holen, nie im Takt
    readonly property var refreshEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode",
        "fullscreen", "workspace", "workspacev2", "focusedmon", "focusedmonv2", "activewindowv2", "moveworkspace", "moveworkspacev2"]
    Connections {
        target: Ui.hyprland && dock.on && dock.autohide === "smart" ? Hyprland : null
        function onRawEvent(event) { if (dock.refreshEvents.indexOf(event.name) >= 0) refreshLater.restart() }
    }
    Timer { id: refreshLater; interval: 60; onTriggered: Hyprland.refreshToplevels() }

    // die untere Kante gehört dem Dock, solange es dort versteckt ist (siehe Dashboard)
    readonly property bool ownsEdge: windows.some(w => w.ownsEdge)
    onOwnsEdgeChanged: Ui.dockOwnsEdge = ownsEdge
    Component.onDestruction: Ui.dockOwnsEdge = false

    // ---- ein Dock pro Bildschirm
    // eigener Name für den Bezug: im Fenster heisst die Eigenschaft selbst "dock"
    readonly property var dockRoot: dock
    Variants {
        model: dock.screens
        DockWindow {
            required property var modelData
            screen: modelData
            dock: dockRoot
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
        function focus(): void { dock.focusDock() }
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
        // für Tests: Menü des n-ten Eintrags ("New window|Private window|…")
        function menu(index: int): string { const m = dock.model(dock.screens[0] || null); return index < m.length ? dock.menuFor(m[index]).map(x => x.text).join("|") : "" }
        // für Tests: n-ten Eintrag vor/hinter den m-ten ziehen (derselbe Weg wie Ziehen mit der Maus)
        function drag(from: int, to: int): bool {
            const m = dock.model(dock.screens[0] || null)
            if (from >= m.length || to >= m.length) return false
            return dock.move(m[from], m[to], to > from)
        }
        // für Tests: n-ten Eintrag aus dem Dock ziehen (lösen)
        function dragOut(index: int): bool { const m = dock.model(dock.screens[0] || null); return index < m.length && dock.unpin(m[index]) }
        // für Tests: Taste im Dock (Left, Right, Return, Menu, Escape …); "" = Tastatur aktiv?
        function key(name: string): string { return dock.windows.length > 0 ? dock.windows[0].testKey(name) : "" }
        function refresh(): void { dock.refreshFiles() }
        // für Tests: Logik von smart mit nachgestellten Flächen: {"dock": {...}, "windows": [...]}
        function smartTest(json: string): bool { try { const o = JSON.parse(json); return V.ueberdeckt(o.dock, o.windows) } catch (e) { return false } }
        function animMs(): int { return dock.animMs }
        // für Tests: Maus n-mal über das erste Dock führen (Vergrösserung), Dauer in ms
        function sweep(n: int): int { return dock.windows.length > 0 ? dock.windows[0].sweep(n) : -1 }
        function badge(index: int): int { const m = dock.model(dock.screens[0] || null); return index < m.length ? dock.badgeFor(m[index]) : 0 }
    }
}
