pragma Singleton
import QtQuick
import Quickshell

// Ist eine persönliche Anbindung eingeschaltet? Alle sind nach der Installation aus. Jede Gruppe
// fragt hier, bevor sie etwas startet oder anzeigt (kein Panel, kein Tab, keine Abfrage, wenn aus).
// Abhängige Schalter gelten nur, wenn ihr Grundschalter an ist (z. B. der Agent nur mit Missa).
// Auf der Befehlszeile: shell-set get missa.enabled
Singleton {
    readonly property bool missa: Settings.get("missa.enabled", false) === true
    readonly property bool missaAgent: missa && Settings.get("missa.agent_enabled", false) === true
    readonly property bool missaVoice: missa && Settings.get("missa.voice_enabled", false) === true
    readonly property bool nextcloud: Settings.get("nextcloud.enabled", false) === true
    readonly property bool lab: missa && Settings.get("lab.enabled", false) === true
    readonly property bool calendar: Settings.get("calendar.enabled", false) === true
    readonly property bool sensor: Settings.get("sensor.enabled", false) === true
    readonly property bool gamesCustom: Settings.get("games.custom_enabled", false) === true

    // Schlüssel wie "missa.agent_enabled" → eingeschaltet und Abhängigkeit erfüllt?
    function on(key) {
        const spec = Settings.schemaKey(key)
        if (Settings.get(key, false) !== true) return false
        return !spec || !spec.depends || on(spec.depends)
    }
}
