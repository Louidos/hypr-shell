import QtQuick
import Quickshell.Widgets

// Bild mit runden Ecken; ohne Bild erscheint ein Ersatz (z. B. Anfangsbuchstabe).
ClippingRectangle {
    id: r
    property string source: ""
    property string fallbackText: ""
    property int sourceWidth: 256
    readonly property bool ready: img.status === Image.Ready
    color: Theme.card
    Image {
        id: img
        anchors.fill: parent
        source: r.source
        sourceSize.width: r.sourceWidth
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: r.ready
    }
    Txt {
        anchors.centerIn: parent
        visible: !r.ready
        text: r.fallbackText
        size: r.height * 0.42
        weight: Font.Bold
    }
}
