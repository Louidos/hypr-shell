import QtQuick
import Quickshell
import "../common"

// Desktop-Widgets hinter den Fenstern: grosse Uhr und Auslastungs-Ringe.
Scope {
    id: d
    readonly property var screen: Settings.screenFor(Settings.get("desktop.screen", ""))

    ClockWidget {
        screen: d.screen
        visible: d.screen !== null && Settings.get("desktop.clock.enabled", true)
    }
    ResourcesWidget {
        screen: d.screen
        visible: d.screen !== null && Settings.get("desktop.resources.enabled", true)
    }
}
