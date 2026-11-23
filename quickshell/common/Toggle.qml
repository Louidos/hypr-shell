import QtQuick

// Schalter: an = weisse Pille mit dunklem Knopf.
Item {
    id: t
    property bool checked: false
    signal toggled()
    implicitWidth: 42
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: t.checked ? Theme.pill : Theme.track
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    Rectangle {
        width: t.height - 6
        height: width
        radius: width / 2
        y: 3
        x: t.checked ? t.width - width - 3 : 3
        color: t.checked ? Theme.onPill : Qt.rgba(1, 1, 1, 0.75)
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: t.toggled()
    }
}
