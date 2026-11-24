import QtQuick
import "../../quickshell/common/fit.js" as F

// Rechenteil der Grössen-Hilfe (quickshell/common/fit.js) ohne Oberfläche, gestartet von
// tests/bildschirmgroessen.sh mit dem qml-Werkzeug von Qt. Gibt "ok: …" bzw. "FEHLER: …" aus.
Item {
    property int fehler: 0
    function pruefe(bed, text) { console.warn((bed ? "  ok: " : "  FEHLER: ") + text); if (!bed) fehler++ }
    function nah(a, b) { return Math.abs(a - b) < 0.001 }

    Component.onCompleted: {
        // Faktor nach der kürzeren Seite (logische Pixel nach der Skalierung)
        pruefe(F.faktor(1920, 1080) === 1 && F.faktor(2560, 1440) === 1 && F.faktor(1600, 1000) > 0.92, "üblicher Bereich: Faktor 1 (Laptop 2560×1600 mit 1.6: " + F.faktor(1600, 1000).toFixed(3) + ")")
        pruefe(F.faktor(1280, 720) === 0.85 && F.faktor(1024, 600) === 0.85, "kleiner Bildschirm: nie unter 0.85")
        pruefe(nah(F.faktor(3840, 2160), 1.5) && F.faktor(7680, 4320) === 2, "4K mit Skalierung 1: 1.5, nie über 2")
        pruefe(F.faktor(1600, 2560) === F.faktor(2560, 1600) && F.faktor(1080, 1920) === 1, "Hochformat: gleicher Faktor wie quer")
        pruefe(F.faktor(0, 0) === 0.85 && F.faktor(undefined, undefined) === 0.85, "ohne Bildschirm: kleinste Grösse")
        // fit(wunsch, faktor, min, max)
        pruefe(F.fit(400, 1) === 400 && F.fit(400, 1.5) === 600, "Wunsch mal Faktor")
        pruefe(F.fit(400, 1, 300, 350) === 350 && F.fit(100, 1, 300, 350) === 300, "begrenzt auf min und max")
        pruefe(F.fit(400, 1, 500, 350) === 350, "max gewinnt (passt auf den Bildschirm)")
        // Rand von Leiste und Dock
        const r = o => F.rand(Object.assign({ barPosition: "top", barHeight: 30, dockEnabled: true, dockMode: "floating", dockPosition: "bottom",
                                               dockMonitor: "all", dockMargin: 10, dockIcon: 48, dockPadding: 8, screenName: "A", firstScreen: "A", factor: 1 }, o))
        let x = r({})
        pruefe(x.top === 30 && x.bottom === 0 && x.left === 0, "Leiste oben 30 px, schwebendes Dock reserviert nichts")
        x = r({ barPosition: "bottom", dockMode: "reserve" })
        pruefe(x.top === 0 && x.bottom === 30 + 10 + 48 + 16, "Leiste unten und reservierendes Dock: " + x.bottom)
        x = r({ dockMode: "reserve", dockPosition: "left", dockMonitor: "B" })
        pruefe(x.left === 0, "Dock auf einem anderen Bildschirm reserviert hier nichts")
        x = r({ dockMode: "reserve", dockPosition: "left", dockMonitor: "primary", factor: 1.5 })
        pruefe(x.left === 10 + 72 + 16, "Dock links auf dem ersten Bildschirm, mit Faktor: " + x.left)
        x = r({ dockMode: "reserve", dockEnabled: false })
        pruefe(x.bottom === 0, "Dock aus: kein Rand")
        x = r({ dockMode: "reserve", dockGivesWay: true })
        pruefe(x.bottom === 0 && x.top === 30, "Dock fährt für Panels weg (dock.when_panel_open = hide): Panel bekommt die volle Höhe")
        // Panel auf den Platz begrenzen (Entwurf 1100×700, Platz in Bildschirmpixeln)
        let p = F.panel(1100, 700, 1904, 1000, 1)
        pruefe(p.w === 1100 && p.h === 700 && !p.scroll, "passt: Entwurfsgrösse")
        p = F.panel(1100, 700, 1264, 644, 0.85)
        pruefe(p.w === 1100 && p.h === 700 && !p.scroll, "1280×720 mit Faktor 0.85: passt ganz (" + Math.round(p.w * 0.85) + "×" + Math.round(p.h * 0.85) + " px)")
        p = F.panel(1100, 900, 1264, 644, 1)
        pruefe(p.w === 1100 && p.h === 644 && p.scroll, "zu hoch: begrenzt, Inhalt rollt")
        p = F.panel(1000, 400, 700, 2400, 1)
        pruefe(p.w === 700 && p.h === 400 && !p.scroll, "zu breit (Hochformat): schmaler, nicht abgeschnitten")
        p = F.panel(1000, 400, 3820, 2100, 1.5)
        pruefe(p.w === 1000 && p.h === 400 && p.w * 1.5 === 1500, "4K: Entwurf passt, auf dem Bildschirm 1.5-mal so gross")
        ende.start()
    }
    // erst nach dem Laden beenden (sonst meldet qml "Did not load any objects")
    Timer { id: ende; interval: 0; onTriggered: Qt.exit(parent.fehler === 0 ? 0 : 1) }
}
