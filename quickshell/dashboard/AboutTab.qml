import QtQuick
import "../common"

// Tab About: System, Distribution, Version dieses Projekts.
Grid12 {
    id: ab
    property var about: ({})
    rows: 2
    narrowRows: 4

    function uptime(s) {
        s = Math.floor(s || 0)
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return (d ? d + "d " : "") + (h ? h + "h " : "") + m + "m"
    }

    component Line: Row {
        id: line
        property string key
        property string value
        width: parent ? parent.width : 300
        spacing: 10
        Txt { width: 92; text: line.key; sub: true; size: 13 }
        Txt { width: line.width - 102; text: line.value || "–"; size: 13; weight: Font.DemiBold }
    }

    Cell {
        col: 0; row: 0; cs: 5; rs: 2
        narrowAt: [0, 0, 6, 2]
        Column {
            anchors { fill: parent; margins: 20 }
            spacing: 12
            Txt { text: "System"; size: 16; weight: Font.Bold }
            Line { key: "User"; value: ab.about.user }
            Line { key: "Host"; value: ab.about.host }
            Line { key: "Kernel"; value: ab.about.kernel }
            Line { key: "CPU"; value: ab.about.cpu }
            Line { key: "Memory"; value: ab.about.memTotal ? (ab.about.memTotal / 1073741824).toFixed(1) + " GiB" : "" }
            Line { key: "Uptime"; value: ab.uptime(ab.about.uptime) }
        }
    }
    Cell {
        col: 5; row: 0; cs: 3; rs: 2
        narrowAt: [0, 2, 3, 2]
        Column {
            anchors.centerIn: parent
            spacing: 12
            Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: ab.about.icon || ""; size: 72 }
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: ab.about.distro || "Linux"; size: 18; weight: Font.Bold }
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Distribution"; sub: true; size: 12 }
        }
    }
    Cell {
        col: 8; row: 0; cs: 4; rs: 2
        narrowAt: [3, 2, 3, 2]
        Column {
            anchors { fill: parent; margins: 20 }
            spacing: 12
            Txt { text: "hypr-shell"; size: 16; weight: Font.Bold }
            Txt { text: "Glass desktop for Hyprland"; sub: true; size: 12 }
            Item { width: 1; height: 4 }
            Line { key: "Version"; value: ab.about.version }
            Line { key: "Hyprland"; value: ab.about.hyprland }
            Line { key: "Quickshell"; value: ab.about.quickshell }
        }
    }
}
