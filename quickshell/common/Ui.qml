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
