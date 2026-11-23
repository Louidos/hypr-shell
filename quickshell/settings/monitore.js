.pragma library
// Rechenteil der Seite Monitors (ohne Oberfläche, getestet in tests/monitore.sh).

// Modi aus "hyprctl monitors -j" (availableModes wie "2560x1600@165.00Hz") → einmalige Auflösungen
// mit der höchsten Bildrate, die grössten zuerst, höchstens max Stück. Die laufende Auflösung des
// Bildschirms und die eingestellte (eingestellt, z. B. "1920x1080") sind immer dabei, auch wenn sie
// nicht zu den grössten gehören oder in der Liste fehlen.
function modes(m, eingestellt, max) {
    const grenze = max > 0 ? max : 6
    const r = {}
    for (const s of ((m && m.availableModes) || [])) {
        const x = /^(\d+x\d+)@([\d.]+)Hz$/.exec(String(s))
        if (!x) continue
        const hz = Math.round(Number(x[2]))
        if (!r[x[1]] || r[x[1]] < hz) r[x[1]] = hz
    }
    const eintrag = (res, hz) => ({ res: res, hz: hz, px: Number(res.split("x")[0]) * Number(res.split("x")[1]) })
    const alle = Object.keys(r).map(k => eintrag(k, r[k])).sort((a, b) => b.px - a.px)
    const liste = alle.slice(0, grenze)
    const aktuell = m && m.width > 0 && m.height > 0 ? m.width + "x" + m.height : ""
    for (const res of [aktuell, String(eingestellt || "")]) {
        if (!/^\d+x\d+$/.test(res) || liste.some(e => e.res === res)) continue
        const da = alle.find(e => e.res === res)
        liste.push(da || eintrag(res, res === aktuell ? Math.round(Number(m.refreshRate) || 0) : 0))
    }
    return liste.sort((a, b) => b.px - a.px)
}

// Beschriftung eines Modus: "1920x1080 @ 60 Hz", ohne bekannte Bildrate nur die Auflösung
function label(mode) { return mode.res + (mode.hz > 0 ? " @ " + mode.hz + " Hz" : "") }
