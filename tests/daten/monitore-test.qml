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
        // Drehung
        pruefe(M.transformName(0) === "normal" && M.transformName(1) === "90" && M.transformName(3) === "270" && M.transformName(5) === "flipped-90" && M.transformName(7) === "flipped-270", "Zahl aus Hyprland → Wert (0 normal, 1 90, 3 270, 5 flipped-90, 7 flipped-270)")
        pruefe(M.transformName(9) === "normal" && M.transformName("quer") === "normal" && M.transformName(undefined) === "normal", "Unsinn oder fehlend (alte Einträge) → normal")
        const p = M.parts("flipped-180")
        pruefe(p.grad === 180 && p.mirrored && M.parts("flipped").grad === 0 && M.parts("flipped").mirrored && !M.parts("90").mirrored, "Wert → Grad und gespiegelt")
        pruefe(M.compose(90, false) === "90" && M.compose(0, false) === "normal" && M.compose(0, true) === "flipped" && M.compose(270, true) === "flipped-270" && M.compose(45, false) === "normal", "Grad und gespiegelt → Wert")
        let alle = true
        for (let i = 0; i < 8; i++) { const q = M.parts(M.transformName(i)); if (M.compose(q.grad, q.mirrored) !== M.transformName(i)) alle = false }
        pruefe(alle, "alle acht Werte hin und zurück")
        pruefe(M.label2("normal") === "normal" && M.label2("90") === "90°" && M.label2("flipped-180") === "180° mirrored", "Beschriftung der Drehung")
        // Überlappung nach dem Drehen (zwei Bildschirme nebeneinander, feste Lage)
        const zwei = [{ name: "eDP-1", width: 2560, height: 1600, scale: 1.6, x: 0, y: 0, transform: 0 },
                      { name: "DP-1", width: 1920, height: 1080, scale: 1, x: 1600, y: 0, transform: 0 }]
        pruefe(!M.overlaps(zwei, {}), "nebeneinander: keine Überlappung")
        const r = M.rect(zwei[0], "90")
        pruefe(r.w === 1000 && r.h === 1600, "gedreht: Breite und Höhe vertauscht (logisch 1000×1600)")
        pruefe(!M.overlaps(zwei, { "eDP-1": "90" }), "links schmaler gedreht: keine Überlappung")
        pruefe(M.overlaps([zwei[0], { name: "DP-1", width: 1920, height: 1080, scale: 1, x: 1000, y: 0, transform: 0 }], { "DP-1": "normal" }) === true, "überlappende Lage wird erkannt")
        pruefe(M.overlaps([{ name: "A", width: 1920, height: 1080, scale: 1, x: 0, y: 0, transform: 0 }, { name: "B", width: 1920, height: 1080, scale: 1, x: 1920, y: 0, transform: 0 }], { A: "flipped-270" }) === false
               && M.overlaps([{ name: "A", width: 1920, height: 1080, scale: 1, x: 0, y: 0, transform: 0 }, { name: "B", width: 1920, height: 1080, scale: 1, x: 0, y: 1080, transform: 0 }], { A: "90" }) === true,
               "hochkant gedreht über einem anderen: Überlappung")
        ende.start()
    }
    // erst nach dem Laden beenden (sonst meldet qml "Did not load any objects")
    Timer { id: ende; interval: 0; onTriggered: Qt.exit(parent.fehler === 0 ? 0 : 1) }
}
