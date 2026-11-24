import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../common"

// Eine Benachrichtigung als Glas-Karte: Symbol oder Bild, App und Zeit, Titel, Text, Knöpfe.
// popup = true: Karte oben rechts, verschwindet nach timeout Sekunden (nicht bei dringenden;
// solange die Maus darauf ist, wartet sie). Im Verlauf (popup = false) als Zeile ohne Zeitablauf.
GlassPanel {
    id: card
    property var info: ({})
    property var center
    property bool popup: false
    property int timeout: 6
    readonly property bool critical: info.critical === true
    radius: popup ? 20 : Theme.cardRadius
    color: popup ? Theme.glass(Math.min(0.95, Theme.glassOpacity + 0.18)) : Theme.card
    border.color: critical ? Theme.warn : (popup ? Theme.glassBorder : Theme.cardBorder)
    height: col.implicitHeight + 24

    function since(d) {
        if (!d) return ""
        const s = Math.max(0, Math.round((Date.now() - d.getTime()) / 1000))
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + " min" : Qt.formatTime(d, "HH:mm")
    }

    // einfahren von rechts
    transform: Translate { id: shift; x: card.popup ? card.width + 20 : 0 }
    Component.onCompleted: if (popup) slideIn.start()
    NumberAnimation { id: slideIn; target: shift; property: "x"; to: 0; duration: 380; easing.type: Easing.OutQuint }

    Timer {
        running: card.popup && !card.critical && card.timeout > 0 && !hov.hovered
        interval: card.timeout * 1000
        onTriggered: card.center.hidePopup(card.info.nid)
    }
    HoverHandler { id: hov }
    TapHandler {
        onTapped: {
            if (card.popup) card.center.invoke(card.info.nid, "default")
        }
    }

    Column {
        id: col
        x: 14; y: 12
        width: parent.width - 28
        spacing: Theme.pad(6)

        Item {
            width: parent.width
            height: 40
            Item {
                id: ico
                width: 36; height: 36
                anchors.verticalCenter: parent.verticalCenter
                RoundImage {
                    id: img
                    anchors.fill: parent
                    radius: Theme.corner(10)
                    visible: (card.info.image || "") !== ""
                    source: card.info.image || ""
                }
                AppIcon {
                    anchors.fill: parent
                    visible: !img.visible
                    size: 36
                    icon: card.info.icon || ""
                }
            }
            Column {
                anchors { left: ico.right; leftMargin: Theme.pad(12); right: close.left; rightMargin: Theme.pad(8); verticalCenter: parent.verticalCenter }
                spacing: Theme.pad(1)
                Txt {
                    width: parent.width
                    text: (card.info.app || "") + "  ·  " + card.since(card.info.time)
                    size: 11
                    sub: true
                }
                Txt {
                    width: parent.width
                    text: card.info.summary || ""
                    size: 14
                    strong: true
                }
            }
            IconButton {
                id: close
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 26; height: 26
                flat: true
                iconSize: 11
                icon: "󰅖"
                onClicked: card.popup ? card.center.hidePopup(card.info.nid) : card.center.remove(card.info.nid)
            }
        }
        Txt {
            width: parent.width
            visible: text !== ""
            text: card.info.body || ""
            size: 12
            sub: true
            wrapMode: Text.Wrap
            maximumLineCount: card.popup ? 4 : 3
            elide: Text.ElideRight
        }
        Flow {
            width: parent.width
            visible: (card.info.actions || []).length > 0
            spacing: Theme.pad(6)
            Repeater {
                model: card.info.actions || []
                delegate: Pill {
                    required property var modelData
                    implicitHeight: 28
                    fontSize: 11
                    text: modelData.text
                    onClicked: card.center.invoke(card.info.nid, modelData.id)
                }
            }
        }
    }
}
