import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common"

// ALT+Tab: Glas-Leiste in der Mitte mit allen offenen Fenstern, zuletzt benutzte zuerst (ein kurzes
// ALT+Tab springt also zum vorherigen Fenster). Jedes weitere Tab wählt weiter, ALT loslassen wechselt.
// Die Tasten kommen über eine Submap von Hyprland (hyprland.lua): die Leiste selbst nimmt nie die
// Tastatur. Sicherheit: ohne Taste nach 5 s zu (Submap verlassen), ebenso, wenn sich der Fokus von
// aussen ändert oder ein anderes Panel aufgeht.
//   shell-quickshell ipc switcher next|prev|commit|cancel|closeSelected
Scope {
    id: sw
    readonly property bool on: Settings.get("switcher.enabled", true) === true
    readonly property bool previews: Settings.get("switcher.previews", true) === true
    readonly property bool allWorkspaces: Settings.get("switcher.scope", "all") === "all"
    readonly property real tile: Settings.get("switcher.size", "medium") === "small" ? 150 : Settings.get("switcher.size", "medium") === "large" ? 260 : 200

    // ---- zuletzt benutzt (MRU): Adressen, vorne das aktive Fenster; Hyprland meldet jeden Fokus
    property var mru: []
    function touch(a) {
        const x = String(a || "").replace(/^0x/, "").toLowerCase()
        if (x === "") return
        mru = [x].concat(mru.filter(y => y !== x)).slice(0, 200)
    }
    Connections {
        target: Ui.hyprland ? Hyprland : null
        function onRawEvent(event) {
            if (event.name === "activewindowv2") {
                sw.touch(event.data)
                // Fokus von aussen geändert, während die Leiste offen ist: abbrechen
                if (ov.open && !sw.committing) sw.cancel()
            }
        }
    }

    // ---- Fenster: unter Hyprland mit Adresse, Arbeitsfläche, Bildschirm und Minimiert-Zustand;
    // ohne Hyprland (Test-Compositor) die Wayland-Fenster in ihrer Reihenfolge
    function entries() {
        const r = []
        if (Ui.hyprland) {
            const l = Hyprland.toplevels.values
            const aktiv = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
            for (let i = 0; i < l.length; i++) {
                const h = l[i]
                if (!h) continue
                const ws = h.workspace, o = h.lastIpcObject || {}
                const minimized = !!ws && ws.name === "special:minimiert"
                if (ws && ws.name && ws.name.indexOf("special:") === 0 && !minimized) continue
                if (!sw.allWorkspaces && !minimized && ws && ws.id !== aktiv) continue
                const a = String(h.address).replace(/^0x/, "").toLowerCase()
                r.push({ address: a, title: String(h.title || o.title || ""), cls: String(o.class || o.initialClass || ""),
                         workspace: ws ? (ws.name || String(ws.id)) : "", other: !!ws && ws.id !== aktiv && !minimized,
                         monitor: ws && ws.monitor ? ws.monitor.name : "", minimized: minimized, toplevel: h.wayland })
            }
            const rank = a => { const i = sw.mru.indexOf(a); return i < 0 ? 1000 : i }
            r.sort((x, y) => rank(x.address) - rank(y.address))
        } else {
            const l = ToplevelManager.toplevels.values
            for (let i = 0; i < l.length; i++)
                r.push({ address: "", title: String(l[i].title || ""), cls: String(l[i].appId || ""), workspace: "", other: false,
                         monitor: "", minimized: false, toplevel: l[i] })
            r.sort((x, y) => (y.toplevel.activated ? 1 : 0) - (x.toplevel.activated ? 1 : 0))
        }
        return r
    }

    property var items: []
    property int sel: 0
    property bool committing: false
    // auf dem Bildschirm mit dem Mauszeiger (unter Hyprland folgt der fokussierte Bildschirm der Maus)
    readonly property var screen: {
        const n = Ui.hyprland && Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        const l = Quickshell.screens
        for (let i = 0; i < l.length; i++) if (l[i].name === n) return l[i]
        return Settings.screenFor(Settings.get("desktop.screen", ""))
    }

    function step(d) {
        if (!sw.on) return
        if (!ov.open) {
            const l = entries()
            if (l.length === 0) { submapReset(); return }
            items = l
            // kurzes ALT+Tab: das vorherige Fenster (Index 1); rückwärts: das letzte
            sel = d > 0 ? Math.min(1, l.length - 1) : l.length - 1
            ov.show()
        } else if (items.length > 0) {
            sel = ((sel + d) % items.length + items.length) % items.length
        }
        idle.restart()
    }
    function commit() {
        idle.stop()
        if (!ov.open) { submapReset(); return }
        const it = items[sel]
        committing = true
        ov.hide()
        submapReset()
        if (it) activate(it)
        committing = false
    }
    function cancel() { idle.stop(); if (ov.open) ov.hide(); submapReset() }
    function activate(it) {
        if (it.minimized && it.address !== "") Quickshell.execDetached([Settings.bin + "shell-window", "restore", "0x" + it.address])
        else if (it.address !== "") Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:0x" + it.address + "\" })"])
        else if (it.toplevel) it.toplevel.activate()
    }
    function closeSelected() {
        const it = items[sel]
        if (!it) return
        if (it.address !== "") Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close({ window = \"address:0x" + it.address + "\" })"])
        else if (it.toplevel) it.toplevel.close()
        const l = items.filter((x, i) => i !== sel)
        if (l.length === 0) { cancel(); return }
        items = l
        sel = Math.min(sel, l.length - 1)
        idle.restart()
    }
    // die Submap von Hyprland verlassen (die Tasten von ALT+Tab gelten nur, solange die Leiste offen ist)
    function submapReset() { if (Ui.hyprland) Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"]) }

    // nie hängen bleiben: 5 s ohne Taste (Loslassen von ALT verloren, Sperrbildschirm, Spiel startet)
    Timer { id: idle; interval: 5000; onTriggered: sw.cancel() }
    // ein anderes Panel geht auf (oder Notfall-Freigabe): abbrechen
    Connections {
        target: Ui
        function onPanelChanged() { if (Ui.panel !== "switcher" && ov.open) sw.cancel() }
        function onReleased() { sw.cancel() }
    }

    IpcHandler {
        target: "switcher"
        enabled: sw.on
        function next(): void { sw.step(1) }
        function prev(): void { sw.step(-1) }
        function commit(): void { sw.commit() }
        function cancel(): void { sw.cancel() }
        function closeSelected(): void { sw.closeSelected() }
        // für Tests: "offen:Auswahl:Anzahl" bzw. "zu"
        function state(): string { return ov.open ? "open:" + sw.sel + ":" + sw.items.length : "closed" }
        function titles(): string { return sw.items.map(i => i.title).join("|") }
    }

    Overlay {
        id: ov
        name: "switcher"
        ipc: false
        place: "center"
        screen: sw.screen
        layer: WlrLayer.Overlay
        // die Tasten kommen über die Submap von Hyprland: die Leiste nimmt nie die Tastatur
        keyboardFocus: WlrKeyboardFocus.None
        closeOnEscape: false
        // kein Fokus-Griff (er könnte die Tastatur nehmen); daneben klicken wirkt nach 5 s ohne Taste
        closeOnOutside: false
        readonly property int perRow: Math.max(1, Math.min(sw.items.length, Math.floor((roomW / k - 32) / (sw.tile + 12))))
        readonly property int rowsNeeded: Math.max(1, Math.ceil(sw.items.length / perRow))
        panelWidth: perRow * (sw.tile + 12) + 20
        panelHeight: rowsNeeded * (sw.tile * 0.75 + 54) + 20
        onClosed: if (!sw.committing) sw.submapReset()

        content: Component {
            Item {
                Flow {
                    x: 10; y: 10
                    width: parent.width - 20
                    spacing: Theme.pad(12)
                    Repeater {
                        model: sw.items
                        delegate: Rectangle {
                            id: cell
                            required property var modelData
                            required property int index
                            readonly property bool active: index === sw.sel
                            width: sw.tile
                            height: sw.tile * 0.75 + 42
                            radius: Theme.cardRadius
                            color: active ? Theme.cardHover : Theme.card
                            border.width: active ? 2 : 1
                            border.color: active ? Theme.accent : Theme.cardBorder
                            opacity: modelData.minimized ? 0.75 : 1
                            // Vorschau (Screencopy wie im Dock), sonst das Symbol
                            Item {
                                id: shot
                                x: 8; y: 8
                                width: parent.width - 16
                                height: sw.tile * 0.75 - 8
                                Loader {
                                    anchors.fill: parent
                                    active: sw.previews && !!cell.modelData.toplevel && ov.open
                                    sourceComponent: ScreencopyView {
                                        captureSource: cell.modelData.toplevel
                                        live: false
                                    }
                                }
                                AppIcon {
                                    anchors.centerIn: parent
                                    size: Math.min(parent.height * 0.5, 56)
                                    icon: cell.modelData.cls.toLowerCase()
                                    opacity: sw.previews ? 0.9 : 1
                                }
                                // andere Arbeitsfläche oder minimiert: kleiner Hinweis
                                Pill {
                                    visible: cell.modelData.other || cell.modelData.minimized
                                    anchors { right: parent.right; top: parent.top; margins: Theme.pad(4) }
                                    clickable: false
                                    implicitHeight: 20
                                    fontSize: 10
                                    text: cell.modelData.minimized ? "minimized" : cell.modelData.workspace + (cell.modelData.monitor ? " · " + cell.modelData.monitor : "")
                                }
                            }
                            Txt {
                                x: 10; y: shot.y + shot.height + 6
                                width: parent.width - 20
                                text: cell.modelData.title !== "" ? cell.modelData.title : cell.modelData.cls
                                size: 12
                                strong: cell.active
                                horizontalAlignment: Text.AlignHCenter
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) { sw.sel = cell.index; idle.restart() } }
                            TapHandler { onTapped: { sw.sel = cell.index; sw.commit() } }
                            Probe { name: "switcher-" + cell.index }
                        }
                    }
                }
            }
        }
    }
}
