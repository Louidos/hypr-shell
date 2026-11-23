import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../common"

// Benachrichtigungsdienst von hypr-shell (ersetzt swaync): läuft immer im Hintergrund.
// - Karten oben rechts (Symbol, Titel, Text, Knöpfe); sie verschwinden nach notifications.timeout
//   Sekunden, dringende bleiben, bis man sie schliesst.
// - Verlauf im Panel (SUPER+N oder Glocke in der Leiste): nach App gruppiert, einzeln oder alle löschen,
//   Schalter Nicht stören. Mit Nicht stören erscheinen keine Karten, der Verlauf füllt sich trotzdem.
// - Nicht stören steht in ~/.local/share/hypr-shell/dnd ("true"/"false", auch shell-toggle dnd).
// - Für die Leiste: ~/.local/share/hypr-shell/notifications-bar.json (Glocke mit Zähler).
Scope {
    id: nc
    property var history: []          // neueste zuerst: { nid, app, icon, image, summary, body, time, urgency, actions, n }
    property var popups: []           // nid der sichtbaren Karten
    property bool dnd: false
    property int seq: 0
    readonly property int timeout: Settings.get("notifications.timeout", 6)
    readonly property int keep: Settings.get("notifications.history", 100)
    readonly property bool enabled: Settings.get("notifications.enabled", true)

    function entry(nid) { return history.find(e => e.nid === nid) }
    function add(n) {
        n.tracked = true
        const e = {
            nid: ++seq, n: n, app: n.appName || "Notification", icon: n.appIcon || "", image: n.image || "",
            summary: n.summary || "", body: n.body || "", time: new Date(),
            urgency: n.urgency, critical: n.urgency === NotificationUrgency.Critical,
            actions: (n.actions || []).filter(a => a.identifier !== "default").map(a => ({ id: a.identifier, text: a.text }))
        }
        const h = [e].concat(history)
        if (h.length > keep) h.length = keep
        history = h
        if (!dnd) showPopup(e)
        n.closed.connect(() => { const x = nc.entry(e.nid); if (x) x.n = null; nc.hidePopup(e.nid) })
        writeBar()
    }
    function showPopup(e) {
        const p = popups.filter(x => x !== e.nid)
        p.unshift(e.nid)
        if (p.length > 5) p.length = 5
        popups = p
    }
    function hidePopup(nid) { popups = popups.filter(x => x !== nid) }
    function remove(nid) {
        const e = entry(nid)
        if (e && e.n) { try { e.n.dismiss() } catch (err) { } }
        history = history.filter(x => x.nid !== nid)
        hidePopup(nid)
        writeBar()
    }
    function clearApp(app) { history.filter(x => x.app === app).forEach(x => remove(x.nid)) }
    function clearAll() { history.slice().forEach(x => remove(x.nid)) }
    function invoke(nid, id) {
        const e = entry(nid)
        if (e && e.n) {
            const a = (e.n.actions || []).find(x => x.identifier === id)
            if (a) a.invoke()
        }
        hidePopup(nid)
    }
    function setDnd(on) {
        dnd = on
        dndFile.setText(on ? "true\n" : "false\n")
        if (on) popups = []
        writeBar()
    }
    function writeBar() {
        const c = history.length
        barFile.setText(JSON.stringify({
            text: (dnd ? "󰂛" : c > 0 ? "󰂚" : "󰂜") + (c > 0 ? "  " + c : ""),
            tooltip: (c === 0 ? "No notifications" : c + " notification" + (c === 1 ? "" : "s")) + (dnd ? " · Do not disturb" : ""),
            class: dnd ? "dnd" : c > 0 ? "unread" : "empty"
        }) + "\n")
        Quickshell.execDetached(["pkill", "-RTMIN+9", "-x", "waybar"])
    }

    // abgeschaltet (notifications.enabled = false) meldet sich hypr-shell gar nicht erst als Dienst an,
    // dann kann ein anderer Benachrichtigungsdienst laufen
    LazyLoader {
        active: nc.enabled
        NotificationServer {
            keepOnReload: true
            actionsSupported: true
            bodyMarkupSupported: false
            imageSupported: true
            persistenceSupported: true
            onNotification: n => nc.add(n)
        }
    }

    FileView {
        id: dndFile
        path: Settings.dataDir + "/dnd"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const on = text().trim() === "true"; if (on !== nc.dnd) { nc.dnd = on; nc.writeBar() } }
    }
    FileView { id: barFile; path: Settings.dataDir + "/notifications-bar.json" }
    Component.onCompleted: writeBar()

    IpcHandler {
        target: "notifications"
        function open(): void { ov.show() }
        function close(): void { ov.hide() }
        function toggle(): void { ov.toggle() }
        function clear(): void { nc.clearAll() }
        function dnd(on: bool): void { nc.setDnd(on) }
        function count(): int { return nc.history.length }
        function visible(): int { return nc.popups.length }
    }

    // ---- Karten oben rechts (unter der Leiste), nur so gross wie die Karten selbst
    PanelWindow {
        id: cards
        screen: Settings.screenFor(Settings.get("desktop.screen", ""))
        visible: nc.popups.length > 0 && screen !== null
        anchors { top: true; right: true }
        margins { top: 8; right: 12 }
        implicitWidth: 380
        implicitHeight: Math.max(1, stack.implicitHeight)
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hypr-shell-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: stack }

        Column {
            id: stack
            width: parent.width
            spacing: 8
            Repeater {
                model: nc.popups
                delegate: NotificationCard {
                    required property int modelData
                    width: stack.width
                    info: nc.entry(modelData) || ({})
                    timeout: nc.timeout
                    center: nc
                    popup: true
                }
            }
        }
    }

    // ---- Verlauf: Panel oben rechts (wächst aus der Ecke)
    Overlay {
        id: ov
        name: "notifications"
        ipc: false
        place: "top-right"
        panelWidth: 420
        panelHeight: Math.min(item ? item.implicitHeight : 200, (screen ? screen.height : 1080) - 80)
        keyboardFocus: WlrKeyboardFocus.OnDemand
        content: Component { NotificationPanel { center: nc } }
    }
}
