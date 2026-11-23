import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland

// Vorschaubild eines Fensters (nur unter Hyprland geladen): sucht das Fenster über seine Adresse und
// zeigt seinen Inhalt; ohne Inhalt bleibt die Fläche durchsichtig (darunter Symbol und Titel).
ScreencopyView {
    id: pv
    property string address: ""
    readonly property var toplevel: {
        const a = address.replace(/^0x/, "").toLowerCase()
        const l = Hyprland.toplevels.values
        for (let i = 0; i < l.length; i++) if (l[i].address.toLowerCase() === a) return l[i]
        return null
    }
    captureSource: toplevel ? toplevel.wayland : null
    live: false
    visible: hasContent
}
