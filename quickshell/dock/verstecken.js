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
