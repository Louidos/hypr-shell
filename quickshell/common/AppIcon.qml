import QtQuick
import Quickshell

// Symbol einer App aus ihrer .desktop-Datei. Reihenfolge: Papirus-Dark (Symbolthema der
// Oberfläche, über die Vererbung danach hicolor), ein Pfad aus der .desktop-Datei bzw.
// /usr/share/pixmaps, erst danach der Platzhalter.
Item {
    id: ai
    property string icon: ""
    property real size: 32
    property string probe: ""
    property int versuch: 0
    readonly property var quellen: {
        const n = (icon || "").trim()
        if (n === "") return []
        if (n.indexOf("file://") === 0) return [n]
        if (n.indexOf("/") === 0) return ["file://" + n]
        const l = []
        const t = Quickshell.iconPath(n, true)
        if (t !== "") l.push(t)
        l.push("file:///usr/share/pixmaps/" + n + ".png", "file:///usr/share/pixmaps/" + n + ".svg")
        return l
    }
    readonly property bool ready: img.status === Image.Ready
    onQuellenChanged: versuch = 0
    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: ai.versuch < ai.quellen.length ? ai.quellen[ai.versuch] : ""
        sourceSize.width: Math.ceil(ai.size * 2)
        sourceSize.height: Math.ceil(ai.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
        visible: ai.ready
        onStatusChanged: if (status === Image.Error) ai.versuch++
        Probe { name: ai.probe }
    }
    Glyph {
        anchors.centerIn: parent
        visible: !ai.ready
        text: "󰀻"
        size: ai.size * 0.85
        color: Theme.subtext
    }
}
