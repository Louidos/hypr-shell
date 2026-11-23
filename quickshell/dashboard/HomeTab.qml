import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Tab Dashboard: Wetter, Profil, Musik, Uhr, Kalender, Ringe (Raster mit 12 Spalten, 3 Zeilen).
Grid12 {
    id: home
    property var about: ({})
    property var weather: ({ ok: false, reason: "loading" })
    rows: 3

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
        running: true
        stdout: StdioCollector { onStreamFinished: { try { home.weather = JSON.parse(text) } catch (e) { home.weather = { ok: false, reason: "offline" } } } }
    }
    Timer { interval: 15 * 60 * 1000; running: true; repeat: true; onTriggered: if (!weatherProc.running) weatherProc.running = true }

    // ---- Wetter (4×1 bei 0,0)
    Cell {
        col: 0; row: 0; cs: 4; rs: 1
        Row {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            spacing: 14
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
                    weight: Font.Bold
                }
                Txt {
                    text: home.weather.ok ? home.weather.description + " · " + home.weather.location
                        : home.weather.reason === "no-location" ? "Set weather.location in settings.json"
                        : home.weather.reason === "unknown-location" ? "Unknown place: " + home.weather.location
                        : home.weather.reason === "loading" ? "Loading weather…" : "Offline"
                    sub: true
                    size: 12
                    width: 210
                }
            }
        }
    }

    // ---- Profil (5×1 bei 4,0)
    Cell {
        col: 4; row: 0; cs: 5; rs: 1
        RoundImage {
            id: avatar
            width: 62; height: 62; radius: 31
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            source: "file://" + Settings.home + "/.face"
            fallbackText: Settings.user.length > 0 ? Settings.user[0].toUpperCase() : "?"
            probe: "dashboard-avatar"
        }
        Column {
            anchors { left: avatar.right; leftMargin: 16; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 8
            Txt {
                width: parent.width
                text: home.greeting() + ", " + Settings.user
                size: 18
                weight: Font.Bold
            }
            Row {
                spacing: 6
                Pill { clickable: false; implicitHeight: 26; fontSize: 11; icon: home.about.icon || ""; text: home.about.distro || "Linux" }
                Pill { clickable: false; implicitHeight: 26; fontSize: 11; icon: "󰄉"; text: "Up " + home.uptime(home.about.uptime) }
            }
        }
    }

    // ---- Musik (3×3 bei 9,0)
    Cell {
        col: 9; row: 0; cs: 3; rs: 3
        MediaCard { anchors.fill: parent; anchors.margins: 14 }
    }

    // ---- Uhr (2×2 bei 0,1)
    Cell {
        col: 0; row: 1; cs: 2; rs: 2
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
                topPadding: 10
                text: Qt.locale("en_GB").dayName(clock.date.getDay(), Locale.LongFormat)
                sub: true
                size: 13
                weight: Font.DemiBold
            }
        }
    }

    // ---- Kalender (5×2 bei 2,1)
    Cell {
        col: 2; row: 1; cs: 5; rs: 2
        Calendar { anchors.fill: parent; anchors.margins: 14; today: clock.date }
    }

    // ---- Ringe (2×2 bei 7,1)
    Cell {
        col: 7; row: 1; cs: 2; rs: 2
        Grid {
            anchors.centerIn: parent
            columns: 2
            rowSpacing: 14
            columnSpacing: 14
            Repeater {
                model: [
                    { label: "CPU", v: () => usage.cpu },
                    { label: "RAM", v: () => usage.mem },
                    { label: "Disk", v: () => usage.disk },
                    { label: "Swap", v: () => usage.swap }
                ]
                delegate: Column {
                    required property var modelData
                    spacing: 4
                    Item {
                        width: 54; height: 54
                        Ring { anchors.fill: parent; value: modelData.v(); thickness: 4 }
                        Txt { anchors.centerIn: parent; text: Math.round(modelData.v()) + "%"; size: 12; weight: Font.Bold }
                    }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; sub: true; size: 11 }
                }
            }
        }
    }
}
