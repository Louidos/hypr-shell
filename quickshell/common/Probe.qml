import QtQuick
import Quickshell

// Nur im Oberflächentest (Umgebungsvariable HYPR_SHELL_TEST=1): schreibt die Lage des
// Elternelements auf dem Bildschirm ins Log ("hypr-shell-probe NAME X Y BREITE HÖHE"), damit
// tests/oberflaeche.sh genau diesen Ausschnitt im Screenshot prüfen kann. Sonst tut es nichts.
Item {
    id: p
    property string name: ""
    readonly property bool aktiv: name !== "" && Quickshell.env("HYPR_SHELL_TEST") === "1"
    readonly property var win: aktiv ? QsWindow.window : null

    function melde() {
        const it = p.parent, w = p.win
        if (!it || !w || !w.screen || !it.visible || it.width < 4 || it.height < 4) return
        const g = it.mapToItem(null, 0, 0)
        const sw = w.screen.width, sh = w.screen.height
        const a = w.anchors, m = w.margins
        const wx = a.left ? m.left : a.right ? sw - w.width - m.right : (sw - w.width) / 2
        const wy = a.top ? m.top : a.bottom ? sh - w.height - m.bottom : (sh - w.height) / 2
        console.log("hypr-shell-probe " + p.name + " " + Math.round(wx + g.x) + " " + Math.round(wy + g.y)
                    + " " + Math.round(it.width) + " " + Math.round(it.height))
    }
    Timer {
        running: p.aktiv
        interval: 700
        repeat: true
        onTriggered: p.melde()
    }
}
