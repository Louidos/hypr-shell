import QtQuick

// Text in Inter. Dicke und Grösse kommen aus Theme (theme.font.*):
//   title: true   Überschrift – Theme.titleWeight, Grösse mal Theme.titleScale
//   heavy: true   grosse Zahl oder Wert – dick wie ein Titel, ohne Titelgrösse
//   strong: true  Beschriftung, Pille, Wert – eine Stufe leichter als Titel (Theme.strongWeight)
//   sonst         normaler Text – Theme.textWeight
// weight nur für eine bewusste Ausnahme setzen (mit Kommentar).
Text {
    property real size: 13
    property bool title: false
    property bool heavy: false
    property bool strong: false
    property int weight: title || heavy ? Theme.titleWeight : strong ? Theme.strongWeight : Theme.textWeight
    property bool sub: false
    font.family: Theme.sans
    font.pixelSize: size * Theme.fontScale * (title ? Theme.titleScale : 1)
    font.weight: weight
    color: sub ? Theme.subtext : Theme.text
    elide: Text.ElideRight
}
