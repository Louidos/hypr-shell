import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../common"

// Inhalt des Hot-Corner-Panels. Reihenfolge und Sichtbarkeit der Karten, App-Liste und
// Schalter kommen aus settings.json (panel.sections, panel.apps, panel.toggles).
FocusScope {
    id: pc
    property var panel
    property string query: ""
    readonly property bool typing: query.length > 0
    readonly property var sections: Settings.get("panel.sections", ["awake", "apps", "media", "shot", "toggles"])
    implicitHeight: col.implicitHeight + 28

    SystemClock { id: clock; precision: SystemClock.Minutes }

    function greeting() {
        const h = clock.date.getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
    readonly property string bin: Settings.home + "/.local/bin/"

    Column {
        id: col
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 10

        // ---- Kopf: Profilbild, Begrüssung, Datum, Uhrzeit
        Item {
            width: parent.width
            height: 52
            RoundImage {
                id: avatar
                width: 42; height: 42; radius: 21
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                source: "file://" + Settings.home + "/.face"
                fallbackText: Settings.user.length > 0 ? Settings.user[0].toUpperCase() : "?"
                probe: "panel-avatar"
            }
            Column {
                anchors { left: avatar.right; leftMargin: 12; right: time.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                Txt { width: parent.width; text: pc.greeting() + ", " + Settings.user; size: 14; weight: Font.Bold; font.family: Theme.mono }
                Txt { width: parent.width; text: Qt.locale("en_GB").toString(clock.date, "dddd, d MMMM"); size: 11; sub: true; font.family: Theme.mono }
            }
            Txt {
                id: time
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                text: Qt.formatTime(clock.date, "HH:mm")
                size: 24
                weight: Font.Bold
                font.family: Theme.mono
            }
        }

        Repeater {
            model: pc.sections
            delegate: Loader {
                required property string modelData
                width: col.width
                sourceComponent: modelData === "awake" ? awakeCard
                               : modelData === "apps" ? appsCard
                               : modelData === "media" ? mediaCard
                               : modelData === "shot" ? shotCard
                               : modelData === "toggles" ? togglesCard : null
            }
        }
    }

    // ---- Keep Awake
    Component {
        id: awakeCard
        GlassCard {
            height: 64
            IconButton {
                id: cup
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                icon: "󰅶"
                active: pc.panel.st.awake
                onClicked: pc.panel.toggle("awake")
            }
            Column {
                anchors { left: cup.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                Txt { text: "Keep Awake"; size: 13; weight: Font.Bold; font.family: Theme.mono }
                Txt {
                    text: pc.panel.st.awake ? "No lock, no standby" : "Normal power management"
                    size: 11; sub: true; font.family: Theme.mono
                }
            }
            Toggle {
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                checked: pc.panel.st.awake
                onToggled: pc.panel.toggle("awake")
            }
        }
    }

    // ---- Apps: Suchfeld, "All", Raster mit 4 Spalten
    Component {
        id: appsCard
        GlassCard {
            id: apps
            readonly property var pinned: {
                // Abhängigkeit auf die App-Liste: DesktopEntries lädt asynchron und kann sich ändern
                const alle = DesktopEntries.applications.values
                const ids = Settings.get("panel.apps", ["kitty", "org.gnome.Nautilus", "firefox", "spotify", "discord", "steam"])
                const r = []
                for (let i = 0; i < ids.length; i++) {
                    const e = alle.length > 0 ? (DesktopEntries.byId(ids[i]) || DesktopEntries.heuristicLookup(ids[i])) : null
                    if (e) r.push(e)   // nicht installierte Apps fallen weg
                }
                return r
            }
            readonly property var found: {
                const q = search.text.trim().toLowerCase()
                if (q.length === 0) return pinned
                const all = DesktopEntries.applications.values, r = []
                for (let i = 0; i < all.length && r.length < 8; i++) {
                    const e = all[i]
                    if (!e.noDisplay && (e.name.toLowerCase().indexOf(q) >= 0 || (e.genericName || "").toLowerCase().indexOf(q) >= 0)) r.push(e)
                }
                return r
            }
            function launch(e) { pc.panel.hide(); e.execute() }
            height: 14 + 36 + 10 + grid.implicitHeight + 14

            Row {
                id: searchRow
                x: 12; y: 14
                width: parent.width - 24
                spacing: 8
                Rectangle {
                    width: parent.width - allBtn.width - 8
                    height: 36
                    radius: 18
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Theme.cardBorder
                    Glyph { id: lens; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: ""; size: 12; color: Theme.subtext }
                    TextInput {
                        id: search
                        anchors { left: lens.right; leftMargin: 10; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: 12
                        clip: true
                        onTextChanged: pc.query = text
                        Keys.onEscapePressed: text.length > 0 ? text = "" : pc.panel.hide()
                        Keys.onReturnPressed: if (apps.found.length > 0) apps.launch(apps.found[0])
                        Txt { visible: search.text.length === 0; text: "Search apps"; size: 12; sub: true; font.family: Theme.mono }
                    }
                }
                Pill {
                    id: allBtn
                    implicitHeight: 36
                    icon: "󰀻"
                    text: "All"
                    onClicked: pc.panel.run(["rofi", "-show", "drun"], true)
                }
            }
            Grid {
                id: grid
                anchors { top: searchRow.bottom; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                columns: 4
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: apps.found
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: (apps.width - 24 - 12) / 4
                        height: 72
                        radius: 14
                        color: tileHover.hovered ? Theme.cardHover : "transparent"
                        AppIcon {
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                            size: 32
                            icon: modelData.icon || ""
                            probe: index === 0 ? "app-icon" : ""
                        }
                        Txt {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.name
                            size: 11
                            font.family: Theme.mono
                        }
                        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: apps.launch(modelData) }
                    }
                }
            }
        }
    }

    // ---- Now playing
    Component {
        id: mediaCard
        GlassCard {
            id: media
            readonly property var players: Mpris.players.values
            readonly property var player: {
                for (let i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i]
                return players.length > 0 ? players[0] : null
            }
            height: 64
            RoundImage {
                id: art
                width: 40; height: 40; radius: 10
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                source: media.player ? media.player.trackArtUrl : ""
                Glyph { anchors.centerIn: parent; visible: !art.ready; text: "󰎇"; size: 16; color: Theme.subtext }
            }
            Column {
                anchors { left: art.right; leftMargin: 12; right: controls.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                Txt { width: parent.width; text: media.player && media.player.trackTitle ? media.player.trackTitle : "Nothing playing"; size: 13; weight: Font.Bold; font.family: Theme.mono }
                Txt { width: parent.width; visible: text !== ""; text: media.player ? (media.player.trackArtist || "") : ""; size: 11; sub: true; font.family: Theme.mono }
            }
            Row {
                id: controls
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 2
                IconButton { flat: true; width: 30; height: 30; iconSize: 13; icon: "󰒮"; onClicked: if (media.player) media.player.previous() }
                IconButton { flat: true; width: 30; height: 30; iconSize: 13; icon: media.player && media.player.isPlaying ? "󰏤" : "󰐊"; onClicked: if (media.player) media.player.togglePlaying() }
                IconButton { flat: true; width: 30; height: 30; iconSize: 13; icon: "󰒭"; onClicked: if (media.player) media.player.next() }
            }
        }
    }

    // ---- Screenshot (wie die Vorlage): Kamera-Symbol, Titel, Hinweis, Ordner oben rechts,
    // darunter die Knöpfe Screen und Region
    Component {
        id: shotCard
        GlassCard {
            height: shotCol.implicitHeight + 28
            Column {
                id: shotCol
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12
                Item {
                    width: parent.width
                    height: 44
                    Rectangle {
                        id: camBubble
                        width: 44; height: 44; radius: 22
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(1, 1, 1, 0.07)
                        Glyph { anchors.centerIn: parent; text: "󰄀"; size: 19 }
                    }
                    Column {
                        anchors { left: camBubble.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Txt { text: "Screenshot"; size: 15; weight: Font.Bold; font.family: Theme.mono }
                        Txt { text: "Saved and copied to clipboard"; size: 12; color: "#9a9aa4"; font.family: Theme.mono }
                    }
                    Glyph {
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        text: "󰉋"
                        size: 15
                        color: folderHover.hovered ? "#F6F5F4" : "#8a8a8a"
                        HoverHandler { id: folderHover; margin: 6; cursorShape: Qt.PointingHandCursor }
                        TapHandler { margin: 6; onTapped: pc.panel.run([pc.bin + "shell-screenshot", "folder"], true) }
                    }
                }
                Row {
                    spacing: 8
                    Pill {
                        implicitHeight: 36
                        icon: "󰊓"
                        text: "Screen"
                        active: true
                        onClicked: pc.panel.run([pc.bin + "shell-screenshot", "screen"], true)
                    }
                    Pill {
                        implicitHeight: 36
                        icon: "󰆞"
                        text: "Region"
                        onClicked: pc.panel.run([pc.bin + "shell-screenshot", "region"], true)
                    }
                }
            }
        }
    }

    // ---- Quick Toggles
    Component {
        id: togglesCard
        GlassCard {
            id: tg
            readonly property var items: Settings.get("panel.toggles", ["wifi", "bluetooth", "dnd", "gaming", "settings"])
            readonly property var icons: ({ wifi: "󰤨", bluetooth: "󰂯", dnd: "󰂚", gaming: "󰊗", settings: "", awake: "󰅶" })
            height: 16 + 20 + 10 + 44 + 16
            Txt { x: 16; y: 16; text: "Quick Toggles"; size: 13; weight: Font.Bold; font.family: Theme.mono }
            Row {
                x: 12
                anchors { bottom: parent.bottom; bottomMargin: 16 }
                spacing: 8
                Repeater {
                    model: tg.items
                    delegate: IconButton {
                        required property string modelData
                        width: (tg.width - 24 - 8 * (tg.items.length - 1)) / tg.items.length
                        height: 44
                        radius: 14
                        iconSize: 17
                        icon: tg.icons[modelData] || ""
                        active: modelData !== "settings" && pc.panel.st[modelData] === true
                        onClicked: {
                            if (modelData === "settings")
                                pc.panel.run(["xdg-open", Settings.home + "/.config/hypr-shell/settings.json"], true)
                            else
                                pc.panel.toggle(modelData)
                        }
                    }
                }
            }
        }
    }
}
