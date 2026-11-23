import QtQuick
import "../common"

// Monatskalender, Woche beginnt am Montag, heute als weisser Kreis.
Item {
    id: cal
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
            weight: Font.Bold
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6
            IconButton { width: 28; height: 28; icon: ""; iconSize: 11; onClicked: cal.offset-- }
            IconButton { width: 28; height: 28; icon: ""; iconSize: 11; onClicked: cal.offset++ }
        }
        TapHandler { onDoubleTapped: cal.offset = 0 }
    }

    Grid {
        id: grid
        anchors { top: head.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
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
                weight: Font.DemiBold
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
                Txt {
                    anchors.centerIn: parent
                    text: day.d.getDate()
                    size: 12
                    weight: day.isToday ? Font.Bold : Font.Normal
                    color: day.isToday ? Theme.pillText : (day.inMonth ? Theme.text : Qt.rgba(1, 1, 1, 0.25))
                }
            }
        }
    }
}
