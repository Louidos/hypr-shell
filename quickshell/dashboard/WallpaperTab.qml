import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../common"

// Tab Wallpaper: Vorschaukarten aller Bilder in ~/Pictures/Wallpapers, Suchfeld,
// Klick setzt das Bild mit shell-wallpaper (Farben ändern sich überall mit).
Item {
    id: wt
    signal closeRequested()
    property string current: ""
    readonly property string folder: Settings.home + "/Pictures/Wallpapers"
    readonly property var exts: ["jpg", "jpeg", "png", "webp", "bmp", "gif"]

    FileView {
        path: Settings.home + "/.local/share/hypr-shell/wallpaper"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: wt.current = text().trim()
    }

    GlassCard {
        id: search
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 40
        radius: 20
        Glyph { id: lens; anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter } text: ""; size: 13; color: Theme.subtext }
        TextInput {
            id: input
            anchors { left: lens.right; leftMargin: 10; right: count.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            color: Theme.text
            font.family: Theme.sans
            font.pixelSize: 13 * Theme.fontScale
            clip: true
            selectByMouse: true
            Keys.onEscapePressed: text.length > 0 ? text = "" : wt.closeRequested()
            Txt { visible: input.text.length === 0; text: "Search wallpapers"; sub: true; size: 13 }
        }
        Txt { id: count; anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } text: files.count + (files.count === 1 ? " image" : " images"); sub: true; size: 11 }
    }

    FolderListModel {
        id: files
        folder: "file://" + wt.folder
        showDirs: false
        caseSensitive: false
        sortField: FolderListModel.Name
        nameFilters: wt.exts.map(e => "*" + input.text + "*." + e)
    }

    GridView {
        id: view
        anchors { top: search.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        cellWidth: width / 3
        cellHeight: cellWidth * 0.6
        model: files
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: cardItem
            required property string filePath
            required property string fileBaseName
            required property int index
            width: view.cellWidth
            height: view.cellHeight
            readonly property bool isCurrent: filePath === wt.current
            RoundImage {
                id: thumb
                anchors { fill: parent; margins: 6 }
                radius: 14
                source: "file://" + cardItem.filePath
                sourceWidth: 480
                fallbackText: ""
                probe: cardItem.index === 0 ? "wallpaper-card" : ""
            }
            Rectangle {
                anchors.fill: thumb
                radius: 14
                color: "transparent"
                border.width: cardItem.isCurrent ? 2 : (hover.hovered ? 1 : 0)
                border.color: cardItem.isCurrent ? Theme.pill : Qt.rgba(1, 1, 1, 0.4)
            }
            Rectangle {
                visible: cardItem.isCurrent
                anchors { top: thumb.top; right: thumb.right; margins: 8 }
                width: 24; height: 24; radius: 12
                color: Theme.pill
                Glyph { anchors.centerIn: parent; text: ""; size: 11; color: Theme.pillText }
            }
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    wt.current = cardItem.filePath
                    Quickshell.execDetached([Settings.home + "/.local/bin/shell-wallpaper", cardItem.filePath])
                }
            }
        }
        Txt {
            anchors.centerIn: parent
            visible: files.count === 0
            text: input.text.length > 0 ? "No match" : "No images in ~/Pictures/Wallpapers"
            sub: true
        }
    }

    Component.onCompleted: input.forceActiveFocus()
}
