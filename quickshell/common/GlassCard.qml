import QtQuick

// Karte innerhalb einer Glasfläche: leicht heller (Weiss 5 %) mit feiner Kontur.
Rectangle {
    property bool hoverable: false
    readonly property bool hovered: hover.hovered
    radius: Theme.cardRadius
    color: hoverable && hover.hovered ? Theme.cardHover : Theme.card
    border.width: 1
    border.color: Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 120 } }
    HoverHandler { id: hover; enabled: parent.hoverable }
}
