import QtQuick

// Leuchten des Rands (theme.border.glow): weicher äusserer Schein in Randfarbe, ohne Versatz.
// Gezeichnet als einige weiche Ringe um die Fläche (ohne Effekt-Modul, läuft auch im
// Software-Rendering der CI). Ist das Leuchten aus, entsteht nichts (kostet nichts).
//
// Als Kind der Fläche (z: -1 zeichnet unter der Fläche, die Ringe liegen ausserhalb):
//   Rectangle { id: glas; Glow { radius: glas.radius } }
Loader {
    id: g
    property real radius: 0
    property color color: Theme.borderBase
    property real size: Theme.glowSize
    property real strength: Theme.glowOpacity
    property bool on: Theme.glow
    active: on && size > 0 && strength > 0
    anchors.fill: parent
    z: -1
    sourceComponent: Item {
        Repeater {
            // je etwa 2.5 px ein Ring, höchstens 10
            model: Math.max(2, Math.min(10, Math.ceil(g.size / 2.5)))
            Rectangle {
                required property int index
                readonly property int n: Math.max(2, Math.min(10, Math.ceil(g.size / 2.5)))
                readonly property real step: g.size / n
                readonly property real grow: (index + 0.5) * step
                x: -grow; y: -grow
                width: g.width + 2 * grow; height: g.height + 2 * grow
                radius: g.radius + grow
                color: "transparent"
                border.width: step + 0.5
                // innen am stärksten, nach aussen weich auslaufend
                border.color: Qt.rgba(g.color.r, g.color.g, g.color.b, g.strength * Math.pow(1 - index / n, 2) * 0.9)
            }
        }
    }
}
