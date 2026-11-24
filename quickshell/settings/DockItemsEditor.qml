import QtQuick
import Quickshell
import "../common"

// Editor für dock.items: Liste zum Sortieren (Ziehen am Griff oder Pfeile), Entfernen, Hinzufügen
// von installierten Programmen (durchsuchbar), Ordnern, Trenner, Papierkorb und Startknopf.
// Jede Änderung geht sofort über shell-set (atomar) an das Dock.
Column {
    id: ed
    spacing: Theme.pad(10)
    readonly property var items: {
        const v = Settings.get("dock.items", [{"type": "app", "desktop_id": "org.gnome.Nautilus", "path": ""}, {"type": "app", "desktop_id": "kitty", "path": ""}, {"type": "app", "desktop_id": "firefox", "path": ""}, {"type": "separator", "desktop_id": "", "path": ""}, {"type": "folder", "desktop_id": "", "path": "~/Downloads"}, {"type": "separator", "desktop_id": "", "path": ""}, {"type": "trash", "desktop_id": "", "path": ""}])
        return Array.isArray(v) ? v : []
    }
    function save(l) { Ui.set("dock.items", l) }
    function move(i, to) {
        if (to < 0 || to >= items.length || to === i) return
        const l = items.slice()
        const x = l.splice(i, 1)[0]
        l.splice(to, 0, x)
        save(l)
    }
    function remove(i) { save(items.filter((v, j) => j !== i)) }
    function add(it) { save(items.concat([it])) }
    function entry(id) { return id ? (DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)) : null }
    function label(it) {
        if (it.type === "app") { const e = entry(it.desktop_id); return e ? e.name : it.desktop_id + "  (not installed)" }
        if (it.type === "folder") return it.path
        return ({ separator: "Separator", trash: "Trash", launcher: "Launcher button" })[it.type] || it.type
    }
    function icon(it) {
        if (it.type === "app") { const e = entry(it.desktop_id); return e ? e.icon : "" }
        return ({ folder: "folder", trash: "user-trash", launcher: "view-app-grid-symbolic" })[it.type] || ""
    }

    Txt { text: "Items"; size: 16; strong: true }
    Txt { width: parent.width; text: "Order of the dock. Drag the handle or use the arrows; running apps that are not pinned appear after the pinned apps."; size: 12; sub: true; wrapMode: Text.Wrap }

    // ---- Liste
    Item {
        id: listBox
        width: parent.width
        height: ed.items.length * 42
        property int dragFrom: -1
        property int dragTo: -1
        property real dragY: 0
        Repeater {
            model: ed.items
            delegate: Rectangle {
                id: rowItem
                required property var modelData
                required property int index
                readonly property bool lifted: listBox.dragFrom === index
                width: listBox.width
                height: 38
                radius: 12
                x: 0
                y: lifted ? listBox.dragY - 19 : 42 * (
                    listBox.dragFrom < 0 ? index
                    : index > listBox.dragFrom && index <= listBox.dragTo ? index - 1
                    : index < listBox.dragFrom && index >= listBox.dragTo ? index + 1 : index)
                z: lifted ? 2 : 1
                color: hover.hovered || lifted ? Theme.cardHover : Theme.cardSoft
                Behavior on y { enabled: !rowItem.lifted; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                HoverHandler { id: hover }
                Row {
                    anchors { left: parent.left; leftMargin: Theme.pad(6); verticalCenter: parent.verticalCenter }
                    spacing: Theme.pad(10)
                    // Griff zum Ziehen
                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰇛"
                        size: 14
                        color: Theme.subtext
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.SizeVerCursor
                            preventStealing: true
                            onPressed: { listBox.dragY = rowItem.y + 19; listBox.dragFrom = rowItem.index; listBox.dragTo = rowItem.index }
                            onPositionChanged: {
                                const yy = mapToItem(listBox, mouseX, mouseY).y
                                listBox.dragY = Math.max(0, Math.min(listBox.height, yy))
                                listBox.dragTo = Math.max(0, Math.min(ed.items.length - 1, Math.floor(yy / 42)))
                            }
                            onReleased: {
                                const f = listBox.dragFrom, t = listBox.dragTo
                                listBox.dragFrom = -1; listBox.dragTo = -1
                                ed.move(f, t)
                            }
                        }
                    }
                    AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ed.icon(rowItem.modelData) !== ""
                        icon: ed.icon(rowItem.modelData)
                        size: 20
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ed.label(rowItem.modelData)
                        size: 13
                        color: rowItem.modelData.type === "separator" ? Theme.subtext : Theme.text
                    }
                }
                Row {
                    anchors { right: parent.right; rightMargin: Theme.pad(6); verticalCenter: parent.verticalCenter }
                    spacing: Theme.pad(2)
                    IconButton { flat: true; width: 28; height: 28; iconSize: 12; icon: "󰁝"; opacity: rowItem.index > 0 ? 1 : 0.3; onClicked: ed.move(rowItem.index, rowItem.index - 1) }
                    IconButton { flat: true; width: 28; height: 28; iconSize: 12; icon: "󰁅"; opacity: rowItem.index < ed.items.length - 1 ? 1 : 0.3; onClicked: ed.move(rowItem.index, rowItem.index + 1) }
                    IconButton {
                        flat: true; width: 28; height: 28; iconSize: 12; icon: "󰆴"
                        onClicked: ed.remove(rowItem.index)
                        Probe { name: "dock-item-remove-" + rowItem.index }
                    }
                }
            }
        }
    }

    // ---- Hinzufügen
    Flow {
        width: parent.width
        spacing: Theme.pad(6)
        Pill { text: "Separator"; icon: "󰇜"; onClicked: ed.add({ type: "separator", desktop_id: "", path: "" }); Probe { name: "dock-add-separator" } }
        Pill { text: "Trash"; icon: "󰩹"; visible: !ed.items.some(i => i.type === "trash"); onClicked: ed.add({ type: "trash", desktop_id: "", path: "" }) }
        Pill { text: "Launcher button"; icon: "󰀻"; visible: !ed.items.some(i => i.type === "launcher"); onClicked: ed.add({ type: "launcher", desktop_id: "", path: "" }) }
    }
    // Ordner: Pfad eintippen oder einen der Vorschläge wählen
    Row {
        width: parent.width
        spacing: Theme.pad(8)
        Field {
            id: folderField
            width: parent.width - addFolder.width - 8
            mono: true
            placeholder: "Folder, e.g. ~/Documents"
            onAccepted: t => { if (t.trim() !== "") { ed.add({ type: "folder", desktop_id: "", path: t.trim() }); input.text = "" } }
        }
        Pill {
            id: addFolder
            text: "Add folder"
            icon: "󰉗"
            onClicked: { const t = folderField.input.text.trim(); if (t !== "") { ed.add({ type: "folder", desktop_id: "", path: t }); folderField.input.text = "" } }
        }
    }
    Flow {
        width: parent.width
        spacing: Theme.pad(6)
        Repeater {
            model: {
                const l = ["~/Downloads", "~/Documents", "~/Pictures", "~/Music", "~/Videos"]
                if (Integrations.nextcloud) l.push(String(Settings.get("nextcloud.mount_path", "~/Nextcloud")))
                if (Integrations.missa) l.push(String(Settings.get("missa.folder", "~/Missa")))
                return l.filter(p => !ed.items.some(i => i.type === "folder" && i.path === p))
            }
            delegate: Pill {
                required property string modelData
                text: modelData
                fontSize: 11
                onClicked: ed.add({ type: "folder", desktop_id: "", path: modelData })
            }
        }
    }
    // Programme: durchsuchbar
    Field {
        id: search
        width: parent.width
        placeholder: "Search apps to add…"
        commitOnBlur: false
    }
    Column {
        width: parent.width
        spacing: Theme.pad(2)
        Repeater {
            model: {
                const q = search.input.text.trim().toLowerCase()
                if (q === "") return []
                return DesktopEntries.applications.values
                    .filter(e => !e.noDisplay && (String(e.name).toLowerCase().indexOf(q) >= 0 || String(e.id).toLowerCase().indexOf(q) >= 0))
                    .filter(e => !ed.items.some(i => i.type === "app" && i.desktop_id === e.id))
                    .slice(0, 8)
            }
            delegate: Rectangle {
                required property var modelData
                width: parent ? parent.width : 0
                height: 34
                radius: 10
                color: appHover.hovered ? Theme.cardHover : "transparent"
                HoverHandler { id: appHover }
                Row {
                    anchors { left: parent.left; leftMargin: Theme.pad(10); verticalCenter: parent.verticalCenter }
                    spacing: Theme.pad(10)
                    AppIcon { anchors.verticalCenter: parent.verticalCenter; icon: modelData.icon; size: 20 }
                    Txt { anchors.verticalCenter: parent.verticalCenter; text: modelData.name; size: 13 }
                }
                TapHandler { onTapped: { ed.add({ type: "app", desktop_id: modelData.id, path: "" }); search.input.text = "" } }
            }
        }
    }
}
