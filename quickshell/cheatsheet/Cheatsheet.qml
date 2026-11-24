import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Kürzel-Spickzettel (SUPER+F1): alle Tastenkürzel in Gruppen, gelesen aus den echten Belegungen
// ("hyprctl binds -j", bei jedem Öffnen neu – ein geändertes Kürzel steht nach "hyprctl reload" drin).
// Die Beschreibung "Gruppe: Aktion" kommt aus hyprland.lua; Kürzel ohne Beschreibung (eigene in
// user.lua) stehen unter "Custom". Kürzel ausgeschalteter Anbindungen sind gar nicht belegt und
// fehlen deshalb. Arbeitsflächen 1…0 werden zu einer Zeile zusammengefasst.
Scope {
    id: cs
    property var binds: []
    property string query: ""
    readonly property var order: ["Panels", "Windows", "Workspaces", "Apps", "Missa", "Screenshots", "System", "Custom"]
    readonly property var icons: ({ Panels: "󰕮", Windows: "󰖯", Workspaces: "󰕰", Apps: "󰀻", Missa: "󰚩", Screenshots: "󰹑", System: "󰒓", Custom: "󰌌" })

    // modmask aus hyprctl: SHIFT 1, CAPS 2, CTRL 4, ALT 8, MOD2 16, MOD3 32, SUPER 64, MOD5 128
    function combo(b) {
        const m = b.modmask || 0, p = []
        if (m & 64) p.push("SUPER")
        if (m & 4) p.push("CTRL")
        if (m & 8) p.push("ALT")
        if (m & 1) p.push("SHIFT")
        if (m & 128) p.push("MOD5")
        const k = b.key === "mouse:272" ? "Left drag" : b.key === "mouse:273" ? "Right drag"
                : b.key === "mouse_down" ? "Scroll down" : b.key === "mouse_up" ? "Scroll up" : b.key
        p.push(k)
        return p.join(" + ")
    }
    // [{ group, items: [{ keys, text }] }]
    readonly property var groups: {
        const rows = []
        const sammel = {}   // "Go to workspace" → Zeile, um 1…0 zusammenzufassen
        for (const b of binds) {
            if (b.submap && b.submap !== "") continue
            const d = b.description || ""
            const i = d.indexOf(": ")
            let g = i > 0 ? d.slice(0, i) : "Custom"
            let t = i > 0 ? d.slice(i + 2) : (d || b.arg || "")
            if (cs.order.indexOf(g) < 0) g = "Custom"
            const keys = combo(b)
            const n = t.match(/^(.*) (\d+)$/)
            if (n && /^\d$/.test(b.key)) {
                const id = g + "|" + n[1]
                if (sammel[id]) { sammel[id].nums.push(b.key); continue }
                const r = { group: g, text: n[1] + " 1…10", keys: keys, nums: [b.key], prefix: keys.slice(0, -1) }
                sammel[id] = r
                rows.push(r)
                continue
            }
            rows.push({ group: g, text: t, keys: keys })
        }
        for (const id in sammel) {
            const r = sammel[id]
            if (r.nums.length > 1) r.keys = r.prefix + "1…0"
        }
        const q = query.trim().toLowerCase()
        const out = []
        for (const g of cs.order) {
            const items = rows.filter(r => r.group === g && (q === "" || (r.text + " " + r.keys + " " + g).toLowerCase().indexOf(q) >= 0))
            if (items.length > 0) out.push({ group: g, items: items })
        }
        return out
    }
    readonly property int count: groups.reduce((n, g) => n + g.items.length, 0)

    Process {
        id: bindsProc
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector { onStreamFinished: { try { cs.binds = JSON.parse(text) } catch (e) { cs.binds = [] } } }
    }

    IpcHandler {
        target: "cheatsheet"
        function open(): void { ov.show() }
        function close(): void { ov.hide() }
        function toggle(): void { ov.toggle() }
        // für Tests: Anzahl Zeilen und eine Zeile je Kürzel ("Gruppe|Tasten|Aktion")
        function rows(): string { return cs.groups.map(g => g.items.map(r => g.group + "|" + r.keys + "|" + r.text).join("\n")).join("\n") }
        function filter(text: string): int { cs.query = text; return cs.count }
    }

    Overlay {
        id: ov
        name: "cheatsheet"
        ipc: false
        place: "center"
        margin: 0
        panelWidth: 1120
        panelHeight: ov.portrait ? 1100 : 760
        scroll: false
        keyboardFocus: WlrKeyboardFocus.Exclusive
        onOpened: { cs.query = ""; bindsProc.running = true }

        content: Component {
            Item {
                focus: true
                Item {
                    id: head
                    x: 24; y: 20
                    width: parent.width - 48
                    height: 44
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Txt { text: "Keyboard shortcuts"; size: 18; weight: Font.Bold }
                        Txt { text: cs.count + " shortcuts · change them in Settings → Keybinds"; size: 11; sub: true }
                    }
                    Rectangle {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: Math.min(300, parent.width * 0.45)
                        height: 40
                        radius: 20
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Theme.cardBorder
                        Glyph { id: lens; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: ""; size: 12; color: Theme.subtext }
                        TextInput {
                            id: field
                            anchors { left: lens.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            focus: true
                            color: Theme.text
                            font.family: Theme.sans
                            font.pixelSize: 13 * Theme.fontScale
                            clip: true
                            onTextChanged: cs.query = text
                            Txt { visible: field.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "Search shortcuts"; size: 13; sub: true }
                        }
                    }
                }

                Flickable {
                    id: flick
                    x: 24
                    anchors { top: head.bottom; topMargin: 16; bottom: parent.bottom; bottomMargin: 20 }
                    width: parent.width - 48
                    contentHeight: flow.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Flow {
                        id: flow
                        width: flick.width
                        spacing: 14
                        Repeater {
                            model: cs.groups
                            delegate: GlassCard {
                                id: card
                                required property var modelData
                                // drei Spalten, auf schmalen Bildschirmen (Hochformat) zwei oder eine
                                readonly property int cols: flow.width >= 880 ? 3 : flow.width >= 540 ? 2 : 1
                                width: (flow.width - (cols - 1) * flow.spacing) / cols
                                height: col.implicitHeight + 24
                                Column {
                                    id: col
                                    x: 14; y: 12
                                    width: parent.width - 28
                                    spacing: 6
                                    Row {
                                        spacing: 8
                                        Glyph { text: cs.icons[card.modelData.group] || ""; size: 14; anchors.verticalCenter: parent.verticalCenter }
                                        Txt { text: card.modelData.group; size: 14; weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Repeater {
                                        model: card.modelData.items
                                        delegate: Item {
                                            required property var modelData
                                            width: col.width
                                            height: Math.max(26, label.implicitHeight + 6)
                                            Txt {
                                                id: label
                                                anchors { left: parent.left; right: keyBox.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                                text: modelData.text
                                                size: 12
                                                wrapMode: Text.Wrap
                                                elide: Text.ElideNone
                                            }
                                            Rectangle {
                                                id: keyBox
                                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                                width: Math.min(col.width * 0.55, keyTxt.implicitWidth + 16)
                                                height: 22
                                                radius: 7
                                                color: Qt.rgba(1, 1, 1, 0.08)
                                                border.width: 1
                                                border.color: Theme.cardBorder
                                                Txt {
                                                    id: keyTxt
                                                    anchors.centerIn: parent
                                                    width: Math.min(implicitWidth, parent.width - 12)
                                                    text: modelData.keys
                                                    size: 11
                                                    font.family: Theme.mono
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Txt {
                    anchors.centerIn: flick
                    visible: cs.count === 0
                    text: cs.binds.length === 0 ? "Could not read the shortcuts (hyprctl binds)" : "Nothing found"
                    sub: true
                }
            }
        }
    }
}
