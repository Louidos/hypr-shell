import QtQuick
import "../common"

// Regler mit Schritten. Während des Ziehens meldet moved(v) jeden neuen Wert (die App schreibt ihn
// sofort, damit man die Wirkung sieht), beim Loslassen released(v).
Item {
    id: sl
    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property real value: 0
    property real dragValue: value
    readonly property bool dragging: ma.pressed
    readonly property real shown: dragging ? dragValue : value
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0
    signal moved(real v)
    signal released(real v)

    implicitWidth: 200
    implicitHeight: 24

    function snap(v) {
        let s = stepSize > 0 ? Math.round((v - from) / stepSize) * stepSize + from : v
        s = Math.min(to, Math.max(from, s))
        return Number(s.toFixed(6))
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: Theme.corner(3)
        color: Theme.track
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: knob.x + knob.width / 2
        height: 6
        radius: Theme.corner(3)
        color: Qt.rgba(1, 1, 1, 0.75)
    }
    Rectangle {
        id: knob
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: Theme.corner(9)
        x: sl.frac * (sl.width - width)
        color: Theme.pill
        border.width: sl.dragging ? 3 : 0
        border.color: Qt.rgba(1, 1, 1, 0.35)
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function at(mx) {
            const f = (mx - 6 - knob.width / 2) / Math.max(1, sl.width - knob.width)
            return sl.snap(sl.from + (sl.to - sl.from) * Math.max(0, Math.min(1, f)))
        }
        onPressed: mouse => { sl.dragValue = at(mouse.x); sl.moved(sl.dragValue) }
        onPositionChanged: mouse => {
            if (!pressed) return
            const v = at(mouse.x)
            if (v !== sl.dragValue) { sl.dragValue = v; sl.moved(v) }
        }
        onReleased: sl.released(sl.dragValue)
    }
}
