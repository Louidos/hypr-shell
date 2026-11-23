import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Seite Integrations: je persönliche Anbindung eine Karte mit Schalter, Statuspunkt (aus, bereit,
// Fehler) und den nötigen Feldern. Passwörter und Schlüssel gehen direkt in
// ~/.config/hypr-shell/secrets.env (shell-secrets, über stdin) – nie in settings.json.
// Eingeschaltet ohne Zugangsdaten steht eine kurze Anleitung da statt eines Fehlers.
Column {
    id: ip
    spacing: 14
    property var mounts: ({})        // shell-mount status
    property var secrets: []         // gesetzte Namen (ohne Werte)

    readonly property var cards: [
        { id: "nextcloud", title: "Nextcloud", icon: "󰅟", keys: ["nextcloud.enabled", "nextcloud.url", "nextcloud.user", "nextcloud.mount_path", "nextcloud.cache_mb", "nextcloud.read_only"],
          secret: "NEXTCLOUD_APP_PASSWORD", secretTitle: "App password", howto: "In Nextcloud: Settings → Security → Devices & sessions → Create new app password." },
        { id: "missa", title: "Missa", icon: "󰚩", keys: ["missa.enabled", "missa.url", "missa.folder"],
          secret: "MISSA_API_KEY", secretTitle: "API key", howto: "Enter the address of Missa-Core and the API key from its configuration." },
        { id: "agent", title: "Missa on this computer", icon: "󰍹", keys: ["missa.agent_enabled"],
          secret: "MISSA_DEVICE_TOKEN", secretTitle: "Device token", howto: "Create a device token in Missa-Core (devices) and enter it here." },
        { id: "voice", title: "Talk to Missa", icon: "󰍬", keys: ["missa.voice_enabled", "missa.voice_language", "missa.voice_model", "missa.voice_voice", "missa.voice_speed"], secret: "", howto: "" },
        { id: "lab", title: "Homelab", icon: "󰒋", keys: ["lab.enabled"], secret: "", howto: "" },
        { id: "calendar", title: "Calendar", icon: "󰃭", keys: ["calendar.enabled", "calendar.url", "calendar.user"],
          secret: "CALDAV_PASSWORD", secretTitle: "Password", howto: "Enter the CalDAV address, user name and an (app) password." },
        { id: "sensor", title: "Sensor", icon: "󰈐", keys: ["sensor.enabled", "sensor.url"], secret: "", howto: "Enter an address that returns JSON." },
        { id: "games", title: "Own games", icon: "󰊴", keys: ["games.custom_enabled", "games.custom"], secret: "", howto: "" },
        { id: "security", title: "Self-signed servers", icon: "󰒃", keys: ["integrations.ca_file"], secret: "", howto: "", always: true }
    ]

    function has(name) { return secrets.indexOf(name) >= 0 }
    function val(k) { return Settings.get(k, "") }
    // { state: off|ready|error|missing|setup, text }
    function stateOf(c) {
        const on = Integrations.on(c.keys[0])
        if (c.always) return { state: "ready", text: val("integrations.ca_file") !== "" ? "CA file set" : "Not needed for normal servers" }
        if (Settings.get(c.keys[0], false) === true && !on) return { state: "setup", text: "Switch on Missa first" }
        if (!on) return { state: "off", text: "Off" }
        if (c.id === "nextcloud") return mounts.nextcloud || { state: "setup", text: "Checking …" }
        if (c.id === "missa" && (val("missa.url") === "" || !has("MISSA_API_KEY"))) return { state: "setup", text: c.howto }
        if (c.id === "agent" && !has("MISSA_DEVICE_TOKEN")) return { state: "setup", text: c.howto }
        if (c.id === "calendar" && (val("calendar.url") === "" || !has("CALDAV_PASSWORD"))) return { state: "setup", text: c.howto }
        if (c.id === "sensor" && val("sensor.url") === "") return { state: "setup", text: c.howto }
        return { state: "ready", text: "On" }
    }
    function reload() { statusProc.running = true; listProc.running = true }
    Component.onCompleted: reload()
    Timer { interval: 4000; running: true; repeat: true; onTriggered: ip.reload() }
    Connections { target: Ui; function onChangesChanged() { refreshSoon.restart() } }
    Timer { id: refreshSoon; interval: 1200; onTriggered: ip.reload() }

    Process {
        id: statusProc
        command: [Settings.bin + "shell-mount", "status"]
        stdout: StdioCollector { onStreamFinished: { try { ip.mounts = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: listProc
        command: [Settings.bin + "shell-secrets", "list"]
        stdout: StdioCollector { onStreamFinished: ip.secrets = text.split("\n").filter(x => x !== "") }
    }
    Process {
        id: secretProc
        property string value: ""
        stdinEnabled: true
        onStarted: { write(value + "\n"); value = ""; stdinEnabled = false }
        onExited: { stdinEnabled = true; ip.reload() }
    }
    Process { id: unsetProc; onExited: ip.reload() }

    Txt {
        width: parent.width
        text: "Everything here is off after installing hypr-shell. Passwords and keys are stored only in ~/.config/hypr-shell/secrets.env (readable only by you), never in settings.json."
        size: 12
        sub: true
        wrapMode: Text.Wrap
    }

    Repeater {
        model: ip.cards
        delegate: GlassCard {
            id: card
            required property var modelData
            readonly property var st: ip.stateOf(modelData)
            readonly property bool on: Integrations.on(modelData.keys[0]) || modelData.always === true
            property bool confirmRemove: false
            width: ip.width
            height: col.implicitHeight + 28
            Column {
                id: col
                x: 14; y: 14
                width: parent.width - 28
                spacing: 8
                Item {
                    width: parent.width
                    height: 34
                    Glyph { id: ic; anchors.verticalCenter: parent.verticalCenter; text: card.modelData.icon; size: 18 }
                    Txt { anchors { left: ic.right; leftMargin: 12; verticalCenter: parent.verticalCenter } text: card.modelData.title; size: 16; weight: Font.Bold }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10; height: 10; radius: 5
                            color: card.st.state === "ready" ? "#5cc98a" : card.st.state === "off" ? Theme.track
                                 : card.st.state === "setup" ? "#e0b24f" : Theme.warn
                            Probe { name: "status-" + card.modelData.id }
                        }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, card.width * 0.55)
                            text: card.st.text
                            size: 11
                            sub: true
                        }
                    }
                }
                Repeater {
                    // Schalter immer, die Felder erst, wenn die Anbindung an ist
                    model: card.modelData.keys.filter((k, i) => i === 0 || card.on)
                    delegate: SettingRow {
                        required property string modelData
                        width: col.width
                        spec: Settings.schemaKey(modelData) || ({ key: modelData })
                    }
                }
                // Passwort / Schlüssel → secrets.env
                Rectangle {
                    visible: card.on && card.modelData.secret !== ""
                    width: col.width
                    height: 52
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.04)
                    Txt {
                        id: secLabel
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        width: 120
                        text: card.modelData.secretTitle || ""
                        size: 13
                        weight: Font.DemiBold
                    }
                    Rectangle {
                        anchors { left: secLabel.right; leftMargin: 8; right: secBtns.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        height: 34
                        radius: 17
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: Theme.cardBorder
                        TextInput {
                            id: secInput
                            anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            echoMode: TextInput.Password
                            color: Theme.text
                            font.pixelSize: 12 * Theme.fontScale
                            clip: true
                            Keys.onReturnPressed: saveBtn.clicked()
                            Txt {
                                visible: secInput.text.length === 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: ip.has(card.modelData.secret) ? "Stored – type to replace" : "Not set"
                                size: 12
                                sub: true
                            }
                        }
                    }
                    Row {
                        id: secBtns
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Pill {
                            id: saveBtn
                            text: "Save"
                            active: secInput.text.length > 0
                            onClicked: {
                                if (secInput.text.length === 0) return
                                secretProc.command = [Settings.bin + "shell-secrets", "set", card.modelData.secret]
                                secretProc.value = secInput.text
                                secInput.text = ""
                                secretProc.running = true
                            }
                        }
                        Pill {
                            visible: ip.has(card.modelData.secret)
                            text: card.confirmRemove ? "Really remove?" : "Remove"
                            onClicked: {
                                if (!card.confirmRemove) { card.confirmRemove = true; return }
                                card.confirmRemove = false
                                unsetProc.command = [Settings.bin + "shell-secrets", "unset", card.modelData.secret]
                                unsetProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}
