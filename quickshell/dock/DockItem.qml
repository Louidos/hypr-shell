import QtQuick
import "../common"

// Ein Eintrag im Dock: Programm, laufendes Fenster ohne Eintrag, Ordner, Papierkorb, Startknopf
// oder Trenner. Punkte (dock.indicator) zeigen laufende Programme, zwei bei mehreren Fenstern,
// kräftiger beim aktiven Fenster.
Item {
    id: di
    property var item: null
    property var dock
    property var win
    property real size: 48

    readonly property string kind: item ? item.kind : "separator"
    readonly property bool separator: kind === "separator"
    readonly property var windows: item ? item.windows : []
    readonly property bool running: windows.length > 0
    readonly property bool active: {
        for (let i = 0; i < windows.length; i++) if (windows[i] && windows[i].activated) return true
        return false
    }
    // Name: Desktop-Eintrag, sonst Titel des Fensters
    readonly property string name: kind === "window" ? (windows.length > 0 && windows[0].title ? String(windows[0].title) : (item && item.name ? String(item.name) : ""))
        : (item && item.name ? String(item.name) : "")
    readonly property bool vertical: dock.vertical
    readonly property int labelRoom: dock.labels === "always" ? 16 : 0

    implicitWidth: separator ? (vertical ? size : 1 + dock.spacing) : size
    implicitHeight: separator ? (vertical ? 1 + dock.spacing : size + labelRoom) : size + labelRoom

    // ---- Trenner
    Rectangle {
        visible: di.separator
        anchors.centerIn: parent
        width: di.vertical ? di.size * 0.7 : 1
        height: di.vertical ? 1 : di.size * 0.7
        color: dock.lightGlass ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.18)
    }

    // ---- Symbol
    Item {
        id: iconBox
        visible: !di.separator
        width: di.size
        height: di.size
        AppIcon {
            id: ic
            anchors.fill: parent
            icon: di.item && di.item.icon ? String(di.item.icon) : ""
            size: di.size
            visible: di.kind !== "window" || ready
        }
        // Fenster ohne Desktop-Eintrag und ohne Symbol: Anfangsbuchstabe des Titels
        Rectangle {
            visible: di.kind === "window" && !ic.ready
            anchors.fill: parent
            anchors.margins: di.size * 0.08
            radius: width * 0.24
            color: Theme.container
            Txt {
                anchors.centerIn: parent
                text: (di.name || "?").charAt(0).toUpperCase()
                size: di.size * 0.42
                weight: Font.DemiBold
                color: Theme.containerText
            }
        }
        // gedrückt: kurz dunkler
        Rectangle {
            anchors.fill: parent
            radius: width * 0.24
            color: Qt.rgba(0, 0, 0, 0.25)
            visible: mouse.pressed
        }
    }

    // ---- Name unter dem Symbol (dock.labels = always)
    Txt {
        visible: !di.separator && di.labelRoom > 0
        width: di.size + dock.spacing
        anchors.horizontalCenter: iconBox.horizontalCenter
        y: di.size + 1
        horizontalAlignment: Text.AlignHCenter
        text: di.name
        size: 10
        color: dock.lightGlass ? "#202024" : Theme.text
    }

    // ---- Anzeige "läuft" (Punkt oder Linie, zwei bei mehreren Fenstern) zur Kante hin
    Grid {
        id: ind
        visible: di.running && dock.indicator !== "none" && !di.separator
        readonly property real gap: Math.max(2, dock.padding / 2)
        readonly property bool line: dock.indicator === "line"
        readonly property int n: Math.min(2, di.windows.length)
        columns: di.vertical ? 1 : n
        rows: di.vertical ? n : 1
        spacing: 3
        x: di.vertical ? (dock.position === "left" ? -gap - width / 2 : di.size + gap - width / 2) : (di.size - width) / 2
        y: di.vertical ? (di.size - height) / 2 : (dock.position === "top" ? -gap - height / 2 : di.height + gap - height / 2)
        Repeater {
            model: ind.n
            Rectangle {
                readonly property real len: ind.line ? (ind.n > 1 ? di.size * 0.22 : di.size * 0.36) : (di.active ? 5 : 4)
                readonly property real thick: ind.line ? 3 : len
                width: di.vertical ? thick : len
                height: di.vertical ? len : thick
                radius: Math.min(width, height) / 2
                color: dock.indicatorColor
                opacity: di.active ? 1 : 0.55
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !di.separator
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: dock.activate(di.item)
        onContainsMouseChanged: {
            if (containsMouse) { win.hoverItem = iconBox; win.hoverText = di.name }
            else if (win.hoverItem === iconBox) { win.hoverItem = null; win.hoverText = "" }
        }
    }
    Component.onDestruction: if (win && win.hoverItem === iconBox) { win.hoverItem = null; win.hoverText = "" }
}
