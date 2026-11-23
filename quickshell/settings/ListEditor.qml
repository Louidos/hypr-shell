import QtQuick
import "../common"

// Sortierbare Liste mit Pfeilen hoch/runter. Mit allowed (feste Werte): je Eintrag ein Schalter,
// ausgeschaltete stehen unten. Ohne allowed (freie Texte, z. B. Apps): löschen und hinzufügen.
Column {
    id: le
    property var value: []
    property var allowed: null
    property bool sortable: true
    property string probePrefix: ""
    signal changedList(var list)
    spacing: 4

    readonly property var labels: ({
        distro: "Distro icon", workspaces: "Workspaces", window: "Window title", media: "Now playing",
        volume: "Volume", battery: "Battery", clock: "Clock", bluetooth: "Bluetooth", network: "Network",
        tray: "Tray", recording: "Recording dot", power: "Power button",
        cpu: "CPU", ram: "RAM", gpu: "GPU", disk: "Disk",
        dashboard: "Dashboard", wallpaper: "Wallpaper", performance: "Performance", about: "About",
        weather: "Weather", profile: "Profile", calendar: "Calendar", rings: "Usage rings",
        awake: "Keep Awake", apps: "Apps", shot: "Screenshot", toggles: "Quick toggles",
        wifi: "Wi-Fi", dnd: "Do not disturb", gaming: "Gaming mode", settings: "Settings"
    })
    function label(v) { return labels[v] || v }

    readonly property var items: {
        const on = (value || []).map(v => ({ name: v, on: true }))
        if (!allowed) return on
        const off = allowed.filter(v => (value || []).indexOf(v) < 0).map(v => ({ name: v, on: false }))
        return on.concat(off)
    }
    function move(i, d) {
        const l = value.slice(), j = i + d
        if (j < 0 || j >= l.length) return
        const t = l[i]; l[i] = l[j]; l[j] = t
        changedList(l)
    }
    function toggle(name, on) {
        if (on) changedList(value.concat([name]))
        else changedList(value.filter(v => v !== name))
    }

    Repeater {
        model: le.items
        delegate: Rectangle {
            id: item
            required property var modelData
            required property int index
            width: le.width
            height: 38
            radius: 12
            color: hover.hovered ? Theme.cardHover : Qt.rgba(1, 1, 1, 0.03)
            HoverHandler { id: hover }
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 12
                Toggle {
                    visible: le.allowed !== null
                    anchors.verticalCenter: parent.verticalCenter
                    checked: item.modelData.on
                    onToggled: le.toggle(item.modelData.name, !item.modelData.on)
                    Probe { name: le.probePrefix !== "" ? le.probePrefix + item.modelData.name : "" }
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: le.label(item.modelData.name)
                    size: 13
                    color: item.modelData.on ? Theme.text : Theme.subtext
                }
            }
            Row {
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                spacing: 2
                visible: item.modelData.on
                IconButton {
                    visible: le.sortable
                    flat: true; width: 28; height: 28; iconSize: 12; icon: "󰁝"
                    opacity: item.index > 0 ? 1 : 0.3
                    onClicked: le.move(item.index, -1)
                }
                IconButton {
                    visible: le.sortable
                    flat: true; width: 28; height: 28; iconSize: 12; icon: "󰁅"
                    opacity: item.index < le.value.length - 1 ? 1 : 0.3
                    onClicked: le.move(item.index, 1)
                }
                IconButton {
                    visible: le.allowed === null
                    flat: true; width: 28; height: 28; iconSize: 12; icon: "󰆴"
                    onClicked: le.changedList(le.value.filter((v, i) => i !== item.index))
                }
            }
        }
    }
    // freie Texte: neuen Eintrag hinzufügen
    Field {
        visible: le.allowed === null
        width: le.width
        placeholder: "Add entry and press Enter"
        onAccepted: t => {
            const v = t.trim()
            if (v !== "" && le.value.indexOf(v) < 0) le.changedList(le.value.concat([v]))
            input.text = ""
        }
    }
}
