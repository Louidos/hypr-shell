pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Gemeinsamer Zustand der Oberfläche: welches Panel offen ist (immer nur eines), Seite der
// Einstellungs-App und das Schreiben von Einstellungen über shell-set (die App schreibt nie selbst in
// settings.json).
Singleton {
    id: ui

    // ---- immer nur ein Panel offen: Name des offenen Panels (Overlay.name) oder ""
    property string panel: ""
    function openPanel(name) { panel = name }
    function closePanel(name) { if (name === undefined || name === "" || panel === name) panel = "" }
    function togglePanel(name) { if (panel === name) closePanel(name); else openPanel(name) }
    // "shell-quickshell ipc shell current" nennt das offene Panel, "… shell close" schliesst es
    IpcHandler {
        target: "shell"
        function current(): string { return ui.panel }
        function close(): void { ui.closePanel() }
        // shell-toggle meldet den Gaming-Modus (Dock ohne Animationen)
        function gaming(on: bool): void { ui.gaming = on }
    }
    property bool gaming: false
    FileView {
        path: Quickshell.env("HOME") + "/.local/share/hypr-shell/gaming"
        printErrors: false
        onLoaded: ui.gaming = true
        onLoadFailed: ui.gaming = false
    }
    // das Dock ist unten versteckt: die Mitte der unteren Kante blendet das Dock ein, nicht das Dashboard
    property bool dockOwnsEdge: false
    // läuft die Oberfläche unter Hyprland? (Fokus-Griff "Klick daneben schliesst" gibt es nur dort)
    readonly property bool hyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""

    readonly property bool settingsOpen: panel === "settings"
    // was der Rechner kann (shell-laptop caps, später auch Anbindungen): Seiten und Zeilen mit
    // "requires" im Schema erscheinen nur, wenn die Fähigkeit da ist
    property var caps: ({})
    function can(req) { return !req || caps[req] === true }
    // ungelesene Benachrichtigungen je App (Kleinschreibung: App-Name und Desktop-Eintrag), vom
    // Benachrichtigungsdienst von hypr-shell gepflegt; ohne Dienst leer (dann keine Zähler im Dock)
    property var notifCounts: ({})
    signal notificationsRead(var keys)
    property string settingsPage: "home"
    // Schlüssel, zu dem die App nach dem Öffnen springen soll (Suche)
    property string settingsFocus: ""
    // Suchtext von aussen (IPC "settings search", z. B. im Oberflächentest)
    property string settingsSearch: ""

    function openSettings(page) {
        if (page && page !== "") settingsPage = page
        openPanel("settings")
    }
    function closeSettings() { closePanel("settings") }
    function toggleSettings(page) { if (settingsOpen) closeSettings(); else openSettings(page) }

    // ---- Bearbeiten-Modus für die Desktop-Widgets (SUPER+ALT+W): Entwurf der Positionen
    // (Anteil der Bildschirmgrösse) und Grössen; gespeichert wird erst mit Done (ein Schritt im Verlauf)
    property bool editDesktop: false
    property var draft: ({})
    function current(w) {
        return {
            x: Settings.get("desktop." + w + ".x", 0), y: Settings.get("desktop." + w + ".y", 0),
            scale: Settings.get("desktop." + w + ".scale", 1)
        }
    }
    function startEdit() {
        draft = { clock: current("clock"), resources: current("resources") }
        closePanel("settings")
        editDesktop = true
    }
    function cancelEdit() { editDesktop = false }
    function resetDraft() {
        const d = Settings.defaults.desktop || {}
        const pick = (o, fx, fy) => ({ x: o && o.x !== undefined ? o.x : fx, y: o && o.y !== undefined ? o.y : fy, scale: o && o.scale !== undefined ? o.scale : 1 })
        draft = { clock: pick(d.clock, 0.02, 0.045), resources: pick(d.resources, 0.015, 0.56) }
    }
    function moveDraft(w, x, y) {
        const d = Object.assign({}, draft)
        d[w] = Object.assign({}, d[w], { x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y)) })
        draft = d
    }
    function scaleDraft(w, f) {
        const d = Object.assign({}, draft)
        d[w] = Object.assign({}, d[w], { scale: Math.max(0.3, Math.min(3, Math.round(f * 20) / 20)) })
        draft = d
    }
    function finishEdit() {
        const r = v => String(Math.round(v * 1000) / 1000)
        const args = ["set"]
        for (const w of ["clock", "resources"]) {
            const c = current(w), n = draft[w]
            if (!n) continue
            if (r(n.x) !== r(c.x)) args.push("desktop." + w + ".x", r(n.x))
            if (r(n.y) !== r(c.y)) args.push("desktop." + w + ".y", r(n.y))
            if (r(n.scale) !== r(c.scale)) args.push("desktop." + w + ".scale", r(n.scale))
        }
        if (args.length > 1) run(args)
        editDesktop = false
    }
    // Position/Grösse eines Widgets: im Bearbeiten-Modus der Entwurf, sonst settings.json
    function widget(w, what, fallback) {
        if (editDesktop && draft[w] && draft[w][what] !== undefined) return draft[w][what]
        return Settings.get("desktop." + w + "." + what, fallback)
    }

    // ---- shell-set: Befehle der Reihe nach; beim Ziehen eines Reglers zählt nur der neueste Wert
    property var queue: []
    property var liveArgs: null
    property int changes: 0          // zählt jede ausgeführte Änderung (für Anzeigen in der App)
    property string lastError: ""

    function run(args) {
        const q = queue.slice()
        q.push(args)
        queue = q
        liveArgs = null
        next()
    }
    // Wert setzen. live = true: während des Ziehens (ein Schritt im Verlauf, wenn losgelassen)
    function set(key, value, live) {
        const v = typeof value === "string" ? value : JSON.stringify(value)
        if (live) { liveArgs = ["--live", key, v]; next() }
        else run([key, v])
    }
    function reset(keys) { run(["reset"].concat(keys)) }
    function undo() { run(["undo"]) }
    function redo() { run(["redo"]) }

    // ---- nur im Oberflächentest (HYPR_SHELL_TEST=1): Bedienelemente über ihre Signale auslösen –
    // derselbe Weg wie ein Mausklick (im unsichtbaren Test-Compositor gibt es kein Zeigegerät)
    property var probes: ({})
    IpcHandler {
        target: "test"
        function click(name: string): bool {
            const p = ui.probes[name]
            if (!p || !p.parent) return false
            const t = p.parent
            if (typeof t.toggled === "function") t.toggled()
            else if (typeof t.clicked === "function") t.clicked()
            else return false
            return true
        }
        // Regler ziehen: Zwischenwerte (moved) bis zum Anteil frac, dann loslassen (released)
        function drag(name: string, frac: real): bool {
            const p = ui.probes[name]
            if (!p || !p.parent || typeof p.parent.released !== "function") return false
            const s = p.parent
            for (let i = 1; i <= 4; i++) s.moved(s.snap(s.from + (s.to - s.from) * frac * i / 4))
            s.released(s.snap(s.from + (s.to - s.from) * frac))
            return true
        }
        // Widget im Bearbeiten-Modus ziehen (derselbe Aufruf wie beim Ziehen mit der Maus)
        function moveWidget(which: string, x: real, y: real): bool {
            if (!ui.editDesktop) return false
            ui.moveDraft(which, x, y)
            return true
        }
        function dragStart(name: string, frac: real): bool {
            const p = ui.probes[name]
            if (!p || !p.parent || typeof p.parent.moved !== "function") return false
            const s = p.parent
            s.moved(s.snap(s.from + (s.to - s.from) * frac))
            return true
        }
    }

    // ---- Tastenkürzel: gleiche Regeln wie shell-apply (Modifikatoren sortiert, Grossschreibung)
    function normCombo(c) {
        const p = String(c).split("+").map(x => x.trim()).filter(x => x !== "")
        if (p.length === 0) return ""
        const mods = p.slice(0, -1).map(m => m.toUpperCase() === "CONTROL" ? "CTRL" : m.toUpperCase())
        const u = mods.filter((m, i) => mods.indexOf(m) === i).sort()
        return u.concat([p[p.length - 1].toUpperCase()]).join(" + ")
    }
    function combosOf(name, v) {
        if (!v) return []
        const r = []
        if (name === "workspace_mod") { for (let i = 0; i < 10; i++) r.push(v + " + " + i); r.push(v + " + mouse_down", v + " + mouse_up") }
        else if (name === "move_mod") { for (let i = 0; i < 10; i++) r.push(v + " + " + i) }
        else if (name === "mouse_mod") r.push(v + " + mouse:272", v + " + mouse:273")
        else r.push(v)
        return r
    }
    // Wer benutzt diese Kombination schon? (Titel der Aktion oder "" wenn frei). self = eigener Name.
    function usedBy(self, value) {
        const kb = Settings.get("keybinds", {})
        const mine = combosOf(self, value).map(normCombo)
        for (const name in kb) {
            if (name === self || name === "custom" || !kb[name]) continue
            const theirs = combosOf(name, kb[name]).map(normCombo)
            if (mine.some(c => theirs.indexOf(c) >= 0)) {
                const s = Settings.schemaKey("keybinds." + name)
                return s ? s.title : name
            }
        }
        const custom = kb.custom || []
        for (let i = 0; i < custom.length; i++)
            if (self !== "custom#" + i && mine.indexOf(normCombo(custom[i].keys)) >= 0) return "own shortcut \"" + custom[i].command + "\""
        return ""
    }

    function next() {
        if (proc.running) return
        let args = null
        if (queue.length > 0) {
            args = queue[0]
            queue = queue.slice(1)
        } else if (liveArgs !== null) {
            args = liveArgs
            liveArgs = null
        }
        if (args === null) return
        proc.command = [Settings.bin + "shell-set"].concat(args)
        proc.running = true
    }

    Process {
        id: proc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") ui.lastError = text.trim().split("\n")[0].replace(/^shell-set: /, "")
        }
        onExited: (code, status) => {
            if (code === 0) ui.lastError = ""
            ui.changes++
            ui.next()
        }
    }
}
