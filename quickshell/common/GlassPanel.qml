import QtQuick

// Grosse Glasfläche (Panel, Dashboard, Kacheln): dunkel, halbtransparent, stark gerundet.
Rectangle {
    property real glassOpacity: 0.44
    radius: Theme.panelRadius
    color: Theme.glass(glassOpacity)
    border.width: 1
    border.color: Theme.glassBorder
}
