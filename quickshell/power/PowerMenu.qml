import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Power-Menü als Überlagerung in der Mitte (SUPER+Escape, Knopf ⏻ in der Leiste, shell-powermenu):
// Lock, Sleep, Logout, Restart, Shutdown als grosse Knöpfe. Pfeiltasten wählen, Enter löst aus.
// Restart und Shutdown verlangen einen zweiten Druck (der Knopf zeigt dann "Press again").
// Ausgeführt wird über shell-powermenu <aktion>.
Scope {
    id: pm
    readonly property var actions: [
        { id: "lock", text: "Lock", icon: "󰌾", confirm: false },
        { id: "suspend", text: "Sleep", icon: "󰤄", confirm: false },
        { id: "logout", text: "Logout", icon: "󰍃", confirm: false },
        { id: "reboot", text: "Restart", icon: "󰜉", confirm: true },
        { id: "shutdown", text: "Shutdown", icon: "󰐥", confirm: true }
    ]
    property int sel: 0
    property string armed: ""

    // gibt "armed" (erster Druck, Bestätigung nötig) oder "done" zurück
    function press(id) {
        const a = actions.find(x => x.id === id)
        if (!a) return ""
        sel = actions.indexOf(a)
        if (a.confirm && armed !== id) { armed = id; disarm.restart(); return "armed" }
        armed = ""
        ov.hide()
        Quickshell.execDetached(["bash", "-c", "sleep 0.3; exec \"$0\" \"$1\"", Settings.bin + "shell-powermenu", id])
        return "done"
    }
    Timer { id: disarm; interval: 4000; onTriggered: pm.armed = "" }

    IpcHandler {
        target: "power"
        function open(): void { ov.show() }
        function close(): void { ov.hide() }
        function toggle(): void { ov.toggle() }
        function press(action: string): string { return pm.press(action) }
    }

    Overlay {
        id: ov
        name: "power"
        ipc: false
        place: "center"
        // fünf Knöpfe in einer Reihe; passt das nicht (schmaler Bildschirm, Hochformat), in mehreren
        readonly property int cols: Math.max(1, Math.min(pm.actions.length, Math.floor((roomW / k - 2 * 24 + 12) / (132 + 12))))
        readonly property int rows: Math.ceil(pm.actions.length / cols)
        panelWidth: cols * 132 + (cols - 1) * 12 + 2 * 24
        panelHeight: rows * 132 + (rows - 1) * 12 + 2 * 24 + 34
        keyboardFocus: WlrKeyboardFocus.Exclusive
        onOpened: { pm.sel = 0; pm.armed = "" }

        content: Component {
            Item {
                focus: true
                Keys.onLeftPressed: { pm.sel = (pm.sel + pm.actions.length - 1) % pm.actions.length; pm.armed = "" }
                Keys.onRightPressed: { pm.sel = (pm.sel + 1) % pm.actions.length; pm.armed = "" }
                Keys.onTabPressed: { pm.sel = (pm.sel + 1) % pm.actions.length; pm.armed = "" }
                Keys.onReturnPressed: pm.press(pm.actions[pm.sel].id)
                Keys.onEnterPressed: pm.press(pm.actions[pm.sel].id)

                Grid {
                    x: 24; y: 24
                    columns: ov.cols
                    spacing: Theme.pad(12)
                    Repeater {
                        model: pm.actions
                        delegate: Rectangle {
                            id: btn
                            required property var modelData
                            required property int index
                            readonly property bool active: pm.sel === index
                            readonly property bool isArmed: pm.armed === modelData.id
                            width: 132; height: 132
                            radius: Theme.cardRadius + 6
                            color: isArmed ? Theme.warn : active ? Theme.pill : (hov.hovered ? Theme.cardHover : Theme.card)
                            border.width: active || isArmed ? 0 : 1
                            border.color: Theme.cardBorder
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.pad(10)
                                Glyph {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: btn.modelData.icon
                                    size: 34
                                    color: btn.active || btn.isArmed ? Theme.pillText : Theme.text
                                }
                                Txt {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: btn.modelData.text
                                    size: 13
                                    strong: true
                                    color: btn.active || btn.isArmed ? Theme.pillText : Theme.text
                                }
                            }
                            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) pm.sel = btn.index }
                            TapHandler { onTapped: pm.press(btn.modelData.id) }
                            Probe { name: "power-" + btn.modelData.id }
                        }
                    }
                }
                Txt {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.pad(16) }
                    text: pm.armed !== "" ? "Press " + (pm.armed === "reboot" ? "Restart" : "Shutdown") + " again to confirm"
                                          : "←  →  choose   ·   Enter  confirm   ·   Esc  close"
                    size: 12
                    color: pm.armed !== "" ? Theme.warn : Theme.subtext
                }
            }
        }
    }
}
