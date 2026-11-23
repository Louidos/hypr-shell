import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Inhalt der Einstellungs-App: links Profil und Seiten, rechts Suche, Undo/Redo und die Seite.
// compact (Hochformat oder schmales Fenster): die Seiten stehen oben als waagrechte Leiste.
// Wird erst erzeugt, wenn das Fenster offen ist (Systemwerte und Seiten laden erst dann).
FocusScope {
    id: sc
    focus: true
    property bool compact: false
    property var about: ({})
    readonly property var pages: (Settings.schema.pages || []).filter(p => Ui.can(p.requires))
    readonly property var page: pages.find(p => p.id === Ui.settingsPage) || pages[0] || ({ id: "home", title: "Home" })

    Connections {
        target: Ui
        function onSettingsSearchChanged() { if (Ui.settingsSearch !== "") { search.input.text = Ui.settingsSearch; Ui.settingsSearch = "" } }
    }
    Component.onCompleted: if (Ui.settingsSearch !== "") { search.input.text = Ui.settingsSearch; Ui.settingsSearch = "" }

    Keys.onEscapePressed: {
        if (search.input.text !== "") search.input.text = ""
        else Ui.closeSettings()
    }

    // Fähigkeiten des Rechners (Laptop-Funktionen) für Seiten und Zeilen mit "requires"
    Process {
        command: [Settings.bin + "shell-laptop", "caps"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { Ui.caps = Object.assign({}, Ui.caps, JSON.parse(text)) } catch (e) { } } }
    }
    // Programme zum Mitfärben (Qt, Firefox, Vesktop, spicetify): Zeilen nur, wenn installiert
    Process {
        command: [Settings.bin + "shell-appcolors", "caps"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { Ui.caps = Object.assign({}, Ui.caps, JSON.parse(text)) } catch (e) { } } }
    }
    Process {
        command: [Settings.bin + "shell-sysinfo", "about"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { sc.about = JSON.parse(text) } catch (e) { } } }
    }

    // ---- Suche über Titel, Erklärung und Schlüssel
    readonly property var results: {
        const q = search.input.text.trim().toLowerCase()
        if (q.length < 2) return []
        const keys = Settings.schema.keys || []
        return keys.filter(k => Ui.can(k.requires) && sc.pages.some(p => p.id === k.page)
                           && (k.title + " " + k.description + " " + k.key).toLowerCase().indexOf(q) >= 0).slice(0, 8)
    }
    function go(spec) {
        search.input.text = ""
        Ui.settingsFocus = spec.key
        Ui.settingsPage = spec.page
        focusTimer.tries = 0
        focusTimer.restart()
    }
    Timer {
        id: focusTimer
        property int tries: 0
        interval: 60
        onTriggered: {
            const p = pageHolder.current
            if (Ui.settingsFocus === "" ) return
            if (p && p.focusKey(Ui.settingsFocus)) { Ui.settingsFocus = ""; return }
            if (++tries < 20) restart()
        }
    }

    GlassPanel {
        anchors.fill: parent
        radius: Theme.panelRadius
        glassOpacity: Theme.glassOpacity
    }

    // ---- Seitenleiste
    Item {
        id: side
        visible: !sc.compact
        x: 14; y: 14
        width: sc.compact ? 0 : Math.min(236, Math.max(180, sc.width * 0.24))
        height: parent.height - 28

        GlassCard { anchors.fill: parent }
        Column {
            id: who
            x: 16; y: 18
            width: parent.width - 32
            spacing: 8
            RoundImage {
                width: 56; height: 56; radius: 28
                source: Settings.face
                Component.onCompleted: Settings.checkFace()
                fallbackText: Settings.user.length > 0 ? Settings.user[0].toUpperCase() : "?"
                probe: "settings-avatar"
            }
            Txt { width: parent.width; text: Settings.user; size: 16; weight: Font.Bold }
            Pill { clickable: false; implicitHeight: 24; fontSize: 11; icon: sc.about.icon || ""; text: sc.about.distro || "Linux" }
        }
        Flickable {
            anchors { top: who.bottom; topMargin: 16; left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 10; leftMargin: 10; rightMargin: 10 }
            contentHeight: nav.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: nav
                width: parent.width
                spacing: 2
                Repeater {
                    model: sc.compact ? [] : sc.pages
                    delegate: Rectangle {
                        id: navItem
                        required property var modelData
                        readonly property bool active: sc.page.id === modelData.id
                        width: nav.width
                        height: 36
                        radius: 18
                        color: active ? Theme.pill : (hov.hovered ? Theme.cardHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Glyph {
                            id: navIcon
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            width: 20
                            text: navItem.modelData.icon
                            size: 15
                            color: navItem.active ? Theme.pillText : Theme.text
                        }
                        Txt {
                            anchors { left: navIcon.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: navItem.modelData.title
                            size: 13
                            weight: navItem.active ? Font.DemiBold : Font.Medium
                            color: navItem.active ? Theme.pillText : Theme.text
                        }
                        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Ui.settingsPage = navItem.modelData.id }
                        Probe { name: "nav-" + navItem.modelData.id }
                    }
                }
            }
        }
    }

    // ---- Seiten als waagrechte Leiste (compact): Profilbild, dann die Seiten, rollt seitlich
    Item {
        id: topNav
        visible: sc.compact
        x: 14; y: 14
        width: parent.width - 28
        height: sc.compact ? 52 : 0
        GlassCard { anchors.fill: parent }
        RoundImage {
            id: topFace
            x: 8; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18
            source: Settings.face
            Component.onCompleted: Settings.checkFace()
            fallbackText: Settings.user.length > 0 ? Settings.user[0].toUpperCase() : "?"
        }
        Flickable {
            id: topFlick
            anchors { left: topFace.right; leftMargin: 8; right: parent.right; rightMargin: 8; top: parent.top; bottom: parent.bottom }
            contentWidth: topRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Row {
                id: topRow
                height: topFlick.height
                spacing: 2
                Repeater {
                    model: sc.compact ? sc.pages : []
                    delegate: Rectangle {
                        id: topItem
                        required property var modelData
                        readonly property bool active: sc.page.id === modelData.id
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        width: topLabel.implicitWidth + 46
                        height: 36
                        radius: 18
                        color: active ? Theme.pill : (topHov.hovered ? Theme.cardHover : "transparent")
                        // die gewählte Seite sichtbar halten
                        onActiveChanged: if (active) topFlick.contentX = Math.max(0, Math.min(x - 40, topFlick.contentWidth - topFlick.width))
                        Glyph {
                            id: topIcon
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: topItem.modelData.icon
                            size: 14
                            color: topItem.active ? Theme.pillText : Theme.text
                        }
                        Txt {
                            id: topLabel
                            anchors { left: topIcon.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            text: topItem.modelData.title
                            size: 13
                            weight: topItem.active ? Font.DemiBold : Font.Medium
                            color: topItem.active ? Theme.pillText : Theme.text
                        }
                        HoverHandler { id: topHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Ui.settingsPage = topItem.modelData.id }
                        Probe { name: "nav-" + topItem.modelData.id }
                    }
                }
            }
        }
    }

    // ---- Kopf: Suche, Fehler, Undo/Redo, Schliessen
    Item {
        id: head
        anchors { left: sc.compact ? parent.left : side.right; leftMargin: sc.compact ? 14 : 18; right: parent.right; rightMargin: sc.compact ? 14 : 18 }
        y: sc.compact ? topNav.y + topNav.height + 12 : 18
        height: 40

        Field {
            id: search
            width: Math.max(140, Math.min(360, parent.width - 220))
            height: 40
            radius: 20
            placeholder: "Search settings, e.g. blur, clock, battery"
            commitOnBlur: false
            onAccepted: if (sc.results.length > 0) sc.go(sc.results[0])
            Probe { name: "settings-search" }
        }
        Txt {
            anchors { left: search.right; leftMargin: 12; right: buttons.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: Ui.lastError
            color: Theme.warn
            size: 12
        }
        Row {
            id: buttons
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6
            Pill { icon: "󰕌"; text: "Undo"; onClicked: Ui.undo(); Probe { name: "settings-undo" } }
            Pill { icon: "󰑎"; text: "Redo"; onClicked: Ui.redo() }
            IconButton { icon: "󰅖"; onClicked: Ui.closeSettings() }
        }
    }

    // ---- Seite (bei jedem Seitenwechsel neu erzeugt, oben beginnend)
    Item {
        id: pageHolder
        anchors { top: head.bottom; topMargin: 14; left: sc.compact ? parent.left : side.right; leftMargin: sc.compact ? 14 : 18; right: parent.right; rightMargin: 14; bottom: parent.bottom; bottomMargin: 14 }
        property var current: null
        Repeater {
            model: [sc.page]
            delegate: SettingsPage {
                id: sp
                required property var modelData
                width: pageHolder.width
                height: pageHolder.height
                page: modelData
                showTitle: modelData.id !== "home"
                // Monitors und Integrations zeigen ihre Werte selbst
                skip: modelData.id === "monitors" ? ["monitors.outputs"]
                    : modelData.id === "dock" ? ["dock.items"]
                    : modelData.id === "integrations" ? (Settings.schema.keys || []).filter(k => k.page === "integrations").map(k => k.key) : []
                extra: modelData.id === "home" ? homeC : modelData.id === "monitors" ? monitorsC : modelData.id === "laptop" ? laptopC : modelData.id === "integrations" ? integrationsC
                     : modelData.id === "about" ? aboutC : modelData.id === "desktop" ? desktopC : modelData.id === "dock" ? dockC
                     : modelData.id === "look" || modelData.id === "theme" ? lookC : null
                footer: modelData.id === "dock" ? dockItemsC
                      : keys.length === 0 && ["home", "about", "monitors", "integrations"].indexOf(modelData.id) < 0 ? emptyC : null
                Component.onCompleted: pageHolder.current = sp
            }
        }
    }
    Component { id: homeC; HomePage { } }
    Component { id: monitorsC; MonitorsPage { } }
    Component { id: aboutC; AboutPage { } }
    Component { id: laptopC; LaptopPage { } }
    Component { id: integrationsC; IntegrationsPage { } }
    Component { id: dockC; DockPage { } }
    Component { id: lookC; LookPage { } }
    Component { id: dockItemsC; DockItemsEditor { } }
    Component {
        id: desktopC
        GlassCard {
            height: 64
            Txt {
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                text: "Move and resize the clock and tiles with the mouse (SUPER + ALT + W)"
                size: 13
            }
            Pill {
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                icon: "󰆾"
                text: "Edit on desktop"
                active: true
                onClicked: Ui.startEdit()
                Probe { name: "edit-on-desktop" }
            }
        }
    }
    Component { id: emptyC; Txt { text: "Nothing to set on this page yet."; sub: true; size: 13 } }

    // ---- Treffer der Suche
    GlassPanel {
        visible: sc.results.length > 0
        x: head.x
        y: head.y + head.height + 6
        z: 10
        width: Math.min(Math.max(search.width, 420), sc.width - x - 14)
        height: resCol.implicitHeight + 16
        radius: 18
        glassOpacity: 0.92
        Column {
            id: resCol
            x: 8; y: 8
            width: parent.width - 16
            Repeater {
                model: sc.results
                delegate: Rectangle {
                    id: res
                    required property var modelData
                    required property int index
                    readonly property var pg: sc.pages.find(p => p.id === modelData.page) || ({ title: modelData.page })
                    width: resCol.width
                    height: 46
                    radius: 12
                    color: rh.hovered ? Theme.cardHover : "transparent"
                    Column {
                        anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        Txt { width: parent.width; text: res.modelData.title + "  ·  " + res.pg.title; size: 13; weight: Font.DemiBold }
                        Txt { width: parent.width; text: res.modelData.key + " – " + res.modelData.description; size: 11; sub: true }
                    }
                    HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: sc.go(res.modelData) }
                    Probe { name: res.index === 0 ? "search-first" : "" }
                }
            }
        }
    }
}
