// hypr-shell: Anmeldebildschirm im Stil des Sperrbildschirms (hyprlock.conf).
// Hintergrund = Bild unscharf und abgedunkelt (beim Installieren vorbereitet), Inhalt links:
// Profilbild, grosse gestapelte Uhr (24 h), Datum, Begrüssung, Passwort als schlichte Linie,
// Benutzer- und Sitzungswahl, darunter Standby, Neustart, Herunterfahren.
// Nur QtQuick ohne Zusatzmodule, damit das Thema mit jedem SDDM-Greeter (Qt 5 oder 6) startet.
import QtQuick 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: cfg("surface", "#121214")

    function cfg(k, d) { const v = config[k]; return (v === undefined || v === null || v === "") ? d : String(v) }
    function dim(c, a) { return Qt.rgba(Qt.color(c).r, Qt.color(c).g, Qt.color(c).b, a) }

    readonly property real s: Math.max(0.6, Math.min(width / 1920, height / 1080))
    readonly property color accent: cfg("accent", "#d4d4d4")
    readonly property color textColor: cfg("text", "#e6e6e6")
    readonly property color textDim: dim(cfg("text", "#e6e6e6"), 0.55)
    readonly property color subtext: cfg("subtext", "#c8c8c8")
    readonly property color errorColor: cfg("error", "#dc5050")
    readonly property string fontUi: cfg("font_ui", "Inter")
    readonly property string fontMono: cfg("font_mono", "JetBrainsMono Nerd Font")
    readonly property real edge: 110 * s
    readonly property real mid: height / 2

    // ---- Benutzer und Sitzungen aus den Modellen von SDDM
    property var users: []
    property int userIndex: 0
    property var sessions: []
    property int sessionIndex: sessionModel && sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property var user: users.length > 0 ? users[Math.min(userIndex, users.length - 1)] : ({ name: "", realName: "", icon: "" })

    Repeater {
        model: userModel
        delegate: Item {
            Component.onCompleted: {
                const u = root.users.slice()
                u[index] = { name: model.name, realName: model.realName || model.name, icon: model.icon || "" }
                root.users = u
                if (model.name === userModel.lastUser) root.userIndex = index
            }
        }
    }
    Repeater {
        model: sessionModel
        delegate: Item {
            Component.onCompleted: { const l = root.sessions.slice(); l[index] = model.name; root.sessions = l }
        }
    }

    FontLoader { id: display; source: "fonts/BebasNeue-Regular.ttf" }

    Image {
        anchors.fill: parent
        source: root.cfg("background", "background.png")
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    function two(n) { return (n < 10 ? "0" : "") + n }
    // Datum wie auf dem Sperrbildschirm (LC_TIME=C): "Monday, 23 November"
    function dateText() {
        const d = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        const m = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
                   "October", "November", "December"]
        return d[now.getDay()] + ", " + two(now.getDate()) + " " + m[now.getMonth()]
    }
    function greeting() {
        const h = now.getHours()
        const name = String(user.name || "")   // wie shell-greeting auf dem Sperrbildschirm
        const g = h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        return name !== "" ? g + ", " + name : g
    }

    // ---- Profilbild (Bild des Benutzers, sonst der Anfangsbuchstabe im Kreis)
    Rectangle {
        id: face
        x: root.edge
        y: root.mid - 380 * root.s - height / 2
        width: 96 * root.s; height: width; radius: width / 2
        color: root.dim(root.textColor, 0.12)
        border.color: root.textDim; border.width: 2
        clip: true
        Text {
            anchors.centerIn: parent
            visible: faceImg.status !== Image.Ready
            text: String(root.user.realName || root.user.name || "?").charAt(0).toUpperCase()
            color: root.textColor
            font.family: root.fontUi; font.pixelSize: 40 * root.s
        }
        Image {
            id: faceImg
            anchors.fill: parent; anchors.margins: 2
            source: root.user.icon ? (String(root.user.icon).indexOf("/") === 0 ? "file://" + root.user.icon : root.user.icon) : ""
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
        }
    }

    // ---- grosse gestapelte Uhr
    Text {
        id: hours
        x: root.edge - 4 * root.s
        y: root.mid - 230 * root.s - height / 2
        text: root.two(root.now.getHours())
        color: root.textColor
        font.family: display.name; font.pixelSize: 170 * root.s
    }
    Text {
        x: root.edge - 4 * root.s
        y: root.mid - 90 * root.s - height / 2
        text: root.two(root.now.getMinutes())
        color: root.textDim
        font.family: display.name; font.pixelSize: 170 * root.s
    }

    // ---- Datum und Begrüssung
    Text {
        x: root.edge; y: root.mid + 10 * root.s - height / 2
        text: root.dateText()
        color: root.subtext
        font.family: root.fontUi; font.pixelSize: 22 * root.s
    }
    Text {
        objectName: "greeting"
        x: root.edge; y: root.mid + 44 * root.s - height / 2
        text: root.greeting()
        color: root.textColor
        font.family: root.fontUi; font.pixelSize: 20 * root.s; font.weight: Font.DemiBold
    }

    // ---- Passwortfeld als schlichte Linie
    Item {
        id: field
        x: root.edge; y: root.mid + 118 * root.s - height / 2
        width: 300 * root.s; height: 46 * root.s
        TextInput {
            id: password
            anchors.fill: parent
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            passwordCharacter: "●"
            color: root.textColor
            selectionColor: root.accent
            font.family: root.fontMono; font.pixelSize: 18 * root.s
            focus: true
            clip: true
            onAccepted: root.login()
            Keys.onEscapePressed: { text = ""; message.text = "" }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: password.text === ""
                text: "Password"
                color: root.dim("#ffffff", 0.53)
                font.family: root.fontUi; font.pixelSize: 18 * root.s
            }
        }
    }
    Rectangle {
        x: root.edge; y: field.y + field.height
        width: field.width; height: 2
        color: message.text !== "" ? root.errorColor : password.activeFocus ? root.accent : root.textDim
    }
    Text {
        id: message
        x: root.edge; y: field.y + field.height + 10 * root.s
        color: root.errorColor
        font.family: root.fontUi; font.pixelSize: 15 * root.s
    }

    function login() {
        if (user.name === "") return
        message.text = ""
        sddm.login(user.name, password.text, sessionIndex)
    }
    Connections {
        target: sddm
        function onLoginFailed() { password.text = ""; message.text = "Wrong password"; password.forceActiveFocus() }
        function onLoginSucceeded() { message.text = "" }
    }

    // ---- Benutzer und Sitzung (Klick schaltet weiter)
    Row {
        x: root.edge; y: root.mid + 190 * root.s
        spacing: 26 * root.s
        Text {
            objectName: "user"
            text: "󰀄  " + (root.user.name || "?") + (root.users.length > 1 ? "  ›" : "")
            color: root.subtext
            font.family: root.fontMono; font.pixelSize: 15 * root.s
            MouseArea {
                anchors.fill: parent
                enabled: root.users.length > 1
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.userIndex = (root.userIndex + 1) % root.users.length; password.forceActiveFocus() }
            }
        }
        Text {
            objectName: "session"
            text: "󰍹  " + (root.sessions[root.sessionIndex] || "Session") + (root.sessions.length > 1 ? "  ›" : "")
            color: root.subtext
            font.family: root.fontMono; font.pixelSize: 15 * root.s
            MouseArea {
                anchors.fill: parent
                enabled: root.sessions.length > 1
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.sessionIndex = (root.sessionIndex + 1) % root.sessions.length; password.forceActiveFocus() }
            }
        }
    }

    // ---- Standby, Neustart, Herunterfahren
    Row {
        x: root.edge; y: root.mid + 250 * root.s
        spacing: 38 * root.s
        Repeater {
            model: [
                { icon: "󰤄", can: sddm.canSuspend, act: function () { sddm.suspend() } },
                { icon: "󰜉", can: sddm.canReboot, act: function () { sddm.reboot() } },
                { icon: "󰐥", can: sddm.canPowerOff, act: function () { sddm.powerOff() } }
            ]
            delegate: Text {
                text: modelData.icon
                visible: modelData.can !== false
                color: hover.containsMouse ? root.textColor : root.textDim
                font.family: root.fontMono; font.pixelSize: 32 * root.s
                MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
            }
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
