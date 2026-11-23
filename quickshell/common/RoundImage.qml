import QtQuick
import Quickshell.Widgets

// Bild mit runden Ecken; ohne Bild erscheint ein Ersatz (z. B. Anfangsbuchstabe).
// Mit Grafikkarte schneidet ClippingRectangle die Ecken rund ab. ClippingRectangle braucht dafür
// einen Shader – ohne Shader (Software-Rendering, z. B. im Oberflächentest der CI) zeichnet es gar
// nichts, auch keine Kinder. Dann erscheint das Bild mit eckigen Ecken. Fläche und Ersatz sind
// normale Rechtecke und Texte, sie erscheinen immer.
Item {
    id: r
    property string source: ""
    property string fallbackText: ""
    property int sourceWidth: 256
    property real radius: 0
    property color color: Theme.card
    // für den Oberflächentest (siehe Probe.qml)
    property string probe: ""
    property int status: Image.Null
    readonly property bool ready: source !== "" && status === Image.Ready
    readonly property bool shader: GraphicsInfo.api !== GraphicsInfo.Software

    Rectangle {
        anchors.fill: parent
        radius: r.radius
        color: r.color
    }
    Txt {
        anchors.centerIn: parent
        visible: !r.ready && r.fallbackText !== ""
        text: r.fallbackText
        size: r.height * 0.42
        weight: Font.Bold
    }
    Loader {
        anchors.fill: parent
        active: r.source !== ""
        sourceComponent: r.shader ? rund : eckig
        onActiveChanged: if (!active) r.status = Image.Null
    }
    Component {
        id: rund
        ClippingRectangle {
            color: "transparent"
            radius: r.radius
            Image {
                anchors.fill: parent
                source: r.source
                sourceSize.width: r.sourceWidth
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
                opacity: 0   // GEGENPROBE, wird zurückgenommen
                onStatusChanged: r.status = status
                Component.onCompleted: r.status = status
                Probe { name: r.probe }
            }
        }
    }
    Component {
        id: eckig
        Image {
            source: r.source
            sourceSize.width: r.sourceWidth
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: status === Image.Ready
            opacity: 0   // GEGENPROBE, wird zurückgenommen
            onStatusChanged: r.status = status
            Component.onCompleted: r.status = status
            Probe { name: r.probe }
        }
    }
}
