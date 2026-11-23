import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Dashboard: Glas-Panel, das unten in der Mitte hochgleitet.
// Öffnen: SUPER+ALT+D, Maus an die Mitte der unteren Kante, SUPER+W (Tab Wallpaper).
// Schliessen: Esc oder Maus verlässt das Panel.
// Systemwerte werden nur abgefragt, solange das Panel offen ist (die Tabs werden erst dann geladen).
Scope {
    id: dash
    property bool open: false
    property string tab: "dashboard"
    property bool entered: false
    property var about: ({})
    readonly property var tabs: ["dashboard", "wallpaper", "performance", "about"]
    readonly property var tabNames: ({ dashboard: "Dashboard", wallpaper: "Wallpaper", performance: "Performance", about: "About" })
    readonly property var tabIcons: ({ dashboard: "󰕭", wallpaper: "󰋩", performance: "󰃘", about: "󰋼" })
    readonly property var screen: Settings.screenFor(Settings.get("desktop.screen", ""))
    readonly property real panelW: Math.min(Settings.get("dashboard.width", 1000), (screen ? screen.width : 1920) - 40)
    readonly property real panelH: 440

    function show(t) {
        if (tabs.indexOf(t) >= 0) tab = t
        entered = false
        if (!aboutProc.running) aboutProc.running = true
        open = true
    }
    function hide() { open = false }

    IpcHandler {
        target: "dashboard"
        function open(tab: string): void { dash.show(tab) }
        function toggle(): void { if (dash.open) dash.hide(); else dash.show("") }
        function close(): void { dash.hide() }
    }

    Process {
        id: aboutProc
        command: [Settings.home + "/.local/bin/shell-sysinfo", "about"]
        stdout: StdioCollector { onStreamFinished: { try { dash.about = JSON.parse(text) } catch (e) { } } }
    }

    // Auslösestreifen an der Mitte der unteren Kante (unter Vollbild-Fenstern, stört also keine Spiele)
    PanelWindow {
        screen: dash.screen
        visible: Settings.get("dashboard.edge", true) && !dash.open && dash.screen !== null
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

    PanelWindow {
        id: win
        property real t: dash.open ? 1 : 0
        Behavior on t {
            NumberAnimation { duration: dash.open ? 460 : 280; easing.type: dash.open ? Easing.OutQuint : Easing.InCubic }
        }

        screen: dash.screen
        visible: dash.screen !== null && (dash.open || t > 0.001)
        anchors { bottom: true }
        implicitWidth: dash.panelW
        implicitHeight: dash.panelH + 12
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "hypr-shell-dashboard"
        WlrLayershell.keyboardFocus: dash.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region { item: body }

        onVisibleChanged: if (visible) keys.forceActiveFocus()

        GlassPanel {
            id: body
            width: parent.width
            height: dash.panelH
            y: (1 - win.t) * (dash.panelH + 24)
            opacity: Math.min(1, win.t * 2)
            glassOpacity: Settings.get("dashboard.opacity", 0.42)

            HoverHandler {
                id: hov
                onHoveredChanged: {
                    if (hovered) { dash.entered = true; leaveTimer.stop() }
                    else if (dash.open && dash.entered) leaveTimer.restart()
                }
            }
            Timer { id: leaveTimer; interval: 350; onTriggered: if (!hov.hovered) dash.hide() }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: dash.hide()
                Keys.onTabPressed: dash.tab = dash.tabs[(dash.tabs.indexOf(dash.tab) + 1) % dash.tabs.length]
            }

            // Tab-Leiste: aktiver Tab als weisse Pille
            Row {
                id: tabBar
                anchors { top: parent.top; topMargin: 16; horizontalCenter: parent.horizontalCenter }
                spacing: 6
                Repeater {
                    model: dash.tabs
                    delegate: Pill {
                        required property string modelData
                        text: dash.tabNames[modelData]
                        icon: dash.tabIcons[modelData]
                        active: dash.tab === modelData
                        implicitHeight: 32
                        onClicked: dash.tab = modelData
                    }
                }
            }

            Loader {
                id: page
                anchors { top: tabBar.bottom; topMargin: 16; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 18 }
                active: dash.open || win.t > 0.001
                sourceComponent: dash.tab === "wallpaper" ? wallTab
                               : dash.tab === "performance" ? perfTab
                               : dash.tab === "about" ? aboutTab : homeTab
            }
        }
    }

    Component { id: homeTab; HomeTab { about: dash.about } }
    Component { id: perfTab; PerfTab { } }
    Component { id: wallTab; WallpaperTab { onCloseRequested: dash.hide() } }
    Component { id: aboutTab; AboutTab { about: dash.about } }
}
