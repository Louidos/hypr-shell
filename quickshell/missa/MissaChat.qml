import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common"

// Chat mit Missa (SUPER+I): Panel von der rechten Kante. Wird nur geladen, wenn missa.enabled an ist
// (shell.qml) – ausgeschaltet gibt es weder Panel noch IPC-Ziel noch eine Netzanfrage.
// Senden über shell-missa chat (Streaming, Sitzung hypr-shell-<Rechnername>, nur die neue Nachricht);
// die Antwort läuft Wort für Wort ein. Der Verlauf der Anzeige steht in missa-chat.json.
Scope {
    id: mc
    property var messages: []           // { role: "user"|"assistant"|"error", text }
    property bool busy: false
    property bool working: false         // Stream pausiert (Missa benutzt ein Werkzeug)
    property bool fresh: false           // nach "New conversation": eigener Verlauf
    property var health: ({ state: "setup", text: "" })
    property var inbox: []               // Dateien in ~/Missa/Eingang (neueste zuerst)
    property bool voice: false           // Antwort zum Vorlesen (vom Sprechen mit Missa)
    signal answered(string text)

    // ---- Verlauf der Aktionen des Missa-Agenten (missa-actions.log), nur mit eingeschaltetem Agenten
    property bool showActions: false
    property var actions: []
    FileView {
        path: Settings.dataDir + "/missa-actions.log"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const l = []
            for (const z of text().split("\n").slice(-40)) { try { if (z.trim() !== "") l.push(JSON.parse(z)) } catch (e) { } }
            mc.actions = l.reverse()
        }
    }

    // ---- mit Missa sprechen (missa.voice_enabled): Aufnahme → whisper.cpp → Chat → piper
    property string voiceState: ""       // "", "listening", "thinking", "speaking"
    property int level: 0
    property var voiceAvail: ({ ok: false, speak: false })
    readonly property bool voiceOn: Integrations.missaVoice && voiceAvail.ok === true
    function voiceToggle() {
        if (!Integrations.missaVoice) return
        if (voiceState === "listening" || voiceState === "speaking") { voiceStop(); return }
        if (voiceState !== "" || !voiceAvail.ok) return
        voiceState = "listening"
        level = 0
        listenProc.running = true
    }
    function voiceStop() {
        Quickshell.execDetached([Settings.bin + "shell-voice", "stop"])
        if (voiceState === "speaking") { speakProc.running = false; voiceState = "" }
    }
    // Markdown fürs Vorlesen entfernen
    function plain(t) { return String(t).replace(/[*_`#>]/g, "").replace(/\[([^\]]*)\]\([^)]*\)/g, "$1") }
    onAnswered: text => {
        if (!voice || !voiceAvail.speak) { if (voiceState === "thinking") voiceState = ""; return }
        voiceState = "speaking"
        speakProc.text = plain(text)
        speakProc.running = true
    }
    onBusyChanged: if (!busy && voiceState === "thinking" && last && last.role === "error") voiceState = ""
    Process {
        id: availProc
        command: [Settings.bin + "shell-voice", "available"]
        running: Integrations.missaVoice
        stdout: StdioCollector { onStreamFinished: { try { mc.voiceAvail = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: listenProc
        command: [Settings.bin + "shell-voice", "listen"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("L ") === 0) mc.level = parseInt(line.slice(2)) || 0
                else if (line === "S") mc.voiceState = "thinking"
                else if (line.indexOf("R ") === 0) { try { mc.voiceState = "thinking"; mc.send(JSON.parse(line.slice(2)), true) } catch (e) { mc.voiceState = "" } }
                else if (line.indexOf("E ") === 0) mc.voiceState = ""
            }
        }
        onExited: if (mc.voiceState === "listening") mc.voiceState = ""
    }
    Process {
        id: speakProc
        property string text: ""
        command: [Settings.bin + "shell-voice", "speak"]
        stdinEnabled: true
        onStarted: { write(text + "\n"); stdinEnabled = false }
        onExited: { stdinEnabled = true; if (mc.voiceState === "speaking") mc.voiceState = "" }
    }
    readonly property var last: messages.length > 0 ? messages[messages.length - 1] : null
    // Rückfrage: letzte Antwort endet mit einem Fragezeichen
    readonly property bool asking: !busy && last !== null && last.role === "assistant" && /\?\s*[*_]*\s*$/.test(last.text)

    function save() { store.setText(JSON.stringify(messages.slice(-60))) }
    function push(role, text) { const m = messages.slice(); m.push({ role: role, text: text }); messages = m }
    function send(text, viaVoice) {
        text = String(text || "").trim()
        if (text === "" || busy) return
        voice = viaVoice === true
        const verlauf = fresh ? messages.filter(m => m.role !== "error").map(m => ({ role: m.role, content: m.text })) : []
        push("user", text)
        push("assistant", "")
        busy = true
        working = false
        chat.environment = { MISSA_NEU: fresh ? "1" : "0", MISSA_VERLAUF: JSON.stringify(verlauf) }
        chat.command = [Settings.bin + "shell-missa", "chat"].concat(voice ? ["--voice"] : [])
        chat.pending = text
        chat.running = true
        pause.restart()
    }
    function cancel() {
        if (!busy) return
        chat.running = false
        finish("(cancelled)")
    }
    function finish(note) {
        busy = false
        working = false
        pause.stop()
        const m = messages.slice()
        if (m.length > 0 && m[m.length - 1].role === "assistant" && m[m.length - 1].text === "") m.pop()
        if (note) m.push({ role: "error", text: note })
        messages = m
        save()
        if (!note && last && last.role === "assistant") answered(last.text)
    }
    function newConversation() {
        if (busy) cancel()
        messages = []
        fresh = true
        save()
    }
    function appendChunk(t) {
        const m = messages.slice()
        const a = Object.assign({}, m[m.length - 1])
        a.text += t
        m[m.length - 1] = a
        messages = m
        working = false
        pause.restart()
    }

    Timer { id: pause; interval: 2500; onTriggered: if (mc.busy) mc.working = true }

    Process {
        id: chat
        property string pending: ""
        stdinEnabled: true
        onStarted: { write(pending + "\n"); stdinEnabled = false }
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("T ") === 0) { try { mc.appendChunk(JSON.parse(line.slice(2))) } catch (e) { } }
                else if (line.indexOf("E ") === 0) {
                    const rest = line.slice(2), i = rest.indexOf(" ")
                    let msg = rest.slice(i + 1)
                    try { msg = JSON.parse(msg) } catch (e) { }
                    chat.error = msg
                }
            }
        }
        property string error: ""
        onExited: {
            stdinEnabled = true
            const e = error
            error = ""
            if (mc.busy) mc.finish(e !== "" ? e : "")
        }
    }
    Process {
        id: healthProc
        command: [Settings.bin + "shell-missa", "health"]
        stdout: StdioCollector { onStreamFinished: { try { mc.health = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: inboxProc
        command: ["bash", "-c", "d=\"$1\"; case \"$d\" in '~/'*) d=\"$HOME/${d#\\~/}\";; esac; find \"$d/Eingang\" -maxdepth 1 -type f -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -n 6 | cut -f2", "_",
                  Settings.get("missa.folder", "~/Missa")]
        stdout: StdioCollector { onStreamFinished: mc.inbox = text.split("\n").filter(x => x !== "") }
    }
    FileView {
        id: store
        path: Settings.dataDir + "/missa-chat.json"
        printErrors: false
        onLoaded: { try { const m = JSON.parse(text()); if (Array.isArray(m)) mc.messages = m } catch (e) { } }
    }

    IpcHandler {
        target: "missa"
        function open(): void { ov.show() }
        function close(): void { ov.hide() }
        function toggle(): void { ov.toggle() }
        function send(text: string): void { ov.show(); mc.send(text, false) }
        function cancel(): void { mc.cancel() }
        function newChat(): void { mc.newConversation() }
        // für Tests
        function lastText(): string { return mc.last ? mc.last.role + ": " + mc.last.text : "" }
        function busy(): bool { return mc.busy }
        function asking(): bool { return mc.asking }
        function status(): string { return mc.health.state }
        function voice(): void { mc.voiceToggle() }
        function voiceState(): string { return mc.voiceState }
    }

    Overlay {
        id: ov
        name: "missa"
        ipc: false
        place: "right"
        fill: true
        panelWidth: 460
        keyboardFocus: WlrKeyboardFocus.Exclusive
        onOpened: { healthProc.running = true; inboxProc.running = true }

        content: Component {
            Item {
                id: root
                focus: true
                Keys.onEscapePressed: event => { if (mc.voiceState === "speaking") { mc.voiceStop(); event.accepted = true } else event.accepted = false }

                // ---- Kopf
                Item {
                    id: head
                    x: 16; y: 14
                    width: parent.width - 32
                    height: 44
                    Rectangle {
                        id: av
                        width: 38; height: 38; radius: 19
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.container
                        Glyph { anchors.centerIn: parent; text: "󰚩"; size: 18; color: Theme.containerText }
                    }
                    Column {
                        anchors { left: av.right; leftMargin: Theme.pad(12); verticalCenter: parent.verticalCenter }
                        Txt { text: "Missa"; size: 16; title: true }
                        Row {
                            spacing: Theme.pad(6)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8; height: 8; radius: 4
                                color: mc.health.state === "ok" ? "#5cc98a" : mc.health.state === "setup" ? "#e0b24f" : Theme.warn
                            }
                            Txt { text: mc.health.text || ""; size: 11; sub: true }
                        }
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: Theme.pad(6)
                        IconButton { visible: Integrations.missaAgent; icon: "󰋚"; active: mc.showActions; onClicked: mc.showActions = !mc.showActions }
                        IconButton { icon: "󰐕"; onClicked: mc.newConversation() }
                        IconButton { icon: "󰅖"; onClicked: ov.hide() }
                    }
                }

                // ---- Anleitung ohne Adresse oder Schlüssel
                Txt {
                    visible: mc.health.state === "setup" && mc.messages.length === 0
                    anchors { top: head.bottom; topMargin: Theme.pad(24); left: parent.left; leftMargin: Theme.pad(24); right: parent.right; rightMargin: Theme.pad(24) }
                    text: "To chat with Missa, enter the address of Missa-Core and the API key in Settings → Integrations."
                    size: 13
                    sub: true
                    wrapMode: Text.Wrap
                }

                // ---- Aktionen des Agenten (Zeit, Werkzeug, Kurzfassung, erlaubt oder abgelehnt)
                ListView {
                    visible: mc.showActions
                    anchors { top: head.bottom; topMargin: Theme.pad(12); bottom: footer.top; bottomMargin: Theme.pad(8); left: parent.left; leftMargin: Theme.pad(14); right: parent.right; rightMargin: Theme.pad(14) }
                    clip: true
                    spacing: Theme.pad(6)
                    model: mc.actions
                    header: Txt { text: "What Missa did on this computer"; size: 13; strong: true; bottomPadding: Theme.pad(6) }
                    delegate: GlassCard {
                        required property var modelData
                        width: ListView.view.width
                        height: ac.implicitHeight + 16
                        Column {
                            id: ac
                            x: 12; y: 8
                            width: parent.width - 24
                            Row {
                                spacing: Theme.pad(8)
                                Txt { text: (modelData.zeit || "").slice(11, 16); size: 11; sub: true; font.family: Theme.mono }
                                Txt { text: (modelData.werkzeug || "").replace("rechner_", ""); size: 12; strong: true }
                                Txt {
                                    text: modelData.ergebnis === "erlaubt" ? "allowed" : modelData.ergebnis === "abgelehnt" ? "declined" : modelData.ergebnis
                                    size: 11
                                    color: modelData.ergebnis === "erlaubt" ? "#5cc98a" : Theme.warn
                                }
                            }
                            Txt { width: parent.width; text: modelData.kurz || ""; size: 11; sub: true; wrapMode: Text.WrapAnywhere; maximumLineCount: 3 }
                        }
                    }
                }

                // ---- Verlauf
                ListView {
                    id: list
                    visible: !mc.showActions
                    anchors { top: head.bottom; topMargin: Theme.pad(12); bottom: footer.top; bottomMargin: Theme.pad(8); left: parent.left; leftMargin: Theme.pad(14); right: parent.right; rightMargin: Theme.pad(14) }
                    clip: true
                    spacing: Theme.pad(10)
                    model: mc.messages
                    onCountChanged: positionViewAtEnd()
                    onContentHeightChanged: if (mc.busy) positionViewAtEnd()
                    delegate: Item {
                        id: msg
                        required property var modelData
                        required property int index
                        readonly property bool mine: modelData.role === "user"
                        width: list.width
                        height: bubble.height
                        Rectangle {
                            id: bubble
                            anchors.right: msg.mine ? parent.right : undefined
                            width: Math.min(list.width * 0.86, Math.max(60, body.implicitWidth + 28))
                            height: body.implicitHeight + 20
                            radius: 16
                            color: msg.mine ? Theme.container : msg.modelData.role === "error" ? Qt.rgba(0.88, 0.42, 0.46, 0.18) : Theme.card
                            border.width: 1
                            border.color: Theme.cardBorder
                            Text {
                                id: body
                                x: 14; y: 10
                                width: Math.min(list.width * 0.86 - 28, implicitWidth)
                                text: msg.modelData.text === "" && mc.busy ? (mc.working ? "Missa is working …" : "…") : msg.modelData.text
                                textFormat: msg.modelData.role === "assistant" ? Text.MarkdownText : Text.PlainText
                                wrapMode: Text.Wrap
                                color: msg.mine ? Theme.containerText : Theme.text
                                font.family: Theme.sans
                                font.pixelSize: 13 * Theme.fontScale
                                onLinkActivated: link => Qt.openUrlExternally(link)
                            }
                            HoverHandler { id: copyHov }
                            IconButton {
                                visible: copyHov.hovered && msg.modelData.text !== ""
                                anchors { right: parent.right; top: parent.top; margins: Theme.pad(4) }
                                width: 24; height: 24
                                iconSize: 10
                                icon: "󰆏"
                                onClicked: Quickshell.execDetached(["wl-copy", msg.modelData.text])
                            }
                        }
                    }
                    footer: Item {
                        width: list.width
                        height: mc.busy && mc.working ? 28 : (mc.asking ? 44 : 0)
                        Txt {
                            visible: mc.busy && mc.working
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Missa is working …"
                            size: 12
                            sub: true
                        }
                        Row {
                            visible: mc.asking
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            spacing: Theme.pad(8)
                            Pill { text: "Yes"; icon: "󰄬"; active: true; onClicked: mc.send("Ja", false); Probe { name: "missa-yes" } }
                            Pill { text: "No"; icon: "󰅖"; onClicked: mc.send("Nein", false) }
                        }
                    }
                }

                // ---- Eingabe
                Column {
                    id: footer
                    anchors { bottom: parent.bottom; bottomMargin: Theme.pad(14); left: parent.left; leftMargin: Theme.pad(14); right: parent.right; rightMargin: Theme.pad(14) }
                    spacing: Theme.pad(8)
                    Flow {
                        width: parent.width
                        visible: mc.inbox.length > 0
                        spacing: Theme.pad(6)
                        Txt { text: "From Eingang:"; size: 11; sub: true; height: 26; verticalAlignment: Text.AlignVCenter }
                        Repeater {
                            model: mc.inbox
                            delegate: Pill {
                                required property string modelData
                                implicitHeight: 26
                                fontSize: 11
                                icon: "󰈙"
                                text: modelData.split("/").pop()
                                onClicked: input.insert(input.length, (input.text === "" ? "" : " ") + modelData)
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: Math.min(140, Math.max(48, input.contentHeight + 24))
                        radius: 20
                        color: Theme.field
                        border.width: 1
                        border.color: drop.containsDrag ? Theme.text : Theme.cardBorder
                        Flickable {
                            id: inFlick
                            anchors { left: parent.left; leftMargin: Theme.pad(16); right: mc.voiceOn ? micBtn.left : sendBtn.left; rightMargin: Theme.pad(8); top: parent.top; topMargin: Theme.pad(12); bottom: parent.bottom; bottomMargin: Theme.pad(12) }
                            contentHeight: input.contentHeight
                            clip: true
                            TextEdit {
                                id: input
                                width: inFlick.width
                                focus: true
                                wrapMode: TextEdit.Wrap
                                color: Theme.text
                                font.family: Theme.sans
                                font.pixelSize: 13 * Theme.fontScale
                                Keys.onReturnPressed: event => {
                                    if (event.modifiers & Qt.ShiftModifier) { event.accepted = false; return }
                                    mc.send(text, false); text = ""
                                }
                                Txt { visible: input.text.length === 0; text: "Write to Missa (drop files here)"; size: 13; sub: true }
                            }
                        }
                        IconButton {
                            id: micBtn
                            visible: mc.voiceOn
                            anchors { right: sendBtn.left; rightMargin: Theme.pad(4); bottom: parent.bottom; bottomMargin: Theme.pad(7) }
                            active: mc.voiceState === "listening"
                            icon: "󰍬"
                            onClicked: mc.voiceToggle()
                        }
                        IconButton {
                            id: sendBtn
                            anchors { right: parent.right; rightMargin: Theme.pad(8); bottom: parent.bottom; bottomMargin: Theme.pad(7) }
                            active: mc.busy || input.text.length > 0
                            icon: mc.busy ? "󰓛" : "󰒊"
                            onClicked: { if (mc.busy) mc.cancel(); else { mc.send(input.text, false); input.text = "" } }
                        }
                        // Dateien hineinziehen: der Pfad kommt als Text in die Nachricht
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            onDropped: drag => {
                                const p = (drag.urls || []).map(u => decodeURIComponent(String(u).replace(/^file:\/\//, "")))
                                if (p.length > 0) input.insert(input.length, (input.text === "" ? "" : " ") + p.join(" "))
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Anzeige beim Sprechen: unten in der Mitte, Pegel und "Listening", "Thinking", "Speaking".
    // Ein Klick (oder Esc, wenn sie den Fokus hat) beendet Aufnahme bzw. Vorlesen.
    Overlay {
        id: voiceOv
        name: "missa-voice"
        exclusive: false
        ipc: false
        place: "bottom"
        margin: 72
        panelWidth: 280
        panelHeight: 52
        radius: 26
        localOpen: mc.voiceState !== ""
        layer: WlrLayer.Overlay
        keyboardFocus: WlrKeyboardFocus.OnDemand
        closeOnOutside: false
        content: Component {
            Item {
                focus: true
                Keys.onEscapePressed: mc.voiceStop()
                Glyph {
                    id: vIcon
                    anchors { left: parent.left; leftMargin: Theme.pad(18); verticalCenter: parent.verticalCenter }
                    text: mc.voiceState === "speaking" ? "󰕾" : mc.voiceState === "thinking" ? "󰚩" : "󰍬"
                    size: 18
                    color: mc.voiceState === "listening" ? Theme.warn : Theme.text
                }
                Txt {
                    id: vText
                    anchors { left: vIcon.right; leftMargin: Theme.pad(12); verticalCenter: parent.verticalCenter }
                    text: mc.voiceState === "listening" ? "Listening" : mc.voiceState === "thinking" ? "Thinking …" : "Speaking"
                    size: 13
                    strong: true
                }
                Rectangle {
                    visible: mc.voiceState === "listening"
                    anchors { left: vText.right; leftMargin: Theme.pad(14); right: parent.right; rightMargin: Theme.pad(20); verticalCenter: parent.verticalCenter }
                    height: 6
                    radius: 3
                    color: Theme.track
                    Rectangle {
                        width: parent.width * Math.min(100, mc.level) / 100
                        height: parent.height
                        radius: 3
                        color: Theme.pill
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }
                }
                TapHandler { onTapped: mc.voiceStop() }
                Probe { name: "missa-voice" }
            }
        }
    }
}
