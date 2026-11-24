import QtQuick

// Karte innerhalb einer Glasfläche: etwas heller als das Glas (theme.card.opacity, beim Überfahren
// theme.card.hover) mit feiner Kontur (theme.card.border_opacity); leuchtet der Rand
// (theme.border.glow), dann halb so stark wie das Glas.
Rectangle {
    id: glassCard
    property bool hoverable: false
    readonly property bool hovered: hover.hovered
    radius: Theme.cardRadius
    color: hoverable && hover.hovered ? Theme.cardHover : Theme.card
    border.width: 1
    border.color: Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 120 } }
    HoverHandler { id: hover; enabled: parent.hoverable }
    Glow { radius: glassCard.radius; size: Theme.glowSize / 2; strength: Theme.glowOpacity / 2 }
}
