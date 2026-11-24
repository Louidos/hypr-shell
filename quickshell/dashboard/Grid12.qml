import QtQuick
import "../common"

// Raster mit 12 Spalten und rows Zeilen; Kinder sind Cell-Elemente.
// narrow (Hochformat oder schmales Dashboard): 6 Spalten und narrowRows Zeilen, jede Karte nimmt
// dann ihre Lage aus Cell.narrowAt.
Item {
    property int rows: 3
    property bool narrow: false
    property int narrowRows: rows * 2
    property real gap: Theme.gap
    readonly property int columns: narrow ? 6 : 12
    readonly property int rowCount: narrow ? narrowRows : rows
    readonly property real cw: (width - (columns - 1) * gap) / columns
    readonly property real rh: (height - (rowCount - 1) * gap) / rowCount
}
