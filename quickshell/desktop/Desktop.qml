import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

// Desktop-Widgets hinter den Fenstern: grosse Uhr und Auslastungs-Kacheln, dazu der
// Bearbeiten-Modus zum Verschieben und Skalieren (SUPER+ALT+W).
Scope {
    id: d
    readonly property var screen: Settings.screenFor(Settings.get("desktop.screen", ""))

    IpcHandler {
        target: "desktop"
        function edit(): void { Ui.startEdit() }
        function done(): void { if (Ui.editDesktop) Ui.finishEdit() }
        function cancel(): void { Ui.cancelEdit() }
    }

    ClockWidget {
        id: clock
        screen: d.screen
        visible: d.screen !== null && Settings.get("desktop.clock.enabled", true)
    }
    ResourcesWidget {
        id: tiles
        screen: d.screen
        visible: d.screen !== null && Settings.get("desktop.resources.enabled", true)
    }
    EditOverlay {
        screen: d.screen
        hasScreen: d.screen !== null
        clockWin: clock
        tilesWin: tiles
    }
}
