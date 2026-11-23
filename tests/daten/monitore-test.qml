import QtQuick
import "../../quickshell/settings/monitore.js" as M

// Rechenteil der Seite Monitors (quickshell/settings/monitore.js) ohne Oberfläche, gestartet von
// tests/monitore.sh mit dem qml-Werkzeug von Qt. Gibt "ok: …" bzw. "FEHLER: …" aus.
Item {
    property int fehler: 0
    function pruefe(bed, text) { console.warn((bed ? "  ok: " : "  FEHLER: ") + text); if (!bed) fehler++ }
    function aufl(l) { return l.map(m => m.res).join(",") }

    Component.onCompleted: {
        const modi = ["3840x2160@60.00Hz", "3840x2160@30.00Hz", "2560x1600@165.00Hz", "2560x1440@144.00Hz",
                      "1920x1200@60.00Hz", "1920x1080@120.00Hz", "1920x1080@59.94Hz", "1680x1050@60.00Hz",
                      "1280x720@60.00Hz", "kaputt", "800x600@60.00Hz"]
        let l = M.modes({ width: 3840, height: 2160, refreshRate: 60, availableModes: modi }, "", 6)
        pruefe(aufl(l) === "3840x2160,2560x1600,2560x1440,1920x1200,1920x1080,1680x1050", "die grössten sechs, jede Auflösung einmal: " + aufl(l))
        pruefe(l[0].hz === 60 && l[4].hz === 120, "je Auflösung die höchste Bildrate")
        l = M.modes({ width: 1280, height: 720, refreshRate: 59.9, availableModes: modi }, "", 6)
        pruefe(l.length === 7 && aufl(l).indexOf("1280x720") >= 0, "laufende Auflösung ausserhalb der sechs erscheint trotzdem: " + aufl(l))
        l = M.modes({ width: 3840, height: 2160, availableModes: modi }, "800x600", 6)
        pruefe(aufl(l).indexOf("800x600") >= 0 && l.length === 7, "eingestellte Auflösung erscheint trotzdem: " + aufl(l))
        l = M.modes({ width: 1366, height: 768, refreshRate: 60.02, availableModes: modi }, "1366x768", 6)
        pruefe(aufl(l).split(",").filter(x => x === "1366x768").length === 1 && l.find(m => m.res === "1366x768").hz === 60,
               "laufender Modus, den availableModes nicht kennt: einmal, mit seiner Bildrate")
        l = M.modes({ name: "HEADLESS-1", width: 1920, height: 1080 }, "", 6)
        pruefe(aufl(l) === "1920x1080" && M.label(l[0]) === "1920x1080", "ohne Modi (kein Hyprland): nur die laufende, ohne \"@ 0 Hz\"")
        pruefe(M.modes(null, "", 6).length === 0 && M.modes({}, "unsinn", 6).length === 0, "leere oder kaputte Angaben brechen nichts")
        pruefe(M.label({ res: "2560x1600", hz: 165 }) === "2560x1600 @ 165 Hz", "Beschriftung")
        ende.start()
    }
    // erst nach dem Laden beenden (sonst meldet qml "Did not load any objects")
    Timer { id: ende; interval: 0; onTriggered: Qt.exit(parent.fehler === 0 ? 0 : 1) }
}
