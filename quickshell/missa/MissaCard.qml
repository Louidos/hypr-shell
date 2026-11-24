import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Karte Missa im Dashboard (nur mit missa.enabled): Kurzfassung aus GET /api/lagebild und die
// nächsten Erinnerungen aus GET /api/erinnerungen. Gelesen nur, solange das Dashboard offen ist.
// Klick öffnet den Chat.
Item {
    id: card
    property string summary: ""
    property var reminders: []
    property string problem: ""

    function zeit(iso) {
        const d = new Date(iso)
        return isNaN(d.getTime()) ? "" : Qt.formatDateTime(d, "ddd HH:mm")
    }
    Process {
        running: true
        command: [Settings.bin + "shell-missa", "get", "/api/lagebild"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const t = JSON.parse(text).text || ""
                    // erste Zeilen ohne Überschriften
                    card.summary = t.split("\n").filter(l => l.trim() !== "" && l.indexOf("#") !== 0).slice(0, 3).join("\n")
                    card.problem = ""
                } catch (e) { card.problem = "Missa-Core not reachable" }
            }
        }
    }
    Process {
        running: true
        command: [Settings.bin + "shell-missa", "get", "/api/erinnerungen"]
        stdout: StdioCollector { onStreamFinished: { try { card.reminders = (JSON.parse(text).erinnerungen || []).slice(0, 2) } catch (e) { } } }
    }

    Row {
        anchors { left: parent.left; leftMargin: Theme.pad(16); right: parent.right; rightMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
        spacing: Theme.pad(12)
        Rectangle {
            width: 44; height: 44; radius: 22
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.container
            Glyph { anchors.centerIn: parent; text: "󰚩"; size: 20; color: Theme.containerText }
        }
        Column {
            width: parent.width - 56
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.pad(2)
            Txt { text: "Missa"; size: 14; title: true }
            Txt {
                width: parent.width
                text: card.problem !== "" ? card.problem : (card.summary || "Nothing special right now")
                size: 11
                sub: true
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
            Txt {
                width: parent.width
                visible: card.reminders.length > 0
                text: "⏰ " + card.reminders.map(r => r.text + " · " + card.zeit(r.faellig)).join("   ")
                size: 11
            }
        }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: Ui.openPanel("missa") }
    Probe { name: "missa-card" }
}
