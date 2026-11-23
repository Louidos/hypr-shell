pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Aussehen von hypr-shell: Glas-Werte, Radien, Schriften und die Farben aus dem
// Hintergrundbild (~/.config/hypr-shell/colors.json, von matugen geschrieben, live neu geladen).
Singleton {
    id: t

    property var c: ({
        accent: "#d4d4d4", onAccent: "#1b1b1b", surface: "#131313", container: "#1f1f1f",
        text: "#e6e6e6", subtext: "#a0a0a0", outline: "#474747", error: "#dc5050"
    })
    readonly property color accent: c.accent
    readonly property color accentText: c.onAccent
    readonly property color text: c.text
    readonly property color subtext: c.subtext
    readonly property color error: c.error

    // Glas: dunkle, halbtransparente Fläche über dem Blur von Hyprland (theme.glass)
    readonly property real glassOpacity: Settings.get("theme.glass", 0.44)
    function glass(opacity) { return Qt.rgba(0.055, 0.055, 0.065, opacity === undefined ? glassOpacity : opacity) }
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.09)
    // Karten innen: Weiss mit 5 % Deckkraft und feiner heller Kontur
    readonly property color card: Qt.rgba(1, 1, 1, 0.05)
    readonly property color cardHover: Qt.rgba(1, 1, 1, 0.08)
    readonly property color cardBorder: Qt.rgba(1, 1, 1, 0.08)
    // aktive Schalter und Tabs: weisse Pille mit dunklem Symbol
    readonly property color pill: Qt.rgba(1, 1, 1, 0.92)
    readonly property color pillText: "#121214"
    readonly property color track: Qt.rgba(1, 1, 1, 0.10)
    // Abzeichen und Pillen in der Farbe des Hintergrundbilds (dunkel gemischt), Text darauf hell
    readonly property color container: mix(c.accent, "#141416", 0.8)
    readonly property color containerText: mix(c.accent, "#ffffff", 0.55)
    readonly property color warn: "#e06c75"

    function mix(a, b, k, al) {
        const x = Qt.color(a), y = Qt.color(b)
        return Qt.rgba(x.r * (1 - k) + y.r * k, x.g * (1 - k) + y.g * k, x.b * (1 - k) + y.b * k, al === undefined ? 1 : al)
    }

    // Radien und Schriften aus settings.json (theme.radius.*, theme.font.*)
    readonly property int panelRadius: Settings.get("theme.radius.panel", 26)
    readonly property int cardRadius: Settings.get("theme.radius.card", 18)

    readonly property string sans: Settings.get("theme.font.ui", "Inter")
    readonly property string mono: Settings.get("theme.font.mono", "JetBrainsMono Nerd Font")
    readonly property string clock: Settings.get("theme.font.clock", "JetBrainsMono Nerd Font")
    readonly property string displayName: Settings.get("theme.font.display", "Bebas Neue")
    // mitgelieferte Bebas Neue, solange die Standardschrift gewählt ist
    readonly property string display: displayName === "Bebas Neue" && bebas.status === FontLoader.Ready ? bebas.name : displayName
    // Faktor für alle Schriftgrössen
    readonly property real fontScale: Settings.get("theme.font.scale", 1.0)

    FontLoader { id: bebas; source: Qt.resolvedUrl("fonts/BebasNeue-Regular.ttf") }

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr-shell/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { t.c = Object.assign({}, t.c, JSON.parse(text())) } catch (e) { }
        }
    }
}
