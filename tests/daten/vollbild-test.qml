import QtQuick
import "../../quickshell/dock/verstecken.js" as V

// Vollbild-Logik des Docks (quickshell/dock/verstecken.js) ohne Oberfläche, gestartet von
// tests/dock.sh mit dem qml-Werkzeug von Qt. Gibt "ok: …" bzw. "FEHLER: …" aus.
// Kernfall: Hyprland lässt hasFullscreen nach dem Schliessen eines Vollbild-Fensters stehen –
// das Dock darf dann nicht weg bleiben.
Item {
    property int fehler: 0
    function pruefe(bed, text) { console.warn((bed ? "  ok: " : "  FEHLER: ") + text); if (!bed) fehler++ }

    Component.onCompleted: {
        const wlA = { fullscreen: true, appId: "mpv" }, wlB = { fullscreen: false, appId: "kitty" }
        const wlC = { fullscreen: false, appId: "steam_app_570" }
        // Hyprland-Fenster wie Quickshell sie liefert: Arbeitsfläche 1 (Bildschirm 1), 5 (Bildschirm 2)
        const hA = { address: "55aa", workspace: { id: 1 }, wayland: wlA, lastIpcObject: { fullscreen: 2, class: "mpv", workspace: { id: 1 } } }
        const hB = { address: "55bb", workspace: { id: 1 }, wayland: wlB, lastIpcObject: { fullscreen: 0, class: "kitty", workspace: { id: 1 } } }
        const hC = { address: "55cc", workspace: { id: 5 }, wayland: wlC, lastIpcObject: { fullscreen: 2, class: "steam_app_570", workspace: { id: 5 } } }

        // 1. Vollbild offen: Dock auf diesem Bildschirm weg
        let f = V.fensterAusHyprland([hA, hB, hC], [wlA, wlB, wlC])
        pruefe(f.length === 3 && f[0].vollbild && !f[1].vollbild && f[0].ws === 1 && f[0].klasse === "mpv", "Fenster aus Hyprland: Arbeitsfläche, Vollbild, Klasse")
        pruefe(V.vollbild(true, 1, f), "Vollbild-Fenster offen, hasFullscreen: Bildschirm gilt als Vollbild")
        pruefe(V.grund(true, 1, f, false) === "fullscreen-window", "Grund: Vollbild-Fenster")

        // 2. Fenster geschlossen, hasFullscreen hängt (kein fullscreen>>0 von Hyprland)
        f = V.fensterAusHyprland([hB, hC], [wlB, wlC])
        pruefe(!V.vollbild(true, 1, f), "geschlossen, hasFullscreen hängt auf true: KEIN Vollbild – das Dock kommt zurück")
        pruefe(V.grund(true, 1, f, false) === "stale-hasfullscreen-ignored", "Grund: veraltetes hasFullscreen wird ignoriert")
        // Quickshell hat das Hyprland-Fenster noch, das Wayland-Fenster ist aber schon weg
        f = V.fensterAusHyprland([hA, hB, hC], [wlB, wlC])
        pruefe(!V.vollbild(true, 1, f), "Hyprland-Fenster noch in der Liste, Wayland-Fenster schon zu: zählt nicht")
        // Hyprland meldet das Fenster als nicht mehr gezeigt
        const hAzu = { address: "55aa", workspace: { id: 1 }, wayland: null, lastIpcObject: { fullscreen: 2, mapped: false, workspace: { id: 1 } } }
        pruefe(!V.vollbild(true, 1, V.fensterAusHyprland([hAzu, hB], [wlB])), "mapped = false: zählt nicht")

        // 3. zweiter Bildschirm: Vollbild dort stört den ersten nicht und umgekehrt
        f = V.fensterAusHyprland([hB, hC], [wlB, wlC])
        pruefe(V.vollbild(true, 5, f), "Spiel im Vollbild auf Bildschirm 2: dort Vollbild")
        pruefe(!V.vollbild(false, 1, f), "Bildschirm 1 ohne hasFullscreen: kein Vollbild, auch wenn Bildschirm 2 eines hat")
        pruefe(!V.vollbild(true, 1, f), "Bildschirm 1 mit hängendem hasFullscreen: kein Vollbild, das Spiel auf Bildschirm 2 zählt nicht")
        pruefe(!V.vollbild(true, 5, V.fensterAusHyprland([hB], [wlB])), "Spiel auf Bildschirm 2 geschlossen: dort wieder kein Vollbild")

        // 4. Wayland meldet Vollbild sofort, Hyprland erst nach dem Neuholen
        const hD = { address: "55dd", workspace: { id: 2 }, wayland: { fullscreen: true }, lastIpcObject: {} }
        pruefe(V.vollbild(true, 2, V.fensterAusHyprland([hD], null)), "frisches Fenster ohne Hyprland-Daten, Wayland sagt Vollbild: Vollbild")
        // maximiert (Andocken oben / Maximieren-Knopf): Hyprland fullscreen 1, wie bisher
        const hM = { address: "55ee", workspace: { id: 3 }, wayland: { fullscreen: false }, lastIpcObject: { fullscreen: 1, workspace: { id: 3 } } }
        pruefe(V.vollbild(true, 3, V.fensterAusHyprland([hM], null)), "maximiert (Modus 1) mit hasFullscreen: wie bisher Vollbild")
        pruefe(!V.vollbild(true, 3, []), "maximiertes Fenster geschlossen: kein Vollbild")
        // ohne hasFullscreen nie Vollbild (Verhalten während eines Vollbilds unverändert)
        pruefe(!V.vollbild(false, 1, V.fensterAusHyprland([hA], [wlA])), "hasFullscreen false: kein Vollbild")

        // 5. Gaming-Modus und kaputte Angaben
        pruefe(V.grund(false, 1, [], true) === "gaming" && V.grund(false, 1, [], false) === "none", "Grund: Gaming-Modus bzw. nichts")
        pruefe(!V.vollbild(true, undefined, f) && !V.vollbild(true, 1, null) && V.fensterAusHyprland(null, null).length === 0
               && V.fensterAusHyprland([null, {}], []).length === 1, "fehlende oder kaputte Angaben brechen nichts")
        pruefe(V.vollbildFenster([{ ws: 1, vollbild: true, lebt: true }, { ws: 1, vollbild: true, lebt: false }, { ws: 2, vollbild: true }], 1).length === 1,
               "vollbildFenster: nur lebende auf der Arbeitsfläche")

        console.warn(fehler === 0 ? "ERGEBNIS ok" : "ERGEBNIS FEHLER " + fehler)
        Qt.exit(fehler === 0 ? 0 : 1)
    }
}
