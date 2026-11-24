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

    // Glas: graue, halbtransparente Fläche über dem Blur von Hyprland (theme.glass_color, theme.glass),
    // mit feinem Rand (theme.border.*). Alle Flächen der Shell nehmen diese Werte.
    readonly property color glassColor: Settings.get("theme.glass_color", "#1a1a1d")
    readonly property real glassOpacity: Settings.get("theme.glass", 0.46)
    // Mindestkontrast: Text muss über dem Hintergrundbild lesbar bleiben (WCAG 4.5:1); reicht die
    // Deckkraft dafür nicht (helles Bild), wird das Glas automatisch so weit dunkler wie nötig
    function lum(c) {
        const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    // Helligkeit des Hintergrundbilds (shell-wallpaper → wallpaper-luma), ohne Angabe eher dunkel
    property real wallpaperLuma: 0.2
    // Gerechnet wird mit einer Karte (theme.card.*) auf dem Glas: so bleibt auch Text auf Karten lesbar,
    // ohne dass die Karten auf hellen Bildern verschwinden
    function readable(opacity) {
        const lg = lum(Qt.color(glassColor)), tl = lum(Qt.color(c.text)), lc = lum(Qt.color(cardBase))
        let a = Math.max(0, Math.min(1, opacity))
        for (let i = 0; i < 100 && a < 0.95; i++) {
            const bg = cardOpacity * lc + (1 - cardOpacity) * (a * lg + (1 - a) * wallpaperLuma)
            if ((Math.max(tl, bg) + 0.05) / (Math.min(tl, bg) + 0.05) >= 4.5) break
            a += 0.01
        }
        return a
    }
    readonly property real glassReadable: readable(glassOpacity)
    // -1 oder fehlend = die gemeinsame Deckkraft; jede Deckkraft wird für die Lesbarkeit geprüft
    function glass(opacity) {
        const g = Qt.color(glassColor)
        const o = opacity === undefined || opacity < 0 ? glassOpacity : opacity
        return Qt.rgba(g.r, g.g, g.b, o === glassOpacity ? glassReadable : readable(o))
    }
    readonly property color borderBase: Settings.get("theme.border.color", "#ffffff")
    readonly property real borderOpacity: Settings.get("theme.border.opacity", 0.8)
    readonly property int borderWidth: Settings.get("theme.border.width", 2)
    readonly property color glassBorder: Qt.rgba(Qt.color(borderBase).r, Qt.color(borderBase).g, Qt.color(borderBase).b, borderOpacity)
    // Leuchten des Rands (theme.border.glow*): weicher äusserer Schein in Randfarbe, ohne Versatz
    // (Glow.qml in GlassPanel, GlassCard, Panels und Dock; Fenster über den Schatten in hyprland.lua)
    readonly property bool glow: Settings.get("theme.border.glow", true) === true
    readonly property real glowSize: Math.max(0, Math.min(40, Settings.get("theme.border.glow_size", 10)))
    readonly property real glowOpacity: Math.max(0, Math.min(1, Settings.get("theme.border.glow_opacity", 0.25)))

    // Karten innen (theme.card.*): Kartenfarbe mit wenig Deckkraft über dem Glas, feine Kontur.
    // Auch für Karten gilt der Mindestkontrast: das Glas wird dafür dunkler (readable); reicht auch
    // das stärkste Glas nicht, wird die Karte so weit durchsichtiger wie nötig (readableCard)
    readonly property color cardBase: Settings.get("theme.card.color", "#ffffff")
    readonly property real cardOpacity: Math.max(0, Math.min(0.4, Settings.get("theme.card.opacity", 0.09)))
    readonly property real cardHoverOpacity: Math.max(0, Math.min(0.5, Settings.get("theme.card.hover", 0.14)))
    readonly property real cardBorderOpacity: Math.max(0, Math.min(1, Settings.get("theme.card.border_opacity", 0.12)))
    function readableCard(opacity) {
        const lc = lum(Qt.color(cardBase)), lg = lum(Qt.color(glassColor)), tl = lum(Qt.color(c.text))
        const under = glassReadable * lg + (1 - glassReadable) * wallpaperLuma
        let a = Math.max(0, opacity)
        for (let i = 0; i < 100 && a > 0; i++) {
            const bg = a * lc + (1 - a) * under
            if ((Math.max(tl, bg) + 0.05) / (Math.min(tl, bg) + 0.05) >= 4.5) break
            a = Math.max(0, a - 0.01)
        }
        return a
    }
    function cardTint(opacity) { const b = Qt.color(cardBase); return Qt.rgba(b.r, b.g, b.b, opacity) }
    readonly property color card: cardTint(readableCard(cardOpacity))
    // der kurze Hover-Zustand bleibt so hell wie eingestellt (eine sichtbare Rückmeldung), mindestens
    // so hell wie die Karte
    readonly property color cardHover: cardTint(Math.max(cardHoverOpacity, Qt.color(card).a))
    readonly property color cardBorder: cardTint(cardBorderOpacity)
    // Abstufungen relativ zur Karte (wachsen mit theme.card.opacity): cardLevel(k) = Karte × k
    function cardLevel(k) { return cardTint(readableCard(cardOpacity * k)) }
    readonly property color cardSoft: cardLevel(0.6)      // Zeilen in Karten
    readonly property color cardFaint: cardLevel(0.8)
    readonly property color field: cardLevel(1.2)         // Such- und Eingabefelder
    readonly property color cardStrong: cardLevel(1.4)    // Symbol-Blasen, Zellen
    // aktive Schalter und Tabs: weisse Pille mit dunklem Symbol (theme.pill.opacity)
    readonly property real pillOpacity: Math.max(0.3, Math.min(1, Settings.get("theme.pill.opacity", 0.92)))
    readonly property color pill: Qt.rgba(1, 1, 1, pillOpacity)
    readonly property color pillText: "#121214"
    // aktiver Eintrag der Seitenleiste in den Einstellungen (theme.pill.nav): soft = hellere graue
    // Pille mit heller, fetter Schrift (wie die Vorlage), white = weisse Pille wie Tabs und Schalter
    readonly property bool navWhite: Settings.get("theme.pill.nav", "soft") === "white"
    readonly property color navPill: navWhite ? pill : cardLevel(1.9)
    readonly property color navPillText: navWhite ? pillText : text
    readonly property color track: Qt.rgba(1, 1, 1, 0.10)

    // Abstände (theme.spacing.*): scale ist der Faktor für alle Abstände der Oberfläche; panel ist der
    // Innenabstand der Glasflächen, card der Innenabstand der Karten, gap die Lücke zwischen Karten.
    // Alle Abstände in quickshell/ gehen über pad(n) (Entwurfswert n mal Faktor). Panels skalieren
    // ihren Inhalt zusätzlich mit der Grössen-Hilfe (ScreenFit), die Abstände wachsen also mit.
    readonly property real spacingScale: Math.max(0.5, Math.min(2, Settings.get("theme.spacing.scale", 1.0)))
    function pad(n) { return Math.round(n * spacingScale) }
    readonly property int panelPad: pad(Settings.get("theme.spacing.panel", 20))
    readonly property int cardPad: pad(Settings.get("theme.spacing.card", 16))
    readonly property int gap: pad(Settings.get("theme.spacing.gap", 12))
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
    readonly property int cardRadius: Settings.get("theme.radius.card", 16)
    // Rundung kleiner Elemente (Zeilen, Felder, Knöpfe) im Verhältnis zur Karte: Entwurfswert n bei
    // Kartenradius 10; ein Kreis (n = halbe Grösse) bleibt ein Kreis, Qt begrenzt auf die halbe Seite
    function corner(n) { return Math.round(n * cardRadius / 10) }

    readonly property string sans: Settings.get("theme.font.ui", "Inter")
    readonly property string mono: Settings.get("theme.font.mono", "JetBrainsMono Nerd Font")
    readonly property string clock: Settings.get("theme.font.clock", "JetBrainsMono Nerd Font")
    readonly property string displayName: Settings.get("theme.font.display", "Bebas Neue")
    // mitgelieferte Bebas Neue, solange die Standardschrift gewählt ist
    readonly property string display: displayName === "Bebas Neue" && bebas.status === FontLoader.Ready ? bebas.name : displayName
    // Faktor für alle Schriftgrössen
    readonly property real fontScale: Settings.get("theme.font.scale", 1.0)
    // Schriftdicke (theme.font.title_weight, text_weight) und Grösse der Überschriften im Verhältnis
    // zum Text (title_scale). Txt { title: true } nimmt titleWeight und titleScale, Txt { strong: true }
    // (Beschriftungen, Pillen) eine Stufe leichter als Titel, normaler Text textWeight.
    function weightOf(name, fallback) {
        return ({ normal: Font.Normal, medium: Font.Medium, demibold: Font.DemiBold, bold: Font.Bold })[name] || fallback
    }
    readonly property int titleWeight: weightOf(Settings.get("theme.font.title_weight", "bold"), Font.Bold)
    readonly property int textWeight: weightOf(Settings.get("theme.font.text_weight", "normal"), Font.Normal)
    readonly property int strongWeight: Math.max(textWeight, titleWeight - 100)
    readonly property real titleScale: Math.max(0.8, Math.min(2, Settings.get("theme.font.title_scale", 1.25)))

    FileView {
        path: Quickshell.env("HOME") + "/.local/share/hypr-shell/wallpaper-luma"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const v = Number(text().trim()); if (!isNaN(v) && v >= 0 && v <= 1) t.wallpaperLuma = v }
    }
    FontLoader { id: bebas; source: Qt.resolvedUrl("fonts/BebasNeue-Regular.ttf") }

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr-shell/colors.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { t.c = Object.assign({}, t.c, JSON.parse(text())) } catch (e) { }
        }
    }
}
