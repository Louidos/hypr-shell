import QtQuick
import Quickshell
import "../common"

// Seite Home, luftig wie die Vorlage: grosses Profilbild in der Mitte, Begrüssung, Datum und
// Uhrzeit, drei Pillen (Farbmodus, Laufzeit, Distro), ein Tipp (settings.home.tips, wechselt bei
// jedem Öffnen, × schaltet die Tipps ab) und Kacheln zu den wichtigsten Seiten („Make it yours“).
// Keine Eingabefelder: Profile, Export und Import stehen unter System → Backup.
Column {
    id: home
    spacing: Theme.pad(18)
    property var about: ({})

    SystemClock { id: clock; precision: SystemClock.Minutes }
    function greeting() {
        const h = clock.date.getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
    // Laufzeit wie "Up 3h 45m" (shell-sysinfo about, Sekunden)
    function uptime(s) {
        s = Number(s) || 0
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return "Up " + (d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m")
    }
    readonly property string colorMode: String(Settings.get("theme.colors", "auto"))

    // ---- Tipps: bei jedem Öffnen ein anderer
    readonly property var tips: [
        "Keep Awake in the hot corner stops the screen from locking during a movie.",
        "SUPER + D opens the dashboard, SUPER + W goes straight to the wallpapers.",
        "Tap SUPER alone to open the app grid; right-click an app to pin it to the dock.",
        "Drag a window to the screen edge to snap it to a half or a quarter.",
        "SUPER + / shows all keyboard shortcuts at a glance.",
        "Every setting here also works in a terminal: shell-set theme.card.opacity 0.15",
        "Look → Preset switches between glass, minimal and gaming in one click.",
        "Undo and redo at the top undo every change, even a whole preset.",
        "Save your setup as a profile under System → Backup before trying something new."
    ]
    property int tip: Math.floor(Math.random() * tips.length)
    readonly property bool tipsOn: Settings.get("settings.home.tips", true) === true

    // ---- Profilbild, Begrüssung, Datum
    Column {
        width: parent.width
        topPadding: Theme.pad(12)
        spacing: Theme.pad(8)
        RoundImage {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96; height: 96; radius: 48
            source: Settings.face
            Component.onCompleted: Settings.checkFace()
            fallbackText: Settings.user.length > 0 ? Settings.user[0].toUpperCase() : "?"
            probe: "home-avatar"
        }
        Item { width: 1; height: Theme.pad(4) }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: home.greeting() + ", " + Settings.user
            size: 22; title: true
            Probe { name: "home-greeting" }
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM  ·  HH:mm")
            size: 13; sub: true
        }
        Item { width: 1; height: Theme.pad(4) }
        Row {
            id: chips
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.pad(8)
            Pill { clickable: true; implicitHeight: 30; fontSize: 12; icon: "󰏘"; text: "Theme · " + home.colorMode.charAt(0).toUpperCase() + home.colorMode.slice(1); onClicked: Ui.settingsPage = "theme" }
            Pill { clickable: false; implicitHeight: 30; fontSize: 12; icon: "󰔟"; text: home.uptime(home.about.uptime) }
            Pill { clickable: false; implicitHeight: 30; fontSize: 12; icon: home.about.icon || ""; text: home.about.distro || "Linux" }
            Probe { name: "home-chips" }
        }
    }

    // ---- Tipp in Akzentfarbe
    Rectangle {
        id: banner
        visible: home.tipsOn
        width: parent.width
        height: visible ? Math.max(76, tipCol.implicitHeight + 2 * Theme.cardPad) : 0
        radius: Theme.cardRadius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.mix(Theme.accent, Theme.glassColor, 0.72, 0.55) }
            GradientStop { position: 1; color: Theme.mix(Theme.accent, Theme.glassColor, 0.9, 0.35) }
        }
        border.width: 1
        border.color: Theme.mix(Theme.accent, "#ffffff", 0.4, 0.35)
        Rectangle {
            id: bulb
            x: Theme.cardPad; anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44; radius: 14
            color: Theme.cardStrong
            Glyph { anchors.centerIn: parent; text: "󰛨"; size: 19; color: Theme.containerText }
        }
        Column {
            id: tipCol
            anchors { left: bulb.right; leftMargin: Theme.pad(14); right: closeTip.left; rightMargin: Theme.pad(8); verticalCenter: parent.verticalCenter }
            spacing: Theme.pad(3)
            Txt { text: "Make yourself at home"; size: 14; title: true }
            Txt { width: parent.width; text: home.tips[home.tip]; size: 12; sub: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
        }
        IconButton {
            id: closeTip
            anchors { right: parent.right; rightMargin: Theme.pad(10); verticalCenter: parent.verticalCenter }
            icon: "󰅖"; iconSize: 13; flat: true
            implicitWidth: 28; implicitHeight: 28
            onClicked: Ui.run(["settings.home.tips", "false"])
            Probe { name: "home-tips-close" }
        }
        Probe { name: "home-tips" }
    }

    // ---- Make it yours: Kacheln zu den wichtigsten Seiten
    Txt { text: "Make it yours"; size: 16; title: true; topPadding: Theme.pad(4) }
    Grid {
        id: tiles
        width: parent.width
        columns: home.width < 520 ? 2 : 3
        spacing: Theme.gap
        readonly property real tileW: (width - (columns - 1) * spacing) / columns
        Repeater {
            // page: Seite der Einstellungen; key: Wert, zu dem gesprungen wird; dash: Tab im Dashboard
            model: [
                { title: "Theme", sub: "Colors & schemes", icon: "󰏘", page: "theme", key: "" },
                { title: "Wallpaper", sub: "Pick a new one", icon: "󰋩", dash: "wallpaper" },
                { title: "Notifications", sub: "Popups & panel", icon: "󰂚", page: "system", key: "notifications.enabled" },
                { title: "Lock screen", sub: "Idle & lock", icon: "󰌾", page: "lock", key: "" },
                { title: "Bar", sub: "Bar layout & style", icon: "󰕰", page: "bar", key: "" },
                { title: "Launcher", sub: "App launcher", icon: "󰀻", page: "apps", key: "apps.launcher" }
            ]
            delegate: GlassCard {
                id: tile
                required property var modelData
                required property int index
                width: tiles.tileW
                height: 76
                hoverable: true
                Rectangle {
                    id: ib
                    width: 40; height: 40; radius: 12
                    anchors { left: parent.left; leftMargin: Theme.cardPad; verticalCenter: parent.verticalCenter }
                    color: Theme.cardStrong
                    Glyph { anchors.centerIn: parent; text: tile.modelData.icon; size: 17 }
                }
                Column {
                    anchors { left: ib.right; leftMargin: Theme.pad(12); right: parent.right; rightMargin: Theme.pad(12); verticalCenter: parent.verticalCenter }
                    spacing: Theme.pad(2)
                    Txt { width: parent.width; text: tile.modelData.title; size: 13; title: true }
                    Txt { width: parent.width; text: tile.modelData.sub; size: 11; sub: true }
                }
                // Klick öffnet die Seite (bzw. den Tab Wallpaper im Dashboard); im Oberflächentest
                // löst "ipc call test click home-tile-<n>" dasselbe aus
                signal clicked()
                onClicked: {
                    if (modelData.dash) Ui.openDashboard(modelData.dash)
                    else Ui.goSettings(modelData.page, modelData.key)
                }
                TapHandler { onTapped: tile.clicked() }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                Probe { name: "home-tile-" + tile.index }
            }
        }
    }
}
