import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Tab Dashboard: Wetter, Profil, Musik, Uhr, Kalender, Ringe für CPU/RAM/Disk (12 Spalten, 3 Zeilen).
Grid12 {
    id: home
    property var about: ({})
    property var weather: ({ ok: false, reason: "loading" })
    rows: 3
    // Hochformat: 6 Spalten, 5 Zeilen (Wetter | Profil, Uhr | Kalender, Musik | Ringe)
    narrowRows: 5
    // Karten an/aus aus settings.json (dashboard.cards)
    readonly property var cards: Settings.get("dashboard.cards", ["weather", "profile", "media", "clock", "calendar", "rings"])
    function shown(name) { return cards.indexOf(name) >= 0 }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    Usage { id: usage; running: true; interval: 2000 }

    function greeting() {
        const h = clock.date.getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
    function uptime(s) {
        s = Math.floor(s || 0)
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return (d ? d + "d " : "") + (h ? h + "h " : "") + m + "m"
    }

    Process {
        id: weatherProc
        command: [Settings.home + "/.local/bin/shell-weather"]
        running: home.shown("weather")
        stdout: StdioCollector { onStreamFinished: { try { home.weather = JSON.parse(text) } catch (e) { home.weather = { ok: false, reason: "offline" } } } }
    }
    Timer { interval: 15 * 60 * 1000; running: true; repeat: true; onTriggered: if (!weatherProc.running) weatherProc.running = true }

    // ---- Sensor (nur mit sensor.enabled): teilt sich die Zelle des Wetters (rechte Hälfte)
    property var sensor: ({ ok: false })
    Process {
        running: Integrations.sensor
        command: [Settings.bin + "shell-fetch", "sensor"]
        stdout: StdioCollector { onStreamFinished: { try { home.sensor = JSON.parse(text) } catch (e) { } } }
    }

    // ---- Wetter (4×1 bei 0,0)
    Cell {
        id: weatherCell
        col: 0; row: 0; cs: 4; rs: 1
        narrowAt: [0, 0, 3, 1]
        visible: home.shown("weather") || Integrations.sensor
        Item {
            visible: Integrations.sensor
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: parent.width * 0.42
            Rectangle { width: 1; height: parent.height - 24; anchors.verticalCenter: parent.verticalCenter; color: Theme.cardBorder }
            Column {
                anchors { left: parent.left; leftMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
                spacing: Theme.pad(2)
                Txt {
                    text: home.sensor.data ? home.sensor.data.value + " " + (home.sensor.data.unit || "") : "–"
                    size: 20
                    heavy: true
                    color: home.sensor.data && home.sensor.data.warn ? Theme.warn : Theme.text
                    Probe { name: "sensor-tile" }
                }
                Txt {
                    text: (home.sensor.data ? home.sensor.data.title : Settings.get("sensor.title", "Air quality"))
                          + (home.sensor.ok === false && home.sensor.error === "not reachable" ? " · not reachable" : home.sensor.error === "setup" ? " · set the address" : "")
                    size: 11
                    sub: true
                }
            }
        }
        Row {
            visible: home.shown("weather")
            anchors { left: parent.left; leftMargin: Theme.pad(18); verticalCenter: parent.verticalCenter }
            spacing: Theme.pad(14)
            Glyph {
                text: home.weather.ok ? home.weather.icon : "󰖐"
                size: 38
                color: home.weather.ok ? Theme.text : Theme.subtext
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Txt {
                    text: home.weather.ok ? home.weather.temp + home.weather.unit : "–"
                    size: 24
                    heavy: true
                }
                Txt {
                    text: home.weather.ok ? home.weather.description + " · " + home.weather.location
                        : home.weather.reason === "no-location" ? "Set weather.location in settings.json"
                        : home.weather.reason === "unknown-location" ? "Unknown place: " + home.weather.location
                        : home.weather.reason === "loading" ? "Loading weather…" : "Offline"
                    sub: true
                    size: 12
                    width: Math.max(60, Math.min(210, weatherCell.width * (Integrations.sensor ? 0.58 : 1) - 90))
                }
            }
        }
    }

    // ---- Missa (nur mit missa.enabled): nimmt den Platz des Profils ein (5×1 bei 4,0)
    Cell {
        col: 4; row: 0; cs: 5; rs: 1
        narrowAt: [3, 0, 3, 1]
        visible: Integrations.missa
        Loader { anchors.fill: parent; active: Integrations.missa; source: "../missa/MissaCard.qml" }
    }

    // ---- Profil (5×1 bei 4,0)
    Cell {
        col: 4; row: 0; cs: 5; rs: 1
        narrowAt: [3, 0, 3, 1]
        visible: home.shown("profile") && !Integrations.missa
        RoundImage {
            id: avatar
            width: 62; height: 62; radius: Theme.corner(31)
            anchors { left: parent.left; leftMargin: Theme.pad(18); verticalCenter: parent.verticalCenter }
            source: Settings.face
            Component.onCompleted: Settings.checkFace()
            fallbackText: Settings.user.length > 0 ? Settings.user[0].toUpperCase() : "?"
            probe: "dashboard-avatar"
        }
        Column {
            anchors { left: avatar.right; leftMargin: Theme.pad(16); right: parent.right; rightMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
            spacing: Theme.pad(8)
            Txt {
                width: parent.width
                text: home.greeting() + ", " + Settings.user
                size: 18
                title: true
            }
            Row {
                spacing: Theme.pad(6)
                Pill { clickable: false; implicitHeight: 26; fontSize: 11; icon: home.about.icon || ""; text: home.about.distro || "Linux" }
                Pill { clickable: false; implicitHeight: 26; fontSize: 11; icon: "󰄉"; text: "Up " + home.uptime(home.about.uptime) }
            }
        }
    }

    // ---- Musik (3×3 bei 9,0)
    Cell {
        col: 9; row: 0; cs: 3; rs: 3
        narrowAt: [0, 3, 4, 2]
        visible: home.shown("media")
        MediaCard { anchors.fill: parent; anchors.margins: Theme.cardPad }
    }

    // ---- Uhr (2×2 bei 0,1)
    Cell {
        col: 0; row: 1; cs: 2; rs: 2
        narrowAt: [0, 1, 2, 2]
        visible: home.shown("clock")
        Column {
            anchors.centerIn: parent
            spacing: -14
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "HH")
                font.family: Theme.display; font.pixelSize: 78
                color: Qt.rgba(1, 1, 1, 0.92)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "mm")
                font.family: Theme.display; font.pixelSize: 78
                color: Qt.rgba(1, 1, 1, 0.5)
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: Theme.pad(10)
                text: Qt.locale("en_GB").dayName(clock.date.getDay(), Locale.LongFormat)
                sub: true
                size: 13
                strong: true
            }
        }
    }

    // ---- Kalender (5×2 bei 2,1)
    Cell {
        col: 2; row: 1; cs: 5; rs: 2
        narrowAt: [2, 1, 4, 2]
        visible: home.shown("calendar")
        Calendar { anchors.fill: parent; anchors.margins: Theme.cardPad; today: clock.date }
    }

    // ---- Ringe (2×2 bei 7,1): CPU, RAM, Datenträger untereinander, Symbol in der Mitte (wie die Vorlage)
    Cell {
        id: rings
        col: 7; row: 1; cs: 2; rs: 2
        narrowAt: [4, 3, 2, 2]
        visible: home.shown("rings")
        readonly property bool tall: height >= width
        readonly property real s: tall ? Math.min(width - 20, (height - 32) / 3) : Math.min(height - 30, (width - 50) / 3)
        Grid {
            anchors.centerIn: parent
            columns: rings.tall ? 1 : 3
            spacing: Theme.pad(rings.tall ? 6 : 16)
            Repeater {
                model: [
                    { label: "CPU", icon: "󰘚", v: () => usage.cpu },
                    { label: "RAM", icon: "󰍛", v: () => usage.mem },
                    { label: "Disk", icon: "󰋊", v: () => usage.disk }
                ]
                delegate: Item {
                    required property var modelData
                    width: rings.s
                    height: rings.s
                    Ring { anchors.fill: parent; value: modelData.v(); thickness: 5; gapped: true }
                    Glyph { anchors.centerIn: parent; text: modelData.icon; size: rings.s * 0.3 }
                }
            }
        }
    }
}
