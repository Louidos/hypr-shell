import QtQuick
import "../common"

// Karte im 12-Spalten-Raster des Dashboards. Das Elternelement ist ein Grid12.
GlassCard {
    property int col: 0
    property int row: 0
    property int cs: 1
    property int rs: 1
    readonly property Item grid: parent
    x: col * (grid.cw + grid.gap)
    y: row * (grid.rh + grid.gap)
    width: cs * grid.cw + (cs - 1) * grid.gap
    height: rs * grid.rh + (rs - 1) * grid.gap
}
