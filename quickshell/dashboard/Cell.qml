import QtQuick
import "../common"

// Karte im 12-Spalten-Raster des Dashboards. Das Elternelement ist ein Grid12.
// narrowAt: [Spalte, Zeile, Breite, Höhe] im schmalen Raster (6 Spalten, Hochformat); ohne Angabe
// bleibt die Karte an ihrer Stelle, auf 6 Spalten begrenzt.
GlassCard {
    property int col: 0
    property int row: 0
    property int cs: 1
    property int rs: 1
    property var narrowAt: null
    readonly property Item grid: parent
    readonly property var at: grid.narrow
        ? (narrowAt || [Math.min(col, 5), row, Math.min(cs, 6 - Math.min(col, 5)), rs])
        : [col, row, cs, rs]
    x: at[0] * (grid.cw + grid.gap)
    y: at[1] * (grid.rh + grid.gap)
    width: at[2] * grid.cw + (at[2] - 1) * grid.gap
    height: at[3] * grid.rh + (at[3] - 1) * grid.gap
}
