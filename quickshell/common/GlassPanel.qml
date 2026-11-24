import QtQuick

// Grosse Glasfläche (Panel, Dashboard, Kacheln): dunkel, halbtransparent, stark gerundet.
Rectangle {
    property real glassOpacity: Theme.glassOpacity
    radius: Theme.panelRadius
    color: Theme.glass(glassOpacity)
    border.width: Theme.borderWidth
    border.color: Theme.glassBorder
}
