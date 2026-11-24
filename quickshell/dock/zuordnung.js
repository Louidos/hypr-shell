.pragma library
// Zuordnung Fenster → Programm (Desktop-Eintrag) für das Dock. Reihenfolge:
// 1. StartupWMClass des Desktop-Eintrags, 2. Name/ID des Desktop-Eintrags, 3. class/app_id in
// Kleinschreibung, 4. Flatpak-ID (letzter Teil, z. B. org.gnome.Nautilus → nautilus),
// 5. Steam-Spiele über steam_app_<id> (steam_icon_<id>). Klappt nichts, liefert finde() null und
// das Dock zeigt ein eigenes Symbol mit dem Fenstertitel.

function klein(s) { return String(s || "").trim().toLowerCase() }

// ID ohne ".desktop"
function ohneEndung(id) { return klein(id).replace(/\.desktop$/, "") }

// letzter Teil einer umgekehrten Domain (org.mozilla.firefox → firefox)
function letzterTeil(s) { const p = klein(s).split("."); return p[p.length - 1] }

// Steam-Spiel? steam_app_570 → "570"
function steamId(appId) {
    const m = /^steam_app_(\d+)$/.exec(klein(appId))
    return m ? m[1] : ""
}

// entries: Liste von Desktop-Einträgen (id, name, startupClass, icon, noDisplay)
// byId: Funktion id → Eintrag oder null
function finde(appId, entries, byId) {
    const a = klein(appId)
    if (a === "") return null
    let i, e
    // 1. StartupWMClass
    for (i = 0; i < entries.length; i++) {
        e = entries[i]
        if (e && klein(e.startupClass) !== "" && klein(e.startupClass) === a) return e
    }
    // 2. ID oder Name des Desktop-Eintrags
    if (byId) {
        e = byId(appId) || byId(a)
        if (e) return e
    }
    for (i = 0; i < entries.length; i++) {
        e = entries[i]
        if (!e) continue
        if (ohneEndung(e.id) === a || klein(e.name) === a) return e
    }
    // 3. Klasse in Kleinschreibung gegen den letzten Teil der Eintrags-ID (z. B. kitty ↔ kitty,
    //    firefox ↔ org.mozilla.firefox)
    for (i = 0; i < entries.length; i++) {
        e = entries[i]
        if (e && letzterTeil(ohneEndung(e.id)) === a) return e
    }
    // 4. Flatpak-ID im Fenster (org.gnome.Nautilus) gegen einfache Eintrags-ID (nautilus)
    if (a.indexOf(".") > 0) {
        const t = letzterTeil(a)
        for (i = 0; i < entries.length; i++) {
            e = entries[i]
            if (e && (ohneEndung(e.id) === t || letzterTeil(ohneEndung(e.id)) === t)) return e
        }
    }
    // 5. Steam-Spiel: Eintrag mit Icon steam_icon_<id> oder Exec steam://rungameid/<id>
    const s = steamId(a)
    if (s !== "") {
        for (i = 0; i < entries.length; i++) {
            e = entries[i]
            if (!e) continue
            if (klein(e.icon) === "steam_icon_" + s) return e
            if (String(e.execString || "").indexOf("steam://rungameid/" + s) >= 0) return e
        }
    }
    return null
}

// Schlüssel, unter dem Fenster einer App zusammengefasst werden
function schluessel(appId, entry) {
    return entry ? "app:" + ohneEndung(entry.id) : "win:" + klein(appId)
}
