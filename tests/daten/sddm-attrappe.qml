// Attrappe für den SDDM-Greeter (Tests): stellt config, sddm, userModel und sessionModel bereit,
// lädt das Thema (Pfad in THEME_DIR), meldet "geladen" und speichert ein Bild davon.
import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 1280; height: 720; visible: true
    readonly property string dir: Qt.application.arguments[Qt.application.arguments.length - 1]

    QtObject {
        id: config
        property string background: "background.png"
        property string accent: "#8ab4f8"
        property string text: "#e3e2e6"
        property string subtext: "#c4c6d0"
        property string surface: "#111318"
        property string error: "#ffb4ab"
        property string font_ui: "Inter"
        property string font_mono: "JetBrainsMono Nerd Font"
    }
    QtObject {
        id: sddm
        property bool canSuspend: true
        property bool canReboot: true
        property bool canPowerOff: true
        signal loginFailed()
        signal loginSucceeded()
        property string last: ""
        function login(u, p, i) { last = u + "|" + p + "|" + i; console.log("attrappe login " + last); if (p !== "richtig") loginFailed() }
        function suspend() { console.log("attrappe suspend") }
        function reboot() { console.log("attrappe reboot") }
        function powerOff() { console.log("attrappe powerOff") }
    }
    ListModel {
        id: userModel
        property string lastUser: "tester"
        ListElement { name: "gast"; realName: "Gast"; icon: "" }
        ListElement { name: "tester"; realName: "Test Person"; icon: "" }
    }
    ListModel {
        id: sessionModel
        property int lastIndex: 1
        ListElement { name: "Plasma" }
        ListElement { name: "Hyprland" }
    }

    Loader {
        id: loader
        anchors.fill: parent
        source: "file://" + win.dir + "/Main.qml"
        onStatusChanged: if (status === Loader.Error) { console.log("attrappe FEHLER beim Laden"); Qt.exit(3) }
        onLoaded: probe.start()
    }
    Timer {
        id: probe; interval: 800
        onTriggered: {
            const r = loader.item
            console.log("attrappe geladen user=" + r.user.name + " session=" + r.sessions[r.sessionIndex] + " gruss=" + r.greeting())
            r.login()
            loader.item.grabToImage(function (img) { img.saveToFile(win.dir + "/vorschau.png"); console.log("attrappe bild"); Qt.exit(0) })
        }
    }
}
