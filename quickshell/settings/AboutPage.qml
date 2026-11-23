import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Seite About: Version und wo die Einstellungen liegen.
Column {
    id: ab
    property var about: ({})
    property string version: ""
    spacing: 12

    FileView { path: Settings.dataDir + "/VERSION"; onLoaded: ab.version = text().trim() }
    Process {
        command: [Settings.bin + "shell-sysinfo", "about"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { ab.about = JSON.parse(text) } catch (e) { } } }
    }

    // settings.json im Terminal (apps.terminal) mit $EDITOR öffnen, sonst nano
    function openSettingsFile() {
        const term = Settings.get("apps.terminal", "kitty")
        const pre = term.split(" ")[0] === "kitty" ? ["kitty", "--class", "hypr-shell-tui"] : term.split(" ")
        Quickshell.execDetached(pre.concat(["-e", "bash", "-c", "exec ${EDITOR:-nano} \"$1\"", "_", Settings.file]))
        Ui.closeSettings()
    }
    // Übersicht aller Einstellungen (docs/einstellungen.md) im Browser (apps.browser)
    function openDocs() {
        const url = "https://github.com/Louidos/hypr-shell/blob/main/docs/einstellungen.md"
        const b = Settings.get("apps.browser", "firefox").split(" ").filter(x => x !== "")
        Quickshell.execDetached(b.concat([url]))
        Ui.closeSettings()
    }

    component Line: Row {
        id: line
        property string key
        property string value
        width: parent ? parent.width : 300
        spacing: 10
        Txt { width: 140; text: line.key; sub: true; size: 13 }
        Txt { width: line.width - 150; text: line.value || "–"; size: 13; weight: Font.DemiBold; font.family: Theme.mono }
    }

    GlassCard {
        width: parent.width
        height: info.implicitHeight + 32
        Column {
            id: info
            x: 18; y: 16
            width: parent.width - 36
            spacing: 10
            Txt { text: "hypr-shell"; size: 18; weight: Font.Bold }
            Txt { text: "Glass desktop for Hyprland"; sub: true; size: 12 }
            Item { width: 1; height: 4 }
            Line { key: "Version"; value: ab.version }
            Line { key: "Settings file"; value: "~/.config/hypr-shell/settings.json" }
            Line { key: "Values"; value: (Settings.schema.keys || []).length + " settings in the schema" }
            Line { key: "Hyprland"; value: ab.about.hyprland || "" }
            Line { key: "Quickshell"; value: ab.about.quickshell || "" }
            Item { width: 1; height: 6 }
            Row {
                spacing: 8
                Pill {
                    icon: "󰈙"
                    text: "Open settings.json"
                    onClicked: ab.openSettingsFile()
                    Probe { name: "about-open-settings" }
                }
                Pill {
                    icon: "󰈹"
                    text: "Open docs"
                    onClicked: ab.openDocs()
                    Probe { name: "about-open-docs" }
                }
            }
        }
    }
}
