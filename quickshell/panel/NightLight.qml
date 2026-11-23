import QtQuick
import Quickshell
import "../common"

// Zeitplan des Nachtlichts (nightlight.schedule, nightlight.from, nightlight.to): schaltet zu den
// eingestellten Zeiten über shell-toggle ein und aus. Dazwischen gilt, was man im Panel schaltet.
// Läuft nur, wenn der Zeitplan eingeschaltet ist (eine Prüfung pro Minute, kein Prozess dazwischen).
Scope {
    id: nl
    readonly property bool active: Settings.get("nightlight.schedule", false)
    readonly property string from: Settings.get("nightlight.from", "20:00")
    readonly property string to: Settings.get("nightlight.to", "07:00")
    property string last: ""   // zuletzt angewendeter Zustand ("on"/"off")

    function minutes(t) { const p = String(t).split(":"); return parseInt(p[0]) * 60 + parseInt(p[1]) }
    // soll jetzt an sein? (über Mitternacht: 20:00–07:00)
    function wanted() {
        const d = new Date(), m = d.getHours() * 60 + d.getMinutes()
        const a = minutes(from), b = minutes(to)
        return a <= b ? (m >= a && m < b) : (m >= a || m < b)
    }
    function check() {
        if (!active) return
        const w = wanted() ? "on" : "off"
        if (w === last) return
        last = w
        Quickshell.execDetached([Settings.bin + "shell-toggle", "nightlight", w])
    }
    onActiveChanged: { last = ""; check() }
    onFromChanged: { last = ""; check() }
    onToChanged: { last = ""; check() }
    Timer { interval: 60000; running: nl.active; repeat: true; triggeredOnStart: true; onTriggered: nl.check() }
}
