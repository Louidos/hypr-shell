import QtQuick
import QtQuick.Effects
import "../common"

// dock.icon_style = theme: Symbole in der Farbe des Hintergrundbilds getönt
MultiEffect {
    saturation: -0.6
    colorization: 0.55
    colorizationColor: Theme.accent
}
