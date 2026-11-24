import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Seite Home: Begrüssung, Kurzwahl zu den wichtigsten Seiten, Profile und Sichern/Laden.
Column {
    id: home
    spacing: Theme.pad(14)
    property var profiles: []
    property string exportPath: Settings.home + "/hypr-shell-settings.json"
    property string message: ""

    SystemClock { id: clock; precision: SystemClock.Hours }
    function greeting() {
        const h = clock.date.getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }

    // Profile neu einlesen (beim Öffnen und nach jeder Änderung über shell-set)
    Process {
        id: listProc
        command: [Settings.bin + "shell-set", "profile", "list"]
        running: true
        stdout: StdioCollector { onStreamFinished: home.profiles = text.split("\n").filter(l => l.trim() !== "") }
    }
    Connections {
        target: Ui
        function onChangesChanged() { if (!listProc.running) listProc.running = true }
    }

    Txt { text: home.greeting() + ", " + Settings.user; size: 26; title: true }
    Txt {
        width: parent.width
        text: "Everything here is saved in ~/.config/hypr-shell/settings.json and works right away. You can also use shell-set in a terminal."
        sub: true; size: 13; wrapMode: Text.WordWrap; elide: Text.ElideNone
    }

    // ---- Kurzwahl
    Grid {
        width: parent.width
        columns: 3
        spacing: Theme.pad(10)
        Repeater {
            model: ["bar", "look", "theme", "desktop", "lock", "keybinds"]
            delegate: GlassCard {
                id: tile
                required property string modelData
                readonly property var pg: (Settings.schema.pages || []).find(p => p.id === modelData) || ({ title: modelData, description: "", icon: "" })
                width: (home.width - 20) / 3
                height: 78
                hoverable: true
                Rectangle {
                    id: tb
                    width: 40; height: 40; radius: 20
                    anchors { left: parent.left; leftMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
                    color: Theme.cardStrong
                    Glyph { anchors.centerIn: parent; text: tile.pg.icon; size: 17 }
                }
                Column {
                    anchors { left: tb.right; leftMargin: Theme.pad(12); right: parent.right; rightMargin: Theme.pad(12); verticalCenter: parent.verticalCenter }
                    Txt { width: parent.width; text: tile.pg.title; size: 14; strong: true }
                    Txt { width: parent.width; text: tile.pg.description; size: 11; sub: true }
                }
                TapHandler { onTapped: Ui.settingsPage = tile.modelData }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }

    // ---- Profile
    GlassCard {
        width: parent.width
        height: profCol.implicitHeight + 28
        Column {
            id: profCol
            x: 16; y: 14
            width: parent.width - 32
            spacing: Theme.pad(10)
            Txt { text: "Profiles"; size: 15; title: true }
            Txt { width: parent.width; text: "Save all current settings under a name and load them again later."; sub: true; size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            Row {
                spacing: Theme.pad(8)
                Field { id: profName; width: 240; placeholder: "Profile name (letters, digits, - and _)" }
                Pill {
                    icon: "󰆓"; text: "Save"
                    onClicked: {
                        const n = profName.input.text.trim()
                        if (!/^[A-Za-z0-9_-]{1,40}$/.test(n)) { Ui.lastError = "profile names use letters, digits, - and _"; return }
                        Ui.run(["profile", "save", n]); profName.input.text = ""
                    }
                }
            }
            Repeater {
                model: home.profiles
                delegate: Rectangle {
                    required property string modelData
                    width: profCol.width
                    height: 40
                    radius: 12
                    color: Theme.cardSoft
                    Txt { anchors { left: parent.left; leftMargin: Theme.pad(12); verticalCenter: parent.verticalCenter } text: modelData; size: 13; strong: true }
                    Row {
                        anchors { right: parent.right; rightMargin: Theme.pad(6); verticalCenter: parent.verticalCenter }
                        spacing: Theme.pad(6)
                        Pill { implicitHeight: 28; fontSize: 11; icon: "󰁯"; text: "Load"; onClicked: Ui.run(["profile", "load", modelData]) }
                        Pill { implicitHeight: 28; fontSize: 11; icon: "󰆴"; text: "Delete"; onClicked: Ui.run(["profile", "delete", modelData]) }
                    }
                }
            }
            Txt { visible: home.profiles.length === 0; text: "No profiles yet."; sub: true; size: 12 }
        }
    }

    // ---- Sichern und Laden
    GlassCard {
        width: parent.width
        height: expCol.implicitHeight + 28
        Column {
            id: expCol
            x: 16; y: 14
            width: parent.width - 32
            spacing: Theme.pad(10)
            Txt { text: "Export and import"; size: 15; title: true }
            Txt { width: parent.width; text: "Write your settings to a file or load them from one. A file is checked before it is loaded."; sub: true; size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            Row {
                spacing: Theme.pad(8)
                Field { id: path; width: Math.max(160, Math.min(380, expCol.width - 220)); mono: true; text: home.exportPath; onAccepted: t => home.exportPath = t }
                Pill { icon: "󰈝"; text: "Export"; onClicked: Ui.run(["export", path.input.text]) }
                Pill { icon: "󰈞"; text: "Import"; onClicked: Ui.run(["import", path.input.text]) }
            }
        }
    }
}
