pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Einstellungen von hypr-shell. Eine Quelle: ~/.config/hypr-shell/settings.json.
// - Ändert sich die Datei, ruft dieser Teil (entprellt) shell-apply auf. shell-apply prüft jeden
//   Wert gegen das Schema, erzeugt die Dateien für Hyprland, Waybar, hypridle, hyprlock und rofi und
//   schreibt die gültigen Werte nach ~/.local/share/hypr-shell/settings.effective.json.
// - Die Oberfläche liest diese gültigen Werte (ein falscher Wert oder kaputtes JSON bricht also nichts).
// - Fehlen sie (shell-apply lief noch nie), gilt settings.json über den Standardwerten des Schemas.
Singleton {
    id: s

    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER")
    readonly property string dataDir: home + "/.local/share/hypr-shell"
    readonly property string file: home + "/.config/hypr-shell/settings.json"
    readonly property string bin: home + "/.local/bin/"

    property var schema: ({ pages: [], keys: [] })
    property var defaults: ({})
    property var raw: ({})
    property var effective: null
    readonly property var data: merge(defaults, effective !== null ? effective : raw)

    function merge(a, b) {
        if (b === undefined || b === null) return a
        if (typeof a !== "object" || a === null || Array.isArray(a) || typeof b !== "object" || Array.isArray(b)) return b
        const r = Object.assign({}, a)
        for (const k in b) r[k] = merge(a[k], b[k])
        return r
    }
    function lookup(obj, path) {
        let v = obj
        const parts = path.split(".")
        for (let i = 0; i < parts.length; i++) {
            if (v === undefined || v === null || typeof v !== "object") return undefined
            v = v[parts[i]]
        }
        return v
    }
    // get("desktop.clock.x", 0.02)
    function get(path, fallback) {
        const v = lookup(data, path)
        return v === undefined || v === null ? fallback : v
    }
    // Wert direkt aus settings.json (undefined = nicht gesetzt, es gilt der Standard)
    function rawValue(path) { return lookup(raw, path) }
    function schemaKey(key) {
        const l = schema.keys || []
        for (let i = 0; i < l.length; i++) if (l[i].key === key) return l[i]
        return null
    }

    // Profilbild ~/.face: fehlt es, bleibt die Quelle leer und die Panels zeigen den Anfangsbuchstaben
    // (statt bei jedem Öffnen „Cannot open“ ins Log zu schreiben). checkFace() beim Öffnen eines Panels.
    property bool hasFace: false
    readonly property string face: hasFace ? "file://" + home + "/.face" : ""
    function checkFace() { faceFile.reload() }
    FileView {
        id: faceFile
        path: s.home + "/.face"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: s.hasFace = true
        onLoadFailed: s.hasFace = false
    }

    // Bildschirm aus den Einstellungen (Name), sonst der erste
    function screenFor(name) {
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++) if (list[i].name === name) return list[i]
        return list.length > 0 ? list[0] : null
    }

    // shell-apply anstossen (entprellt; läuft er schon, folgt genau ein weiterer Lauf)
    property bool applyAgain: false
    function apply() { applyTimer.restart() }
    Timer {
        id: applyTimer
        interval: 250
        onTriggered: {
            if (applyProc.running) s.applyAgain = true
            else applyProc.running = true
        }
    }
    Process {
        id: applyProc
        command: [s.bin + "shell-apply"]
        onExited: if (s.applyAgain) { s.applyAgain = false; applyProc.running = true }
    }
    Component.onCompleted: apply()

    FileView {
        path: s.dataDir + "/schema.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const sc = JSON.parse(text())
                const d = {}
                for (let i = 0; i < sc.keys.length; i++) {
                    const p = sc.keys[i].key.split(".")
                    let o = d
                    for (let j = 0; j < p.length - 1; j++) { if (typeof o[p[j]] !== "object") o[p[j]] = {}; o = o[p[j]] }
                    o[p[p.length - 1]] = sc.keys[i].default
                }
                s.schema = sc
                s.defaults = d
            } catch (e) { console.warn("hypr-shell: schema.json kann nicht gelesen werden") }
        }
    }
    FileView {
        path: s.file
        watchChanges: true
        onFileChanged: { reload(); s.apply() }
        onLoaded: {
            try { const r = JSON.parse(text()); if (typeof r === "object" && r !== null && !Array.isArray(r)) s.raw = r }
            catch (e) { /* kaputtes JSON: shell-apply meldet das, der letzte gültige Stand bleibt */ }
        }
        onLoadFailed: s.raw = ({})
    }
    FileView {
        path: s.dataDir + "/settings.effective.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { s.effective = JSON.parse(text()) } catch (e) { } }
    }
}
