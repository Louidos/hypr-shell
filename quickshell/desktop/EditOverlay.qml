import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"

// Bearbeiten-Modus (SUPER+ALT+W oder "Edit on desktop" in den Einstellungen): eine Fläche über dem
// ganzen Bildschirm. Uhr und Kacheln bekommen einen Rahmen, lassen sich ziehen und mit dem Mausrad
// skalieren; Hilfslinien an Rändern und Mitte, beim Annähern rasten sie ein. Oben Done, Cancel und
// Reset positions; Esc bricht ab. Die Widgets selbst nehmen weiterhin keine Klicks an.
PanelWindow {
    id: ov
    property var clockWin
    property var tilesWin
    // gibt es den Bildschirm? (von Desktop.qml gesetzt; "screen" selbst hier abzufragen ergäbe eine
    // Bindungsschleife, weil Quickshell screen beim Ein- und Ausblenden neu meldet)
    property bool hasScreen: true
    readonly property real sw: Settings.screenWidth(screen)
    readonly property real sh: Settings.screenHeight(screen)
    readonly property real snap: 10
    // aktive Hilfslinien (beim Ziehen): Liste von {v: true/false, pos}
    property var guides: []

    visible: Ui.editDesktop && ov.hasScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: Qt.rgba(0, 0, 0, 0.28)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hypr-shell-edit"
    // Tastatur nur, solange der Bearbeiten-Modus sichtbar läuft
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Ui.cancelEdit()
    }
    onVisibleChanged: { Ui.setKeyboard("hypr-shell-edit", visible); if (visible) { guides = []; keys.forceActiveFocus() } }

    // ---- feste Hilfslinien: Mitte und Ränder (2 %)
    Repeater {
        model: [
            { v: true, pos: ov.sw / 2 }, { v: false, pos: ov.sh / 2 },
            { v: true, pos: ov.sw * 0.02 }, { v: true, pos: ov.sw * 0.98 },
            { v: false, pos: ov.sh * 0.04 }, { v: false, pos: ov.sh * 0.96 }
        ]
        delegate: Rectangle {
            required property var modelData
            readonly property bool hot: ov.guides.some(g => g.v === modelData.v && Math.abs(g.pos - modelData.pos) < 0.5)
            x: modelData.v ? modelData.pos - width / 2 : 0
            y: modelData.v ? 0 : modelData.pos - height / 2
            width: modelData.v ? (hot ? 2 : 1) : ov.sw
            height: modelData.v ? ov.sh : (hot ? 2 : 1)
            color: hot ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.16)
        }
    }

    // ---- Rahmen je Widget
    Repeater {
        model: [
            { which: "clock", label: "Clock", win: ov.clockWin },
            { which: "resources", label: "Tiles", win: ov.tilesWin }
        ]
        delegate: Rectangle {
            id: fr
            required property var modelData
            readonly property string which: modelData.which
            readonly property var win: modelData.win
            visible: win !== undefined && win !== null && win.visible
            // wo das Widget wirklich steht (auf den Bildschirm begrenzt, siehe ClockWidget.qml)
            x: win ? win.margins.left : Ui.widget(which, "x", 0) * ov.sw
            y: win ? win.margins.top : Ui.widget(which, "y", 0) * ov.sh
            width: win ? win.implicitWidth : 100
            height: win ? win.implicitHeight : 100
            color: drag.pressed ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
            radius: 14
            border.width: 2
            border.color: drag.pressed || hov.hovered ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.55)

            Pill {
                anchors { left: parent.left; bottom: parent.top; bottomMargin: 8 }
                clickable: false
                implicitHeight: 26
                fontSize: 11
                icon: "󰆾"
                text: fr.modelData.label + " · " + Math.round(Ui.widget(fr.which, "scale", 1) * 100) + " %"
            }
            HoverHandler { id: hov; cursorShape: drag.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
            MouseArea {
                id: drag
                anchors.fill: parent
                property real ox: 0
                property real oy: 0
                onPressed: mouse => { ox = mouse.x; oy = mouse.y }
                onPositionChanged: mouse => {
                    if (!pressed) return
                    const p = mapToItem(null, mouse.x, mouse.y)
                    const r = ov.snapTo(p.x - ox, p.y - oy, fr.width, fr.height)
                    Ui.moveDraft(fr.which, r.x / ov.sw, r.y / ov.sh)
                }
                onReleased: ov.guides = []
                onWheel: wheel => Ui.scaleDraft(fr.which, Ui.widget(fr.which, "scale", 1) + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
            Probe { name: "edit-" + fr.which }
        }
    }
    // an Mitte und Rändern einrasten; gibt die neue Lage zurück und merkt die aktiven Linien
    function snapTo(x, y, w, h) {
        const g = []
        const vx = [sw / 2, sw * 0.02, sw * 0.98], hy = [sh / 2, sh * 0.04, sh * 0.96]
        let nx = x, ny = y
        for (const t of vx) {
            if (Math.abs(x - t) < snap) { nx = t; g.push({ v: true, pos: t }); break }
            if (Math.abs(x + w / 2 - t) < snap) { nx = t - w / 2; g.push({ v: true, pos: t }); break }
            if (Math.abs(x + w - t) < snap) { nx = t - w; g.push({ v: true, pos: t }); break }
        }
        for (const t of hy) {
            if (Math.abs(y - t) < snap) { ny = t; g.push({ v: false, pos: t }); break }
            if (Math.abs(y + h / 2 - t) < snap) { ny = t - h / 2; g.push({ v: false, pos: t }); break }
            if (Math.abs(y + h - t) < snap) { ny = t - h; g.push({ v: false, pos: t }); break }
        }
        guides = g
        return { x: Math.max(0, Math.min(sw - 20, nx)), y: Math.max(0, Math.min(sh - 20, ny)) }
    }


    // ---- Leiste oben: Done, Cancel, Reset positions
    GlassPanel {
        id: bar
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 48 }
        width: barRow.implicitWidth + 28
        height: 52
        radius: 26
        glassOpacity: 0.85
        Row {
            id: barRow
            anchors.centerIn: parent
            spacing: 10
            Txt { anchors.verticalCenter: parent.verticalCenter; text: "Drag to move · scroll to resize · Esc cancels"; size: 13; weight: Font.DemiBold; rightPadding: 6 }
            Pill { text: "Reset positions"; icon: "󰑓"; onClicked: Ui.resetDraft(); Probe { name: "edit-reset" } }
            Pill { text: "Cancel"; icon: "󰅖"; onClicked: Ui.cancelEdit(); Probe { name: "edit-cancel" } }
            Pill { text: "Done"; icon: "󰄬"; active: true; onClicked: Ui.finishEdit(); Probe { name: "edit-done" } }
        }
    }
}
