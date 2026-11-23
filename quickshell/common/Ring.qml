import QtQuick

// Ring 0–100 %, beginnt oben und läuft im Uhrzeigersinn.
// gapped: offene Lücke unten (Anzeige wie ein Tacho), beginnt dann unten links.
Canvas {
    id: r
    property real value: 0
    property real thickness: 4
    property bool gapped: false
    property color color: Theme.text
    property color trackColor: Theme.track
    property real shown: Math.max(0, Math.min(100, value))
    Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    onShownChanged: requestPaint()
    onColorChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const g = getContext("2d")
        g.reset()
        const rad = Math.min(width, height) / 2 - thickness / 2 - 0.5
        if (rad <= 1) return
        const cx = width / 2, cy = height / 2
        const gap = gapped ? 0.18 * Math.PI : 0
        const start = gapped ? Math.PI / 2 + gap : -Math.PI / 2
        const span = 2 * Math.PI - 2 * gap
        const v = shown / 100
        g.lineWidth = thickness
        g.lineCap = "round"
        g.strokeStyle = trackColor
        g.beginPath()
        if (gapped) g.arc(cx, cy, rad, start + span * v + (v > 0.005 ? 0.25 : 0), start + span)
        else g.arc(cx, cy, rad, 0, 2 * Math.PI)
        g.stroke()
        if (v > 0.005) {
            g.strokeStyle = color
            g.beginPath(); g.arc(cx, cy, rad, start, start + span * v); g.stroke()
        }
    }
}
