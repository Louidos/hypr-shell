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
    property bool selected: false          // Tastatur (SUPER+B)
    property bool dragging: false
    property Item iconItem: iconBox
    readonly property int badge: dock.badgeFor(item)

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
        opacity: di.dragging ? 0.35 : 1
        // Tastatur: sichtbarer Rahmen um das gewählte Symbol
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: width * 0.26
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            visible: di.selected
        }
        // Zähler für Benachrichtigungen (dock.badges)
        Rectangle {
            visible: di.badge > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: -2
            height: Math.max(16, di.size * 0.34)
            width: Math.max(height, badgeText.implicitWidth + 8)
            radius: height / 2
            color: Theme.error
            Txt {
                id: badgeText
                anchors.centerIn: parent
                text: di.badge > 99 ? "99+" : String(di.badge)
                size: Math.max(9, di.size * 0.2)
                weight: Font.DemiBold
                color: "white"
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
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        property point start: Qt.point(0, 0)
        property bool dragged: false
        property bool held: false
        onPressed: event => {
            start = Qt.point(event.x, event.y); dragged = false; held = false
            if (event.button === Qt.LeftButton && di.kind === "folder") holdTimer.restart()
        }
        onPositionChanged: event => {
            if (!(pressedButtons & Qt.LeftButton) || held) return
            if (!dragged && Math.abs(event.x - start.x) + Math.abs(event.y - start.y) > 10) { dragged = true; holdTimer.stop(); win.closePopup() }
            if (dragged) win.dragMove(di.item.key, mapToItem(win.contentItem, event.x, event.y))
        }
        onReleased: event => {
            holdTimer.stop()
            if (dragged) { win.dragEnd(); dragged = false }
        }
        onClicked: event => {
            if (dragged || held) return
            if (event.button === Qt.RightButton) { win.menu(di.item, iconBox); return }
            win.closePopup()
            if (event.button === Qt.MiddleButton) dock.newWindow(di.item)
            else dock.activate(di.item)
        }
        onWheel: event => dock.cycle(di.item, event.angleDelta.y > 0 ? -1 : 1)
        onContainsMouseChanged: {
            win.hoverAny = containsMouse
            if (containsMouse) {
                win.hoverItem = iconBox; win.hoverText = win.popupOpen ? "" : di.name
                if (di.windows.length > 1) listTimer.restart()
            } else {
                listTimer.stop()
                if (win.hoverItem === iconBox) { win.hoverItem = null; win.hoverText = "" }
            }
        }
        // Klick und Halten auf einem Ordner: die neuesten Dateien
        Timer { id: holdTimer; interval: 500; onTriggered: { mouse.held = true; win.recentFiles(di.item, iconBox) } }
        // Maus ruht auf einer App mit mehreren Fenstern: Fensterliste
        Timer { id: listTimer; interval: 450; onTriggered: if (mouse.containsMouse && !win.popupOpen) { win.hoverText = ""; win.windowList(di.item, iconBox) } }
    }
    Component.onDestruction: if (win && win.hoverItem === iconBox) { win.hoverItem = null; win.hoverText = "" }
}
