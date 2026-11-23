import QtQuick

// Text in Inter
Text {
    property real size: 13
    property int weight: Font.Normal
    property bool sub: false
    font.family: Theme.sans
    font.pixelSize: size * Theme.fontScale
    font.weight: weight
    color: sub ? Theme.subtext : Theme.text
    elide: Text.ElideRight
}
