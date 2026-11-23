import QtQuick

// Symbol aus JetBrainsMono Nerd Font
Text {
    property real size: 14
    font.family: Theme.mono
    font.pixelSize: size * Theme.fontScale
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
