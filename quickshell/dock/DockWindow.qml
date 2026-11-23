import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"

// Ein Dock auf einem Bildschirm: Layer-Shell-Fenster an der Kante (dock.position), das Glas mittig
// mit dock.margin Abstand. Die Eingabefläche (mask) ist genau das sichtbare Glas, Klicks daneben
// gehen an die Fenster darunter. Zu viele Einträge: Symbole werden bis dock.icon_min_size kleiner,
// danach lässt sich das Dock mit dem Mausrad verschieben; länger als dock.max_length wird es nie.
PanelWindow {
    id: win
    property var dock
    readonly property var d: dock
    readonly property var dockWindow: win

    // Modell als Schlüssel (für ScriptModel: gleiche Schlüssel behalten ihre Symbole) + Daten
    readonly property var entries: d ? d.model(screen) : []
    readonly property var keys: entries.map(o => o.key)
    readonly property var byKey: {
        const m = {}
        for (let i = 0; i < entries.length; i++) m[entries[i].key] = entries[i]
        return m
    }

    // ---- Masse
    readonly property bool vertical: d.vertical
    readonly property string pos: d.position
    readonly property real screenLen: vertical ? (screen ? screen.height : 1080) : (screen ? screen.width : 1920)
    readonly property int nIcons: entries.filter(o => o.kind !== "separator").length
    readonly property int nSeps: entries.length - nIcons
    readonly property int sepW: 1 + d.spacing
    function lengthFor(s) { return nIcons * s + Math.max(0, entries.length - 1) * d.spacing + nSeps * sepW + 2 * d.padding }
    readonly property real maxBody: Math.floor(screenLen * d.maxLength)
    readonly property int icon: nIcons === 0 ? d.iconSize
        : Math.max(d.iconMin, Math.min(d.iconSize, Math.floor((maxBody - lengthFor(0)) / nIcons)))
    readonly property real contentLen: lengthFor(icon)
    readonly property bool scrolls: contentLen > maxBody + 0.5
    readonly property real bodyLen: Math.min(maxBody, contentLen)
    readonly property int labelRoom: d.labels === "always" ? 16 : 0
    readonly property int thickness: icon + 2 * d.padding + labelRoom
    readonly property int radius: Math.min(d.radius, Math.floor(thickness / 2))
    readonly property int shadowPad: d.shadow === "none" ? 0 : d.shadow === "soft" ? 12 : d.shadow === "medium" ? 18 : 26
    readonly property int tipRoom: d.labels === "hover" ? (vertical ? 240 : 44) : 0
    readonly property int outward: Math.max(tipRoom, shadowPad)
    readonly property int sideRoom: Math.max(shadowPad, vertical ? 24 : 80)

    function geometry() {
        return { x: Math.round(body.x), y: Math.round(body.y), width: Math.round(body.width), height: Math.round(body.height),
                 windowWidth: width, windowHeight: height, icon: icon, scrolls: scrolls, radius: radius }
    }
    Component.onCompleted: { const l = d.windows.slice(); l.push(win); d.windows = l }
    Component.onDestruction: { if (d) d.windows = d.windows.filter(w => w !== win) }

    anchors {
        bottom: pos === "bottom"
        top: pos === "top"
        left: pos === "left"
        right: pos === "right"
    }
    implicitWidth: vertical ? d.margin + thickness + outward : Math.min(screenLen, bodyLen + 2 * sideRoom)
    implicitHeight: vertical ? Math.min(screenLen, bodyLen + 2 * sideRoom) : d.margin + thickness + outward
    visible: d.on && d.shown
    color: "transparent"
    exclusionMode: d.reserve ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: d.reserve ? d.margin + thickness : 0
    WlrLayershell.layer: d.topLayer ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "hypr-shell-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: body }

    // Name des Symbols unter der Maus (dock.labels = hover), ausserhalb des Glases
    property var hoverItem: null
    property string hoverText: ""
    Rectangle {
        id: tip
        visible: win.d.labels === "hover" && win.hoverItem !== null && win.hoverText !== ""
        readonly property point c: win.hoverItem ? win.hoverItem.mapToItem(win.contentItem, win.hoverItem.width / 2, win.hoverItem.height / 2) : Qt.point(0, 0)
        width: tipText.implicitWidth + 20
        height: tipText.implicitHeight + 10
        radius: height / 2
        color: Theme.glass(0.82)
        border.width: 1
        border.color: Theme.glassBorder
        x: win.vertical ? (win.pos === "left" ? body.x + body.width + 10 : body.x - width - 10)
                        : Math.max(2, Math.min(win.width - width - 2, c.x - width / 2))
        y: win.vertical ? Math.max(2, Math.min(win.height - height - 2, c.y - height / 2))
                        : (win.pos === "bottom" ? body.y - height - 10 : body.y + body.height + 10)
        Txt {
            id: tipText
            anchors.centerIn: parent
            text: win.hoverText
            size: 12
        }
    }

    Item {
        id: body
        width: win.vertical ? win.thickness : win.bodyLen
        height: win.vertical ? win.bodyLen : win.thickness
        x: win.pos === "left" ? win.d.margin : win.pos === "right" ? parent.width - win.d.margin - width : Math.round((parent.width - width) / 2)
        y: win.pos === "top" ? win.d.margin : win.pos === "bottom" ? parent.height - win.d.margin - height : Math.round((parent.height - height) / 2)

        // Schatten: einige weiche Ränder um das Glas (ohne Effekt-Modul, läuft mit jedem Qt)
        Repeater {
            model: win.shadowPad > 0 ? 4 : 0
            Rectangle {
                required property int index
                readonly property real grow: (index + 1) * win.shadowPad / 4
                x: -grow; y: -grow + (win.pos === "top" ? 0 : win.shadowPad / 6)
                width: body.width + 2 * grow; height: body.height + 2 * grow
                radius: win.radius + grow
                color: "transparent"
                border.width: win.shadowPad / 4 + 1
                border.color: Qt.rgba(0, 0, 0, (win.d.shadow === "strong" ? 0.16 : win.d.shadow === "medium" ? 0.11 : 0.07) * (1 - index / 4))
            }
        }

        Rectangle {
            id: glass
            anchors.fill: parent
            radius: win.radius
            color: win.d.glassColor
            border.width: win.d.borderWidth
            border.color: win.d.borderColor
            Behavior on color { ColorAnimation { duration: 400 } }
        }

        Flickable {
            id: flick
            anchors.fill: parent
            clip: win.scrolls
            interactive: win.scrolls
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: win.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
            contentWidth: row.width + 2 * win.d.padding
            contentHeight: row.height + 2 * win.d.padding
            // Mausrad verschiebt ein volles Dock (auch quer zur Richtung)
            WheelHandler {
                enabled: win.scrolls
                onWheel: event => {
                    const delta = (event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x) / 2
                    if (win.vertical) flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - delta))
                    else flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - delta))
                }
            }

            Grid {
                id: row
                x: win.d.padding
                y: win.d.padding
                columns: win.vertical ? 1 : Math.max(1, win.keys.length)
                rows: win.vertical ? Math.max(1, win.keys.length) : 1
                spacing: win.d.spacing
                Repeater {
                    model: ScriptModel { values: win.keys }
                    DockItem {
                        required property var modelData
                        // eigener Name: im Symbol heissen die Eigenschaften selbst "win" und "dock"
                        item: dockWindow.byKey[modelData] || null
                        dock: dockWindow.d
                        win: dockWindow
                        size: dockWindow.icon
                    }
                }
            }
        }
    }
}
