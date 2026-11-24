import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../common"

// Unterseite Ton im Panel: Ausgabe- und Eingabegerät wählen (wirkt sofort), Lautstärke je App.
// Direkt über PipeWire (Quickshell.Services.Pipewire), ohne Hilfsprogramm.
Column {
    id: ap
    property var panel
    spacing: Theme.pad(6)
    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => n.audio && !n.isSink && !n.isStream && (n.name || "").indexOf(".monitor") < 0)
    readonly property var streams: nodes.filter(n => n.audio && n.isStream && !n.isSink)

    PwObjectTracker { objects: ap.sinks.concat(ap.sources, ap.streams) }

    component Device: GlassCard {
        id: d
        property var node
        property bool chosen: false
        signal pick()
        width: ap.width
        height: 42
        hoverable: true
        Glyph {
            id: mark
            anchors { left: parent.left; leftMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
            text: d.chosen ? "󰄬" : ""
            size: 13
        }
        Txt {
            anchors { left: mark.right; leftMargin: Theme.pad(10); right: parent.right; rightMargin: Theme.pad(12); verticalCenter: parent.verticalCenter }
            text: d.node ? (d.node.description || d.node.nickname || d.node.name) : ""
            size: 12
            weight: d.chosen ? Theme.titleWeight : Theme.textWeight
        }
        TapHandler { onTapped: d.pick() }
    }

    component Level: Item {
        id: lv
        property var node
        property string label: ""
        property string icon: ""
        width: ap.width
        height: 40
        readonly property real vol: node && node.audio ? node.audio.volume : 0
        Glyph { id: li; anchors { left: parent.left; leftMargin: Theme.pad(6); verticalCenter: parent.verticalCenter } text: lv.icon; size: 14 }
        Txt { id: lt; anchors { left: li.right; leftMargin: Theme.pad(10); verticalCenter: parent.verticalCenter } width: 110; text: lv.label; size: 12 }
        Rectangle {
            id: track
            anchors { left: lt.right; leftMargin: Theme.pad(8); right: parent.right; rightMargin: Theme.pad(44); verticalCenter: parent.verticalCenter }
            height: 6
            radius: Theme.corner(3)
            color: Theme.track
            Rectangle { width: parent.width * Math.min(1, lv.vol); height: parent.height; radius: Theme.corner(3); color: Theme.pill }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                function setAt(x) { if (lv.node && lv.node.audio) lv.node.audio.volume = Math.max(0, Math.min(1, x / track.width)) }
                onPressed: mouse => setAt(mouse.x - 10)
                onPositionChanged: mouse => { if (pressed) setAt(mouse.x - 10) }
            }
        }
        Txt { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: Math.round(lv.vol * 100) + "%"; size: 11; sub: true }
    }

    Txt { text: "Output"; size: 12; strong: true; sub: true }
    Txt { visible: ap.sinks.length === 0; text: "No output devices"; size: 12; sub: true }
    Repeater {
        model: ap.sinks
        delegate: Device {
            required property var modelData
            node: modelData
            chosen: Pipewire.defaultAudioSink === modelData
            onPick: Pipewire.preferredDefaultAudioSink = modelData
        }
    }
    Level { visible: Pipewire.defaultAudioSink !== null; node: Pipewire.defaultAudioSink; label: "Volume"; icon: "󰕾" }

    Txt { text: "Input"; size: 12; strong: true; sub: true }
    Txt { visible: ap.sources.length === 0; text: "No input devices"; size: 12; sub: true }
    Repeater {
        model: ap.sources
        delegate: Device {
            required property var modelData
            node: modelData
            chosen: Pipewire.defaultAudioSource === modelData
            onPick: Pipewire.preferredDefaultAudioSource = modelData
        }
    }

    Txt { visible: ap.streams.length > 0; text: "Apps"; size: 12; strong: true; sub: true }
    Repeater {
        model: ap.streams
        delegate: Level {
            required property var modelData
            node: modelData
            label: modelData.properties["application.name"] || modelData.description || modelData.name
            icon: "󰎈"
        }
    }
}
