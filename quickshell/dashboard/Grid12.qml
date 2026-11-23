import QtQuick

// Raster mit 12 Spalten und rows Zeilen; Kinder sind Cell-Elemente.
Item {
    property int rows: 3
    property real gap: 10
    readonly property real cw: (width - 11 * gap) / 12
    readonly property real rh: (height - (rows - 1) * gap) / rows
}
