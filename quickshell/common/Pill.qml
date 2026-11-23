import QtQuick

// Pille mit Symbol und/oder Text. active = weisse Pille mit dunklem Inhalt (aktiver Tab / Schalter).
Rectangle {
    id: p
    property string text: ""
    property string icon: ""
    property bool active: false
    property bool clickable: true
    property real fontSize: 12
    signal clicked()

    implicitHeight: 30
    implicitWidth: row.implicitWidth + 24
    radius: height / 2
    color: active ? Theme.pill : (hover.hovered && clickable ? Theme.cardHover : Theme.card)
    border.width: active ? 0 : 1
    border.color: Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 140 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Glyph {
            visible: p.icon !== ""
            text: p.icon
            size: p.fontSize + 2
            color: p.active ? Theme.onPill : Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }
        Txt {
            visible: p.text !== ""
            text: p.text
            size: p.fontSize
            weight: Font.DemiBold
            color: p.active ? Theme.onPill : Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    HoverHandler { id: hover; cursorShape: p.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { enabled: p.clickable; onTapped: p.clicked() }
}
