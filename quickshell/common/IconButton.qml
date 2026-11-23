import QtQuick

// Runder Knopf mit Symbol; active = weisse Pille mit dunklem Symbol.
Rectangle {
    id: b
    property string icon: ""
    property bool active: false
    property real iconSize: 15
    property bool flat: false
    signal clicked()
    implicitWidth: 34
    implicitHeight: 34
    radius: height / 2
    color: active ? Theme.pill : (hover.hovered ? Theme.cardHover : (flat ? "transparent" : Theme.card))
    border.width: active || flat ? 0 : 1
    border.color: Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 140 } }
    Glyph {
        anchors.centerIn: parent
        text: b.icon
        size: b.iconSize
        color: b.active ? Theme.pillText : Theme.text
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: b.clicked() }
}
