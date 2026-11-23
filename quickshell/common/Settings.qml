pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Liest ~/.config/hypr-shell/settings.json und übernimmt Änderungen sofort (ohne Neustart).
// Fehlende Werte kommen aus den Standardwerten unten (gleich wie settings/settings.example.json).
Singleton {
    id: s

    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER")

    readonly property var defaults: ({
        weather: { location: "", units: "metric" },
        desktop: {
            screen: "",
            clock: { enabled: true, x: 0.02, y: 0.045, scale: 1.0 },
            resources: { enabled: true, x: 0.015, y: 0.56, scale: 1.0 }
        },
        dashboard: { width: 1000, edge: true, opacity: 0.42 }
    })
    property var data: defaults

    function merge(a, b) {
        if (b === undefined || b === null) return a
        if (typeof a !== "object" || a === null || Array.isArray(a) || typeof b !== "object" || Array.isArray(b)) return b
        const r = Object.assign({}, a)
        for (const k in b) r[k] = merge(a[k], b[k])
        return r
    }
    // get("desktop.clock.x", 0.02)
    function get(path, fallback) {
        let v = data
        const parts = path.split(".")
        for (let i = 0; i < parts.length; i++) {
            if (v === undefined || v === null) break
            v = v[parts[i]]
        }
        return v === undefined || v === null ? fallback : v
    }

    // Bildschirm aus den Einstellungen (Name), sonst der erste
    function screenFor(name) {
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++) if (list[i].name === name) return list[i]
        return list.length > 0 ? list[0] : null
    }

    FileView {
        id: file
        path: s.home + "/.config/hypr-shell/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { s.data = s.merge(s.defaults, JSON.parse(text())) }
            catch (e) { console.warn("hypr-shell: settings.json ist kein gültiges JSON – Standardwerte bleiben") }
        }
        onLoadFailed: s.data = s.defaults
    }
}
