import QtQuick
import Quickshell
import "../common"

// Tab Games: zuletzt gespielte Steam-Spiele mit Cover und eigene Einträge (GOG, Battle.net …).
// Klick startet das Spiel (shell-games launch) und schliesst das Dashboard.
Item {
    id: gt
    property var games: []
    signal closeRequested()

    Flickable {
        anchors.fill: parent
        contentWidth: row.implicitWidth
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        Row {
            id: row
            spacing: 14
            Repeater {
                model: gt.games
                delegate: Item {
                    id: g
                    required property var modelData
                    required property int index
                    // Cover im Seitenverhältnis 2:3 (196 px bei der üblichen Höhe)
                    width: Math.round((gt.height - 34) * 0.662)
                    height: gt.height
                    Rectangle {
                        id: frame
                        width: parent.width
                        height: parent.height - 34
                        radius: Theme.cardRadius
                        color: Theme.card
                        border.width: 1
                        border.color: hov.hovered ? Theme.text : Theme.cardBorder
                        clip: true
                        RoundImage {
                            anchors.fill: parent
                            radius: Theme.cardRadius
                            source: g.modelData.cover !== "" ? "file://" + g.modelData.cover : ""
                            probe: g.index === 0 ? "games-cover" : ""
                        }
                        Column {
                            anchors.centerIn: parent
                            visible: g.modelData.cover === ""
                            spacing: 8
                            Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: "󰊗"; size: 40; color: Theme.subtext }
                        }
                        Rectangle {
                            anchors { right: parent.right; top: parent.top; margins: 8 }
                            width: 26; height: 26; radius: 13
                            color: Qt.rgba(0, 0, 0, 0.45)
                            Glyph { anchors.centerIn: parent; text: g.modelData.source === "steam" ? "󰓓" : "󰊴"; size: 13 }
                        }
                        scale: hov.hovered ? 1.02 : 1
                        Behavior on scale { NumberAnimation { duration: 140 } }
                    }
                    Txt {
                        anchors { top: frame.bottom; topMargin: 8; left: parent.left; right: parent.right }
                        horizontalAlignment: Text.AlignHCenter
                        text: g.modelData.name
                        size: 12
                        weight: Font.DemiBold
                    }
                    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached([Settings.bin + "shell-games", "launch", g.modelData.id])
                            gt.closeRequested()
                        }
                    }
                }
            }
        }
    }
}
