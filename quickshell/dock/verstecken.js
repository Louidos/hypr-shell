.pragma library
// Logik für dock.autohide = smart: Überdeckt ein Fenster die Fläche des Docks?
// dock: {x, y, width, height} in Bildschirmkoordinaten (logische Pixel, wie Hyprland).
// fenster: [{x, y, width, height, sichtbar}] – nur Fenster der aktiven Arbeitsfläche des
// Bildschirms, versteckte (sichtbar = false) zählen nicht. Berührung an der Kante zählt nicht.
function ueberdeckt(dock, fenster) {
    if (!dock || dock.width <= 0 || dock.height <= 0) return false
    for (let i = 0; i < (fenster || []).length; i++) {
        const f = fenster[i]
        if (!f || f.sichtbar === false || f.width <= 0 || f.height <= 0) continue
        if (f.x < dock.x + dock.width && f.x + f.width > dock.x && f.y < dock.y + dock.height && f.y + f.height > dock.y) return true
    }
    return false
}

// Fenster aus Hyprland (HyprlandToplevel.lastIpcObject) für einen Bildschirm und dessen aktive Arbeitsfläche
function ausHyprland(toplevels, monitorName, workspaceId) {
    const out = []
    for (let i = 0; i < (toplevels || []).length; i++) {
        const o = toplevels[i] ? toplevels[i].lastIpcObject : null
        if (!o || !o.at || !o.size) continue
        if (o.hidden === true || o.mapped === false) continue
        const ws = o.workspace ? o.workspace.id : undefined
        if (workspaceId !== undefined && ws !== workspaceId) continue
        out.push({ x: o.at[0], y: o.at[1], width: o.size[0], height: o.size[1], sichtbar: true, fullscreen: !!o.fullscreen })
    }
    return out
}

// ---- Vollbild (dock.hide_on_fullscreen) unter Hyprland
// Hyprland meldet je Arbeitsfläche hasFullscreen. Wird ein Fenster im Vollbild geschlossen, schickt
// Hyprland aber kein "fullscreen>>0": Quickshell lässt hasFullscreen dann auf true stehen und das
// Dock bliebe auf diesem Bildschirm weg. Deshalb gilt hasFullscreen nur, solange auf der aktiven
// Arbeitsfläche noch ein lebendes Fenster im Vollbild (oder maximiert) ist.
// fenster: [{ws, vollbild, lebt, adresse, klasse}] (siehe fensterAusHyprland)
function vollbildFenster(fenster, wsId) {
    const out = []
    for (let i = 0; i < (fenster || []).length; i++) {
        const f = fenster[i]
        if (!f || f.lebt === false || f.vollbild !== true) continue
        if (wsId === undefined || wsId === null || f.ws !== wsId) continue
        out.push(f)
    }
    return out
}
function vollbild(hasFullscreen, wsId, fenster) {
    return hasFullscreen === true && vollbildFenster(fenster, wsId).length > 0
}
// Begründung für die Diagnose (shell-diag dock): warum gilt der Bildschirm (nicht) als Vollbild?
function grund(hasFullscreen, wsId, fenster, gaming) {
    if (gaming) return "gaming"
    const n = vollbildFenster(fenster, wsId).length
    if (hasFullscreen === true && n > 0) return "fullscreen-window"
    if (hasFullscreen === true) return "stale-hasfullscreen-ignored"
    return "none"
}
// HyprlandToplevel → {ws, vollbild, lebt, adresse, klasse}. lebende: Fenster von ToplevelManager
// (Wayland); ein Hyprland-Fenster, dessen Wayland-Fenster dort fehlt, ist schon geschlossen.
function fensterAusHyprland(toplevels, lebende) {
    const out = []
    for (let i = 0; i < (toplevels || []).length; i++) {
        const t = toplevels[i]
        if (!t) continue
        const o = t.lastIpcObject || {}
        const ws = t.workspace ? t.workspace.id : o.workspace ? o.workspace.id : undefined
        const wl = t.wayland || null
        // Wayland meldet Vollbild sofort, Hyprland (fullscreen: 1 maximiert, 2 Vollbild) nach dem Neuholen
        const fs = (wl !== null && wl.fullscreen === true) || o.fullscreen === true || Number(o.fullscreen) > 0
        let lebt = o.mapped !== false
        if (wl !== null && lebende) lebt = lebt && lebende.indexOf(wl) >= 0
        out.push({ ws: ws, vollbild: fs, lebt: lebt, adresse: String(t.address || o.address || ""), klasse: String(o.class || (wl ? wl.appId : "") || "") })
    }
    return out
}
