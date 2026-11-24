import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Kopf der Seite Laptop: Leistungsprofil und Grafik-Modus (aus shell-laptop status, nur was der
// Rechner kann). Ein neuer Grafik-Modus braucht eine Bestätigung, weil man sich danach ab- oder
// neu anmelden muss. Ladegrenze und Tastaturlicht stehen darunter als normale Einstellungen.
Column {
    id: lp
    spacing: Theme.pad(12)
    property var st: ({ caps: {}, profile: null, profiles: [], gfx: null, gfx_modes: [], gfx_pending: null })
    property string confirm: ""      // Grafik-Modus, der auf Bestätigung wartet
    property string message: ""

    function reload() { statusProc.running = true }
    function run(args) {
        actionProc.command = [Settings.bin + "shell-laptop"].concat(args)
        actionProc.running = true
    }
    Component.onCompleted: reload()

    Process {
        id: statusProc
        command: [Settings.bin + "shell-laptop", "status"]
        stdout: StdioCollector { onStreamFinished: { try { lp.st = JSON.parse(text) } catch (e) { } } }
    }
    Process {
        id: actionProc
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") lp.message = text.trim().split("\n").slice(-1)[0] }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") lp.message = text.trim().split("\n").slice(-1)[0] }
        onExited: lp.reload()
    }

    Txt {
        visible: !lp.st.caps.laptop
        width: parent.width
        text: "This computer has no adjustable power profile, graphics mode or charge limit (asusctl, supergfxctl or power-profiles-daemon). On ASUS laptops: install asusctl."
        size: 13
        sub: true
        wrapMode: Text.Wrap
    }

    // ---- Leistungsprofil
    GlassCard {
        visible: lp.st.profile !== null
        width: parent.width
        height: 64
        Txt { anchors { left: parent.left; leftMargin: Theme.pad(18); verticalCenter: parent.verticalCenter } text: "Power profile" + (lp.st.caps.asusctl ? "  ·  asusctl" : ""); size: 14; strong: true }
        Row {
            anchors { right: parent.right; rightMargin: Theme.pad(14); verticalCenter: parent.verticalCenter }
            spacing: Theme.pad(6)
            Repeater {
                model: lp.st.profiles
                delegate: Pill {
                    required property string modelData
                    text: ({ "power-saver": "Quiet", balanced: "Balanced", performance: "Performance" })[modelData] || modelData
                    active: lp.st.profile === modelData
                    onClicked: lp.run(["profile", "set", modelData])
                    Probe { name: "laptop-profile-" + modelData }
                }
            }
        }
    }

    // ---- Grafik-Modus (supergfxctl)
    GlassCard {
        visible: lp.st.gfx !== null
        width: parent.width
        height: gfxCol.implicitHeight + 28
        Column {
            id: gfxCol
            x: 18; y: 14
            width: parent.width - 36
            spacing: Theme.pad(10)
            Item {
                width: parent.width
                height: 30
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Txt { text: "Graphics mode"; size: 14; strong: true }
                    Txt { text: "Now: " + (lp.st.gfx || "–") + (lp.st.gfx_pending && lp.st.gfx_pending.indexOf("No action") < 0 ? "  ·  " + lp.st.gfx_pending : ""); size: 12; sub: true }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.pad(6)
                    Repeater {
                        model: lp.st.gfx_modes
                        delegate: Pill {
                            required property string modelData
                            text: modelData
                            active: lp.st.gfx === modelData
                            onClicked: if (lp.st.gfx !== modelData) lp.confirm = modelData
                        }
                    }
                }
            }
            Rectangle {
                visible: lp.confirm !== ""
                width: parent.width
                height: 52
                radius: 14
                color: Theme.field
                Txt {
                    anchors { left: parent.left; leftMargin: Theme.pad(14); right: btns.left; rightMargin: Theme.pad(10); verticalCenter: parent.verticalCenter }
                    text: "Switch to " + lp.confirm + "? You have to log out (or restart) afterwards."
                    size: 12
                    wrapMode: Text.Wrap
                }
                Row {
                    id: btns
                    anchors { right: parent.right; rightMargin: Theme.pad(10); verticalCenter: parent.verticalCenter }
                    spacing: Theme.pad(6)
                    Pill { text: "Cancel"; onClicked: lp.confirm = "" }
                    Pill { text: "Switch"; active: true; onClicked: { lp.run(["gfx", "set", lp.confirm]); lp.confirm = "" } }
                }
            }
        }
    }
    Txt { visible: lp.message !== ""; width: parent.width; text: lp.message; size: 12; sub: true; wrapMode: Text.Wrap }
}
