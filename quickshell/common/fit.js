.pragma library
// Rechenteil der Grössen-Hilfe (ScreenFit.qml), ohne Oberfläche getestet in
// tests/bildschirmgroessen.sh. Alle Werte in logischen Pixeln.

// Grössenfaktor nach der kürzeren Bildschirmseite: 1 im üblichen Bereich (1080–1440), darunter
// kleiner (höchstens auf 0.85, z. B. 1280×720), darüber grösser (höchstens 2, z. B. 4K mit Skalierung 1)
function faktor(w, h) {
    const k = Math.min(Number(w) || 1280, Number(h) || 720)
    if (k < 1080) return Math.max(0.85, k / 1080)
    if (k > 1440) return Math.min(2, k / 1440)
    return 1
}

// Wunschwert mal Faktor, begrenzt auf [min, max]; max gewinnt (passt auf den Bildschirm)
function fit(want, k, min, max) {
    let v = Number(want) * (k > 0 ? k : 1)
    if (min !== undefined && min !== null) v = Math.max(Number(min), v)
    if (max !== undefined && max !== null) v = Math.min(Number(max), v)
    return Math.max(0, v)
}

// Rand, den Leiste und ein reservierendes Dock belegen: {top, bottom, left, right}
function rand(o) {
    const r = { top: 0, bottom: 0, left: 0, right: 0 }
    const bar = Math.max(0, Number(o.barHeight) || 0)
    r[o.barPosition === "bottom" ? "bottom" : "top"] += bar
    const monitor = String(o.dockMonitor || "all")
    const hier = monitor === "all" || (monitor === "primary" ? o.screenName === o.firstScreen : monitor === o.screenName)
    if (o.dockEnabled !== false && o.dockMode === "reserve" && hier) {
        const kante = ["top", "bottom", "left", "right"].indexOf(o.dockPosition) >= 0 ? o.dockPosition : "bottom"
        r[kante] += (Number(o.dockMargin) || 0) + Math.round((Number(o.dockIcon) || 48) * (o.factor || 1)) + 2 * (Number(o.dockPadding) || 0)
    }
    return r
}

// Panel auf den freien Platz begrenzen. Eingaben in Bildschirmpixeln (Platz) und Entwurfsgrösse
// (want), Ergebnis in Entwurfseinheiten (vor dem Faktor k): {w, h, scroll}. scroll = der Inhalt
// ist höher als der Platz und muss rollen.
function panel(wantW, wantH, roomW, roomH, k) {
    const s = k > 0 ? k : 1
    const w = Math.max(1, Math.min(Number(wantW) || 1, roomW / s))
    const h = Math.max(1, Math.min(Number(wantH) || 1, roomH / s))
    return { w: w, h: h, scroll: (Number(wantH) || 0) > h + 0.5 }
}
