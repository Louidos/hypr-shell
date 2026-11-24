import QtQuick
import Quickshell
import "fit.js" as F

// Grössen-Hilfe für ein Fenster auf einem Bildschirm (jedes Fenster hat seine eigene, so rechnet
// bei mehreren Bildschirmen jedes mit seinem). Alle Werte sind logische Pixel nach der Skalierung
// von Hyprland (so meldet Quickshell die Bildschirme); ändern sich Auflösung, Skalierung oder
// Drehung, rechnen alle Bindungen von selbst neu.
//
//   ScreenFit { id: fit; screen: win.screen }
//   width: fit.fit(420, 280, fit.availWidth - 24)
//
//   width, height          ganzer Bildschirm
//   top/bottom/left/right  von Leiste (bar.position, bar.height) und einem Dock mit
//                          dock.mode = reserve belegter Rand (forPanel und dock.when_panel_open =
//                          hide: ohne Dock)
//   availWidth/availHeight Platz ohne Leiste und reserviertes Dock
//   portrait               Hochformat (höher als breit)
//   factor                 Grössenfaktor der Oberfläche: 1 zwischen 1080 und 1440 Pixeln kürzerer
//                          Seite, darunter bis 0.85 kleiner, darüber bis 2 grösser (4K mit
//                          Skalierung 1 sieht so nicht winzig aus)
//   fit(wunsch, min, max)  Wunschwert × factor, nie unter min und nie über max (max gewinnt)
QtObject {
    id: f
    property var screen: null
    // für ein Panel (Overlay): fährt das Dock für Panels weg (dock.when_panel_open = hide), zählt
    // sein reservierter Platz nicht – das Panel bekommt die volle Höhe
    property bool forPanel: false
    // ohne Bildschirm: der erste, den es gibt, sonst die kleinste unterstützte Grösse 1280×720
    readonly property var target: screen ? screen : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    readonly property string name: target ? target.name : ""
    readonly property real width: target && target.width > 0 ? target.width : 1280
    readonly property real height: target && target.height > 0 ? target.height : 720
    readonly property bool portrait: height > width

    // Leiste (Waybar auf jedem Bildschirm) und ein Dock, das Platz reserviert
    readonly property var rand: F.rand({
        barPosition: Settings.get("bar.position", "top"),
        barHeight: Settings.get("bar.height", 30),
        dockEnabled: Settings.get("dock.enabled", true),
        dockMode: Settings.get("dock.mode", "floating"),
        dockPosition: Settings.get("dock.position", "bottom"),
        dockMonitor: Settings.get("dock.monitor", "all"),
        dockMargin: Settings.get("dock.margin", 10),
        dockIcon: Settings.get("dock.icon_size", 48),
        dockPadding: Settings.get("dock.padding", 8),
        dockGivesWay: forPanel && Settings.get("dock.when_panel_open", "hide") === "hide",
        screenName: name,
        firstScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "",
        factor: factor
    })
    readonly property real top: rand.top
    readonly property real bottom: rand.bottom
    readonly property real left: rand.left
    readonly property real right: rand.right
    readonly property real availWidth: Math.max(1, width - left - right)
    readonly property real availHeight: Math.max(1, height - top - bottom)

    readonly property real factor: F.faktor(width, height)
    function fit(want, min, max) { return F.fit(want, factor, min, max) }
}
