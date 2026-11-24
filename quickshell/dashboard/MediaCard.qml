import QtQuick
import Quickshell.Services.Mpris
import "../common"

// Musik: Cover, Titel, Interpret, zurück / Play / weiter (MPRIS, z. B. Spotify, Firefox).
Item {
    id: m
    readonly property var players: Mpris.players.values
    readonly property var player: {
        for (let i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i]
        return players.length > 0 ? players[0] : null
    }

    RoundImage {
        id: cover
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        width: Math.min(parent.width, parent.height - 110)
        height: width
        radius: 14
        source: m.player ? m.player.trackArtUrl : ""
        sourceWidth: 400
        Glyph {
            anchors.centerIn: parent
            visible: !cover.ready
            text: "󰝚"
            size: cover.height * 0.32
            color: Theme.subtext
        }
    }
    Column {
        anchors { top: cover.bottom; topMargin: Theme.pad(12); left: parent.left; right: parent.right }
        spacing: Theme.pad(2)
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: m.player && m.player.trackTitle ? m.player.trackTitle : "Nothing playing"
            size: 14
            title: true
        }
        Txt {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: m.player ? (m.player.trackArtist || m.player.identity || "") : ""
            sub: true
            size: 12
        }
    }
    Row {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        spacing: Theme.pad(10)
        IconButton { icon: "󰒮"; flat: true; onClicked: if (m.player && m.player.canGoPrevious) m.player.previous() }
        IconButton {
            icon: m.player && m.player.isPlaying ? "󰏤" : "󰐊"
            active: true
            onClicked: if (m.player && m.player.canTogglePlaying) m.player.togglePlaying()
        }
        IconButton { icon: "󰒭"; flat: true; onClicked: if (m.player && m.player.canGoNext) m.player.next() }
    }
}
