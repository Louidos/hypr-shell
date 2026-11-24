import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Dashboard: Glas-Panel, das unten in der Mitte hochgleitet (gemeinsamer Baustein Overlay).
// Öffnen: SUPER+ALT+D oder SUPER+D, Maus an die Mitte der unteren Kante, SUPER+W (Tab Wallpaper).
// Schliessen: Esc, Klick daneben oder Maus verlässt das Panel; öffnet ein anderes Panel, schliesst es.
// Systemwerte werden nur abgefragt, solange das Panel offen ist (der Inhalt wird erst dann geladen).
Scope {
    id: dash
    readonly property bool open: ov.open
    property string tab: "dashboard"
    property var about: ({})
    // Tabs, Reihenfolge und Start-Tab aus settings.json (dashboard.tabs, dashboard.start)
    readonly property var allTabs: ["dashboard", "wallpaper", "performance", "games", "lab", "about"]
    // Spiele (shell-games list, beim Öffnen gelesen); ohne Spiele bleibt der Tab Games weg
    property var games: []
    readonly property var tabs: {
        const l = Settings.get("dashboard.tabs", allTabs).filter(t => allTabs.indexOf(t) >= 0 && (t !== "games" || games.length > 0) && (t !== "lab" || Integrations.lab))
        return l.length > 0 ? l : ["dashboard"]
    }
    readonly property string startTab: {
        const t = Settings.get("dashboard.start", "dashboard")
        return tabs.indexOf(t) >= 0 ? t : tabs[0]
    }
    readonly property var tabNames: ({ dashboard: "Dashboard", wallpaper: "Wallpaper", performance: "Performance", games: "Games", lab: "Lab", about: "About" })
    readonly property var tabIcons: ({ dashboard: "󰕮", wallpaper: "󰋩", performance: "󰓅", games: "󰊗", lab: "󰒋", about: "󰋽" })
    readonly property var screen: Settings.screenFor(Settings.get("desktop.screen", ""))
    // Breite aus dashboard.width; Overlay begrenzt sie auf den Bildschirm (mit Grössenfaktor)
    readonly property real panelW: Settings.get("dashboard.width", 1000)
    // Hochformat oder schmal: Karten in 6 statt 12 Spalten, dafür höher (Overlay rollt, wenn nötig)
    readonly property bool narrow: ov.portrait || ov.fitWidth < 760
    // wie die Vorlage: Kopf 64 px (Tab-Leiste), Inhalt 330 px (schmal 5 Zeilen: 555 px), Rand theme.spacing.panel
    readonly property real headH: 64
    readonly property real pad: Theme.panelPad
    readonly property real pageH: narrow ? 555 : 330
    readonly property real panelH: headH + 4 + pageH + pad

    property string wantTab: ""
    function show(t) {
        wantTab = t || ""
        tab = tabs.indexOf(t) >= 0 ? t : startTab
        ov.show()
    }
    function hide() { ov.hide() }

    IpcHandler {
        target: "dashboard"
        function open(tab: string): void { dash.show(tab) }
        function toggle(): void { if (dash.open) dash.hide(); else dash.show("") }
        function close(): void { dash.hide() }
    }

    Process {
        id: gamesProc
        command: [Settings.home + "/.local/bin/shell-games", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { dash.games = JSON.parse(text) } catch (e) { dash.games = [] }
                // "ipc dashboard open games": der Tab gibt es erst, wenn die Spiele gelesen sind
                if (dash.wantTab === "games" && dash.games.length > 0) dash.tab = "games"
            }
        }
    }
    Process {
        id: aboutProc
        command: [Settings.home + "/.local/bin/shell-sysinfo", "about"]
        stdout: StdioCollector { onStreamFinished: { try { dash.about = JSON.parse(text) } catch (e) { } } }
    }

    // Auslösestreifen an der Mitte der unteren Kante (unter Vollbild-Fenstern, stört also keine Spiele)
    PanelWindow {
        screen: dash.screen
        // liegt dort ein verstecktes Dock, blendet die Kante das Dock ein (siehe docs/dock.md)
        visible: Settings.get("dashboard.edge", true) && !dash.open && dash.screen !== null && !Ui.dockOwnsEdge
        anchors { bottom: true }
        implicitWidth: 320
        implicitHeight: 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hypr-shell-edge"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: edgeTimer.restart()
            onExited: edgeTimer.stop()
        }
        Timer { id: edgeTimer; interval: 150; onTriggered: dash.show("") }
    }

    Overlay {
        id: ov
        name: "dashboard"
        ipc: false
        place: "bottom"
        screen: dash.screen
        panelWidth: dash.panelW
        panelHeight: dash.panelH
        glassOpacity: Settings.get("dashboard.opacity", -1)   // -1 = gemeinsames Glas
        keyboardFocus: WlrKeyboardFocus.Exclusive
        leaveDelay: Settings.get("dashboard.close_on_leave", true) ? 350 : -1
        // von aussen geöffnet (z. B. Ui.openPanel): Start-Tab; Daten für About und Profil holen
        onOpened: { if (dash.tabs.indexOf(dash.tab) < 0) dash.tab = dash.startTab; if (!aboutProc.running) aboutProc.running = true; if (!gamesProc.running) gamesProc.running = true }

        content: Component {
            Item {
                id: keys
                focus: true
                Keys.onTabPressed: dash.tab = dash.tabs[(dash.tabs.indexOf(dash.tab) + 1) % dash.tabs.length]

                // Tab-Leiste: gleich breite Tabs über die ganze Breite, Symbol über dem Text,
                // der aktive Tab als weisse Pille, die zum gewählten Tab gleitet
                Item {
                    id: tabBar
                    x: dash.pad
                    y: 10
                    width: parent.width - 2 * dash.pad
                    height: dash.headH - 14
                    readonly property int cur: Math.max(0, dash.tabs.indexOf(dash.tab))
                    readonly property real tw: width / dash.tabs.length
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.card
                    }
                    Rectangle {
                        x: tabBar.cur * tabBar.tw + 4
                        y: 4
                        width: tabBar.tw - 8
                        height: tabBar.height - 8
                        radius: height / 2
                        color: Theme.pill
                        Behavior on x { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
                    }
                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: dash.tabs
                            delegate: Item {
                                id: tb
                                required property string modelData
                                required property int index
                                readonly property bool active: tabBar.cur === index
                                width: tabBar.tw
                                height: tabBar.height
                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.pad(1)
                                    Glyph {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: dash.tabIcons[tb.modelData]
                                        size: 18
                                        color: tb.active ? Theme.pillText : Theme.subtext
                                        Behavior on color { ColorAnimation { duration: 220 } }
                                    }
                                    Txt {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: tabBar.tw >= 64
                                        text: dash.tabNames[tb.modelData]
                                        size: 12
                                        strong: tb.active
                                        color: tb.active ? Theme.pillText : Theme.subtext
                                        Behavior on color { ColorAnimation { duration: 220 } }
                                    }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: dash.tab = tb.modelData }
                            }
                        }
                    }
                }

                // die Seite des gewählten Tabs (wird mit dem Panel geladen und wieder entladen)
                Loader {
                    id: page
                    x: dash.pad
                    y: dash.headH + 4
                    width: parent.width - 2 * dash.pad
                    height: dash.pageH
                    sourceComponent: dash.tab === "wallpaper" ? wallTab
                                   : dash.tab === "performance" ? perfTab
                                   : dash.tab === "games" ? gamesTab
                                   : dash.tab === "lab" ? labTab
                                   : dash.tab === "about" ? aboutTab : homeTab
                }
            }
        }
    }

    Component { id: homeTab; HomeTab { about: dash.about; narrow: dash.narrow } }
    Component { id: perfTab; PerfTab { narrow: dash.narrow } }
    Component { id: labTab; LabTab { } }
    Component { id: gamesTab; GamesTab { games: dash.games; onCloseRequested: dash.hide() } }
    Component { id: wallTab; WallpaperTab { onCloseRequested: dash.hide() } }
    Component { id: aboutTab; AboutTab { about: dash.about; narrow: dash.narrow } }
}
