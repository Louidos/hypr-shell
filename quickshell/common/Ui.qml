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
    // angemeldete Panels (Overlay meldet sich an und ab): ein Name ohne Panel – z. B. Missa, solange
    // es aus ist – darf Ui.panel nie besetzen, sonst nimmt das Dock keine Klicks mehr an
    property var known: ({})
    function registerPanel(name) { const k = Object.assign({}, known); k[name] = (k[name] || 0) + 1; known = k }
    function unregisterPanel(name) {
        const k = Object.assign({}, known)
        if (k[name] > 1) k[name]--; else delete k[name]
        known = k
        if (!known[name] && panel === name) panel = ""
    }
    function openPanel(name) {
        if (!name || !known[name]) { if (name) console.info("hypr-shell: kein Panel \"" + name + "\" – nichts geöffnet"); return }
        panel = name
    }
    function closePanel(name) { if (name === undefined || name === "" || panel === name) panel = "" }
    function togglePanel(name) { if (panel === name) closePanel(name); else openPanel(name) }
    // Fläche jedes offenen Panels auf seinem Bildschirm ({screen, x, y, width, height}, Endlage ohne
    // Animation); das Dock weicht aus, wenn das offene Panel es überdeckt (dock.when_panel_open)
    property var panelAreas: ({})
    function setPanelArea(name, area) {
        if (!name) return
        const k = Object.assign({}, panelAreas)
        if (area) k[name] = area; else delete k[name]
        panelAreas = k
    }

    // ---- Tastatur: jede Fläche meldet, solange sie die Tastatur will (Exclusive/OnDemand, sichtbar
    // und offen). Regel: nur sichtbar offene Flächen dürfen die Tastatur haben; der Notfall gibt alles frei.
    property var keyboardWanted: ({})
    function setKeyboard(name, on) {
        if (!name || (keyboardWanted[name] === true) === !!on) return
        const k = Object.assign({}, keyboardWanted)
        if (on) k[name] = true; else delete k[name]
        keyboardWanted = k
    }
    function keyboardHolders() { return Object.keys(keyboardWanted).sort().join(",") }
    signal released()
    function releaseAll() {
        closePanel()
        editDesktop = false
        released()           // Dock: Tastatur-Modus aus, nicht exklusive Karten zu
    }
    // "shell-quickshell ipc shell current" nennt das offene Panel, "… shell close" schliesst es
    IpcHandler {
        target: "shell"
        function current(): string { return ui.panel }
        // für Tests und den Notfall: ein Panel öffnen wie von innen (auch ein unbekannter Name)
        function open(name: string): string { ui.openPanel(name); return ui.panel }
        // welche Flächen der Shell gerade die Tastatur wollen ("" = keine) – shell-diag tastatur
        function keyboard(): string { return ui.keyboardHolders() }
        // Notfall (SUPER+CTRL+Escape, shell-diag freigeben): alle Panels zu, Dock-Tastatur-Modus
        // und Bearbeiten-Modus aus – danach hält keine Fläche der Shell mehr die Tastatur
        function release(): string { ui.releaseAll(); return ui.keyboardHolders() }
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
    // zu einer Seite (und einem Wert darauf) springen, z. B. von den Kacheln der Startseite
    signal settingsGo(string page, string key)
    function goSettings(page, key) { settingsGo(page || "home", key || "") }
    // Dashboard mit einem bestimmten Tab öffnen (z. B. Wallpaper von der Startseite)
    property string dashboardTab: ""
    function openDashboard(tab) { dashboardTab = tab || ""; openPanel("dashboard") }
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
        // ist das Element mit dieser Probe gerade da und sichtbar? (direkt, ohne das gepufferte Log)
        function visible(name: string): bool {
            const p = ui.probes[name]
            if (!p || !p.parent) return false
            for (let it = p.parent; it; it = it.parent) if (!it.visible || it.opacity === 0) return false
            return p.parent.width >= 4 && p.parent.height >= 4
        }
        // Endlage des offenen Panels mit Leuchten (glow = Grösse des Scheins, glowRoom = Platz im Fenster)
        function area(name: string): string { return JSON.stringify(ui.panelAreas[name] || {}) }
        // Kontrast von Text auf einer Karte über dem Glas über dem Hintergrundbild (WCAG, Ziel 4.5)
        function contrast(): real {
            const tl = Theme.lum(Qt.color(Theme.text)), lg = Theme.lum(Qt.color(Theme.glassColor)), lc = Theme.lum(Qt.color(Theme.cardBase))
            const ga = Qt.color(Theme.glass()).a, ca = Qt.color(Theme.card).a
            const bg = ca * lc + (1 - ca) * (ga * lg + (1 - ga) * Theme.wallpaperLuma)
            return Math.round((Math.max(tl, bg) + 0.05) / (Math.min(tl, bg) + 0.05) * 100) / 100
        }
        // aktuelle Design-Werte aus Theme (Karten, Pille, Leuchten, Abstände, Schrift) als JSON
        function theme(): string {
            const a = c => Math.round(Qt.color(c).a * 100) / 100   // Farben speichern 8 Bit: auf 0.01 genau
            return JSON.stringify({ card: a(Theme.card), cardHover: a(Theme.cardHover), cardBorder: a(Theme.cardBorder),
                                    cardColor: String(Theme.cardBase), pill: a(Theme.pill), glow: Theme.glow, glowSize: Theme.glowSize,
                                    glowOpacity: Theme.glowOpacity, panelPad: Theme.panelPad, cardPad: Theme.cardPad, gap: Theme.gap,
                                    pad10: Theme.pad(10), titleWeight: Theme.titleWeight, textWeight: Theme.textWeight,
                                    strongWeight: Theme.strongWeight, titleScale: Theme.titleScale, glass: a(Theme.glass()) })
        }
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
