import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Monatskalender, Woche beginnt am Montag, heute als weisser Kreis. Mit calendar.enabled (CalDAV,
// shell-fetch calendar) Punkte an Tagen mit Terminen und darunter die nächsten drei Termine; ohne
// eingeschaltete Anbindung wie bisher nur das Datum (und keine Netzanfrage).
Item {
    id: cal
    property var events: []
    // Lage im Oberflächentest (verdeckt das Dock den Kalender?)
    Probe { name: "calendar" }
    // Termin → Date (UTC-Zeiten aus CalDAV in Ortszeit)
    function when(e) {
        if (e.allday) { const p = e.start.split("-"); return new Date(+p[0], +p[1] - 1, +p[2]) }
        return new Date(e.start + ":00" + (e.utc ? "Z" : ""))
    }
    readonly property var upcoming: events.filter(e => { const d = when(e); return d.getTime() >= today.getTime() - (e.allday ? 86400000 : 0) }).slice(0, 3)
    function hasEvent(d) { return events.some(e => when(e).toDateString() === d.toDateString()) }
    Process {
        running: Integrations.calendar
        command: [Settings.bin + "shell-fetch", "calendar"]
        stdout: StdioCollector {
            onStreamFinished: { try { const r = JSON.parse(text); cal.events = r.data && r.data.events ? r.data.events : [] } catch (e) { } }
        }
    }
    property date today: new Date()
    property int offset: 0   // Monate relativ zu heute
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property var loc: Qt.locale("en_GB")
    // erster angezeigter Tag: Montag der ersten Woche
    readonly property date first: {
        const wd = (shown.getDay() + 6) % 7   // Montag = 0
        return new Date(shown.getFullYear(), shown.getMonth(), 1 - wd)
    }

    Item {
        id: head
        width: parent.width
        height: 30
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: cal.loc.standaloneMonthName(cal.shown.getMonth(), Locale.LongFormat) + " " + cal.shown.getFullYear()
            size: 15
            title: true
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Theme.pad(6)
            IconButton { width: 28; height: 28; icon: ""; iconSize: 11; onClicked: cal.offset-- }
            IconButton { width: 28; height: 28; icon: ""; iconSize: 11; onClicked: cal.offset++ }
        }
        TapHandler { onDoubleTapped: cal.offset = 0 }
    }

    Grid {
        id: grid
        anchors { top: head.bottom; topMargin: Theme.pad(6); left: parent.left; right: parent.right; bottom: next.top; bottomMargin: next.visible ? Theme.pad(4) : 0 }
        columns: 7
        readonly property real cw: width / 7
        readonly property real ch: height / 7
        Repeater {
            model: 7
            delegate: Txt {
                required property int index
                width: grid.cw; height: grid.ch
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: cal.loc.dayName((index + 1) % 7, Locale.ShortFormat).substring(0, 2)
                sub: true
                size: 11
                strong: true
            }
        }
        Repeater {
            model: 42
            delegate: Item {
                id: day
                required property int index
                readonly property date d: new Date(cal.first.getFullYear(), cal.first.getMonth(), cal.first.getDate() + index)
                readonly property bool isToday: d.toDateString() === cal.today.toDateString()
                readonly property bool inMonth: d.getMonth() === cal.shown.getMonth()
                width: grid.cw; height: grid.ch
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 2
                    height: width
                    radius: width / 2
                    color: Theme.pill
                    visible: day.isToday
                }
                // Punkt an Tagen mit Terminen
                Rectangle {
                    visible: Integrations.calendar && day.inMonth && cal.hasEvent(day.d)
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.pad(1) }
                    width: 4; height: 4; radius: 2
                    color: day.isToday ? Theme.pillText : Theme.accent
                }
                Txt {
                    anchors.centerIn: parent
                    text: day.d.getDate()
                    size: 12
                    weight: day.isToday ? Theme.titleWeight : Theme.textWeight
                    color: day.isToday ? Theme.pillText : (day.inMonth ? Theme.text : Qt.rgba(1, 1, 1, 0.25))
                }
            }
        }
    }

    // die nächsten drei Termine
    Column {
        id: next
        visible: Integrations.calendar && cal.upcoming.length > 0
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: visible ? implicitHeight : 0
        spacing: Theme.pad(1)
        Repeater {
            model: cal.upcoming
            delegate: Txt {
                required property var modelData
                width: next.width
                text: Qt.formatDateTime(cal.when(modelData), modelData.allday ? "ddd d." : "ddd d. HH:mm") + "  " + modelData.title
                size: 11
                sub: true
                Probe { name: "calendar-event" }
            }
        }
    }
}
