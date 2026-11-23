import QtQuick

// Grosse Glasfläche (Panel, Dashboard, Kacheln): dunkel, halbtransparent, stark gerundet.
Rectangle {
    property real glassOpacity: Theme.glassOpacity
    radius: Theme.panelRadius
    color: Theme.glass(glassOpacity)
    border.width: 1
    border.color: Theme.glassBorder
}
