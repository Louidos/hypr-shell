import QtQuick
import "../common"

// Verlauf der Benachrichtigungen im Panel: Kopf mit Nicht stören und "Clear all", darunter nach App
// gruppiert (je Gruppe löschen), jede Benachrichtigung einzeln löschbar.
Item {
    id: np
    property var center
    focus: true
    readonly property var groups: {
        const g = [], idx = {}
        for (const e of center.history) {
            if (idx[e.app] === undefined) { idx[e.app] = g.length; g.push({ app: e.app, icon: e.icon, items: [] }) }
            g[idx[e.app]].items.push(e)
        }
        return g
    }
    implicitHeight: 16 + head.height + 12 + (center.history.length === 0 ? 90 : Math.min(list.contentHeight, 640)) + 16

    Item {
        id: head
        x: 16; y: 16
        width: parent.width - 32
        height: 36
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Txt { text: "Notifications"; size: 16; weight: Font.Bold }
            Txt {
                text: np.center.history.length === 0 ? "All caught up" : np.center.history.length + " in history"
                size: 11
                sub: true
            }
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8
            Txt { anchors.verticalCenter: parent.verticalCenter; text: "Do not disturb"; size: 12; sub: true }
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: np.center.dnd
                onToggled: np.center.setDnd(!np.center.dnd)
                Probe { name: "notifications-dnd" }
            }
            Pill {
                anchors.verticalCenter: parent.verticalCenter
                visible: np.center.history.length > 0
                implicitHeight: 28
                fontSize: 11
                icon: "󰎟"
                text: "Clear all"
                onClicked: np.center.clearAll()
                Probe { name: "notifications-clear" }
            }
        }
    }

    Column {
        visible: np.center.history.length === 0
        anchors { top: head.bottom; topMargin: 24; horizontalCenter: parent.horizontalCenter }
        spacing: 6
        Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: "󰂜"; size: 28; color: Theme.subtext }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "No notifications"; sub: true }
    }

    ListView {
        id: list
        visible: np.center.history.length > 0
        x: 12
        anchors { top: head.bottom; topMargin: 12; bottom: parent.bottom; bottomMargin: 16 }
        width: parent.width - 24
        clip: true
        spacing: 12
        boundsBehavior: Flickable.StopAtBounds
        model: np.groups
        delegate: Column {
            id: grp
            required property var modelData
            width: list.width
            spacing: 6
            Item {
                width: parent.width
                height: 24
                AppIcon { id: gi; size: 18; icon: grp.modelData.icon; anchors.verticalCenter: parent.verticalCenter; x: 4 }
                Txt {
                    anchors { left: gi.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: grp.modelData.app + "  (" + grp.modelData.items.length + ")"
                    size: 12
                    weight: Font.DemiBold
                }
                IconButton {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24
                    flat: true
                    iconSize: 11
                    icon: "󰎟"
                    onClicked: np.center.clearApp(grp.modelData.app)
                }
            }
            Repeater {
                model: grp.modelData.items
                delegate: NotificationCard {
                    required property var modelData
                    width: grp.width
                    info: modelData
                    center: np.center
                }
            }
        }
    }
}
