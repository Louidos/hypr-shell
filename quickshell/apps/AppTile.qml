import QtQuick
import "../common"

// Ein Feld im App-Raster: Symbol, Name und Stern für Favoriten. Klick startet, Mittelklick öffnet ein
// neues Fenster, Rechtsklick das Menü (Lage in Koordinaten des Felds).
Item {
    id: tile
    property var entry: null
    property bool selected: false
    property bool favorite: false
    property real iconSize: 48
    signal hovered()
    signal launch()
    signal newWindow()
    signal menu(real x, real y)

    Rectangle {
        anchors { fill: parent; margins: Theme.pad(4) }
        radius: Theme.cardRadius
        color: tile.selected ? Theme.cardHover : (th.hovered ? Theme.card : "transparent")
        border.width: tile.selected ? Theme.borderWidth : 0
        border.color: Theme.accent
    }
    AppIcon {
        id: ti
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Math.max(8, tile.height * 0.12) }
        size: tile.iconSize
        icon: tile.entry ? (tile.entry.icon || "") : ""
    }
    Glyph {
        visible: tile.favorite
        anchors { right: parent.right; top: parent.top; margins: Theme.pad(10) }
        text: "󰓎"
        size: 11
        color: Theme.accent
    }
    Txt {
        anchors { top: ti.bottom; topMargin: Theme.pad(8); left: parent.left; right: parent.right; leftMargin: Theme.pad(8); rightMargin: Theme.pad(8) }
        text: tile.entry ? String(tile.entry.name) : ""
        size: 12
        horizontalAlignment: Text.AlignHCenter
        maximumLineCount: 2
        wrapMode: Text.Wrap
    }
    HoverHandler { id: th; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) tile.hovered() }
    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: tile.launch() }
    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: tile.newWindow() }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: (ev) => tile.menu(ev.position.x, ev.position.y) }
}
