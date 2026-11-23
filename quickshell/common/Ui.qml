pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Gemeinsamer Zustand der Oberfläche: Einstellungs-App offen/zu und welche Seite, und das Schreiben
// von Einstellungen über shell-set (die App schreibt nie selbst in settings.json).
Singleton {
    id: ui

    property bool settingsOpen: false
    property string settingsPage: "home"
    // Schlüssel, zu dem die App nach dem Öffnen springen soll (Suche)
    property string settingsFocus: ""
    // Suchtext von aussen (IPC "settings search", z. B. im Oberflächentest)
    property string settingsSearch: ""

    function openSettings(page) {
        if (page && page !== "") settingsPage = page
        settingsOpen = true
    }
    function closeSettings() { settingsOpen = false }
    function toggleSettings(page) { if (settingsOpen) closeSettings(); else openSettings(page) }

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
