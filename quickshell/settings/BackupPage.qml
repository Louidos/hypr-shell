import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Abschnitt „Backup“ auf der Seite System: Profile (alle Einstellungen unter einem Namen speichern
// und wieder laden) sowie Export und Import in eine Datei. Früher auf der Startseite.
Column {
    id: home
    spacing: Theme.pad(14)
    property var profiles: []
    property string exportPath: Settings.home + "/hypr-shell-settings.json"

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

    Txt { text: "Backup"; size: 15; title: true; topPadding: Theme.pad(8); color: Theme.subtext; Probe { name: "backup-section" } }

    // ---- Profile
    GlassCard {
        width: parent.width
        height: profCol.implicitHeight + 2 * Theme.cardPad
        Column {
            id: profCol
            x: Theme.cardPad; y: Theme.cardPad
            width: parent.width - 2 * Theme.cardPad
            spacing: Theme.pad(10)
            Txt { text: "Profiles"; size: 15; title: true }
            Txt { width: parent.width; text: "Save all current settings under a name and load them again later."; sub: true; size: 12; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            Row {
                spacing: Theme.pad(8)
                Field { id: profName; width: 240; placeholder: "Profile name (letters, digits, - and _)" }
                Pill {
                    Probe { name: "backup-profile-save" }
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
        height: expCol.implicitHeight + 2 * Theme.cardPad
        Column {
            id: expCol
            x: Theme.cardPad; y: Theme.cardPad
            width: parent.width - 2 * Theme.cardPad
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
