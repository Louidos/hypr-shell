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

// ---- Drehung (monitors.outputs[].transform)
// Werte wie im Schema; Hyprland meldet die Zahl 0–7 (wl_output_transform, gegen den Uhrzeigersinn)
const DREHUNGEN = ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]

// Zahl aus "hyprctl monitors -j" (transform) oder Text → Wert wie im Schema ("normal" bei Unsinn)
function transformName(v) {
    if (typeof v === "number" && v >= 0 && v <= 7 && Math.floor(v) === v) return DREHUNGEN[v]
    return DREHUNGEN.indexOf(String(v)) >= 0 ? String(v) : "normal"
}
// "flipped-90" → { grad: 90, mirrored: true }
function parts(v) {
    const n = transformName(v)
    const mirrored = n.indexOf("flipped") === 0
    const rest = mirrored ? n.replace(/^flipped-?/, "") : n
    return { grad: rest === "" || rest === "normal" ? 0 : Number(rest), mirrored: mirrored }
}
// { grad, mirrored } → Wert wie im Schema
function compose(grad, mirrored) {
    const g = [0, 90, 180, 270].indexOf(Number(grad)) >= 0 ? Number(grad) : 0
    if (mirrored) return g === 0 ? "flipped" : "flipped-" + g
    return g === 0 ? "normal" : String(g)
}
// Text für die Anzeige: "normal", "90°", "180° mirrored"
function label2(v) {
    const p = parts(v)
    return (p.grad === 0 ? (p.mirrored ? "0°" : "normal") : p.grad + "°") + (p.mirrored ? " mirrored" : "")
}

// Fläche eines Bildschirms in logischen Pixeln (Skalierung und Drehung eingerechnet); transform
// darf eine Zahl (Hyprland) oder ein Wert aus dem Schema sein
function rect(m, transform) {
    const s = Number(m.scale) > 0 ? Number(m.scale) : 1
    let w = (Number(m.width) || 0) / s, h = (Number(m.height) || 0) / s
    const t = DREHUNGEN.indexOf(transformName(transform === undefined ? m.transform : transform))
    if (t % 2 === 1) { const x = w; w = h; h = x }
    return { x: Number(m.x) || 0, y: Number(m.y) || 0, w: w, h: h }
}
// überlappen sich zwei Bildschirme? (monitore: Liste aus hyprctl; neu: { name: transform } für die
// gewählten, noch nicht übernommenen Drehungen)
function overlaps(monitore, neu) {
    const l = (monitore || []).map(m => rect(m, neu && neu[m.name] !== undefined ? neu[m.name] : m.transform))
    for (let i = 0; i < l.length; i++)
        for (let j = i + 1; j < l.length; j++) {
            const a = l[i], b = l[j]
            if (a.x < b.x + b.w - 0.5 && b.x < a.x + a.w - 0.5 && a.y < b.y + b.h - 0.5 && b.y < a.y + a.h - 0.5) return true
        }
    return false
}
