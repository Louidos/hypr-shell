import QtQuick

// Ring 0–100 %, beginnt oben und läuft im Uhrzeigersinn.
Canvas {
    id: r
    property real value: 0
    property real thickness: 4
    property color color: Theme.text
    property color trackColor: Theme.track
    property real shown: Math.max(0, Math.min(100, value))
    Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    onShownChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const g = getContext("2d")
        g.reset()
        const rad = Math.min(width, height) / 2 - thickness / 2 - 0.5
        if (rad <= 1) return
        const cx = width / 2, cy = height / 2, start = -Math.PI / 2
        g.lineWidth = thickness
        g.lineCap = "round"
        g.strokeStyle = trackColor
        g.beginPath(); g.arc(cx, cy, rad, 0, 2 * Math.PI); g.stroke()
        if (shown > 0.5) {
            g.strokeStyle = color
            g.beginPath(); g.arc(cx, cy, rad, start, start + 2 * Math.PI * shown / 100); g.stroke()
        }
    }
}
