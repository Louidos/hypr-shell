import QtQuick
import "../common"

// Eine Seite der App: Titel, Erklärung, "Reset page" und die Abschnitte mit ihren Zeilen –
// alles aus dem Schema. Eigene Inhalte (Home, Monitors, Keybinds, About) kommen über extra/footer.
Flickable {
    id: pg
    property var page: ({})
    property Component extra: null      // über den Abschnitten
    property Component footer: null     // unter den Abschnitten
    property var skip: []               // Schlüssel, die die Seite selbst zeigt
    property bool showTitle: true
    readonly property var keys: (Settings.schema.keys || []).filter(k => k.page === page.id && skip.indexOf(k.key) < 0 && Ui.can(k.requires))
    readonly property var sections: {
        const r = []
        for (let i = 0; i < keys.length; i++) if (r.indexOf(keys[i].section) < 0) r.push(keys[i].section)
        return r
    }
    readonly property var changedKeys: keys.filter(k => {
        const v = Settings.rawValue(k.key)
        return v !== undefined && JSON.stringify(v) !== JSON.stringify(k.default)
    }).map(k => k.key)
    property var rows: ({})

    contentWidth: width
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // zu einem Wert springen (Suche) und ihn kurz aufleuchten lassen
    function focusKey(k) {
        const r = rows[k]
        if (!r) return false
        const y = r.mapToItem(col, 0, 0).y
        contentY = Math.max(0, Math.min(y - 24, contentHeight - height))
        r.flash = true
        return true
    }

    Column {
        id: col
        x: 4
        y: 8
        width: pg.width - 8
        spacing: 12

        Item {
            width: parent.width
            visible: pg.showTitle || resetPage.visible
            height: visible ? titleCol.implicitHeight : 0
            Column {
                id: titleCol
                anchors { left: parent.left; right: resetPage.left; rightMargin: 12 }
                spacing: 4
                visible: pg.showTitle
                Txt { text: pg.page.title || ""; size: 26; weight: Font.Bold }
                Txt { width: parent.width; text: pg.page.description || ""; sub: true; size: 13; wrapMode: Text.WordWrap; elide: Text.ElideNone }
            }
            Pill {
                id: resetPage
                anchors { right: parent.right; top: parent.top; topMargin: 4 }
                visible: pg.changedKeys.length > 0
                icon: "󰑓"
                text: "Reset page"
                onClicked: Ui.reset(pg.changedKeys)
                Probe { name: "reset-page" }
            }
        }

        Loader {
            width: parent.width
            active: pg.extra !== null
            visible: active
            sourceComponent: pg.extra
        }

        Repeater {
            model: pg.sections
            delegate: Column {
                id: sec
                required property string modelData
                width: col.width
                spacing: 8
                Txt { topPadding: 8; text: sec.modelData; size: 13; weight: Font.Bold; color: Theme.subtext }
                Repeater {
                    model: pg.keys.filter(k => k.section === sec.modelData)
                    delegate: SettingRow {
                        id: srow
                        required property var modelData
                        width: sec.width
                        spec: modelData
                        Component.onCompleted: pg.rows[modelData.key] = srow
                    }
                }
            }
        }

        Loader {
            width: parent.width
            active: pg.footer !== null
            visible: active
            sourceComponent: pg.footer
        }
    }
}
