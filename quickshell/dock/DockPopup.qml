import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"

// Kleine Glas-Liste über einem Dock-Symbol: Menü (Rechtsklick, Menütaste), Fensterliste
// (mehrere Fenster, mit Vorschau bei dock.previews) oder die neuesten Dateien eines Ordners.
// rows: [{ text, icon (Glyphe), appIcon, toplevel, run, keep }]
PopupWindow {
    id: pop
    property var dock
    property var win
    property Item target: null
    property var rows: []
    property string mode: "menu"           // menu | windows | files
    property int selected: -1              // Tastatur
    signal done()

    readonly property string pos: dock ? dock.position : "bottom"
    readonly property bool previews: mode === "windows" && dock && dock.previews
    readonly property point at: target && win ? target.mapToItem(win.contentItem, 0, 0) : Qt.point(0, 0)

    anchor.window: win
    anchor.rect.x: at.x
    anchor.rect.y: at.y
    anchor.rect.width: target ? target.width : 1
    anchor.rect.height: target ? target.height : 1
    anchor.edges: pos === "bottom" ? Edges.Top : pos === "top" ? Edges.Bottom : pos === "left" ? Edges.Right : Edges.Left
    anchor.gravity: anchor.edges
    anchor.margins.top: pos === "bottom" ? 14 : 0
    anchor.margins.bottom: pos === "top" ? 14 : 0
    anchor.margins.left: pos === "right" ? 14 : 0
    anchor.margins.right: pos === "left" ? 14 : 0
    color: "transparent"
    implicitWidth: Math.max(180, col.implicitWidth + 16)
    implicitHeight: col.implicitHeight + 16

    function run(i) {
        if (i < 0 || i >= rows.length) return
        const r = rows[i]
        if (r.run) r.run()
        if (!r.keep) done()
        else rows = rows.slice()          // Text kann sich ändern ("Click again to empty")
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.panelRadius
        color: Theme.glass(0.86)
        border.width: Theme.borderWidth
        border.color: Theme.glassBorder
        HoverHandler { id: popHover }
    }
    readonly property bool hovered: popHover.hovered

    Column {
        id: col
        x: 8; y: 8
        spacing: Theme.pad(2)
        Repeater {
            model: pop.rows
            Rectangle {
                id: row
                required property var modelData
                required property int index
                width: Math.max(164, rowContent.implicitWidth + 20)
                height: pop.previews && modelData.toplevel ? 112 : 32
                radius: 9
                color: pop.selected === index || ma.containsMouse ? Theme.cardHover : "transparent"
                border.width: pop.selected === index ? 1 : 0
                border.color: Theme.accent
                Row {
                    id: rowContent
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.pad(10)
                    Item {
                        visible: pop.previews && !!row.modelData.toplevel
                        width: visible ? 150 : 0
                        height: visible ? 96 : 0
                        Rectangle { anchors.fill: parent; radius: 6; color: Theme.card }
                        Loader {
                            anchors.fill: parent
                            // nur für Fenster, die es noch gibt (Vorschau eines geschlossenen Fensters = Absturzgefahr)
                            active: pop.visible && pop.previews && !!row.modelData.toplevel && !!pop.dock && pop.dock.alive(row.modelData.toplevel)
                            sourceComponent: ScreencopyView {
                                captureSource: row.modelData.toplevel
                                live: false
                            }
                        }
                    }
                    Glyph {
                        visible: !row.modelData.appIcon && !!row.modelData.icon
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.icon || ""
                        size: 15
                        color: Theme.subtext
                    }
                    AppIcon {
                        visible: !!row.modelData.appIcon
                        anchors.verticalCenter: parent.verticalCenter
                        icon: row.modelData.appIcon || ""
                        size: 18
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 300)
                        text: row.modelData.text
                        size: 13
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.run(row.index)
                }
            }
        }
    }
}
