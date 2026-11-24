import QtQuick

// Grosse Glasfläche (Panel, Dashboard, Kacheln): dunkel, halbtransparent, stark gerundet, mit
// feinem Rand und auf Wunsch leuchtendem Rand (theme.border.glow).
Rectangle {
    id: gp
    property real glassOpacity: Theme.glassOpacity
    radius: Theme.panelRadius
    color: Theme.glass(glassOpacity)
    border.width: Theme.borderWidth
    border.color: Theme.glassBorder
    Glow { radius: gp.radius }
}
