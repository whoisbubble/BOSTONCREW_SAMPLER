import QtQuick

Canvas {
    id: icon

    property string name: "play"
    property color lineColor: AppTheme.text

    antialiasing: true

    onNameChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.save()
        ctx.strokeStyle = icon.lineColor
        ctx.fillStyle = icon.lineColor
        ctx.lineWidth = Math.max(1.8, Math.min(width, height) * 0.085)
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        var w = width
        var h = height
        var s = Math.min(w, h)
        var ox = (w - s) / 2
        var oy = (h - s) / 2

        function rr(x, y, rw, rh, r) {
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + rw - r, y)
            ctx.quadraticCurveTo(x + rw, y, x + rw, y + r)
            ctx.lineTo(x + rw, y + rh - r)
            ctx.quadraticCurveTo(x + rw, y + rh, x + rw - r, y + rh)
            ctx.lineTo(x + r, y + rh)
            ctx.quadraticCurveTo(x, y + rh, x, y + rh - r)
            ctx.lineTo(x, y + r)
            ctx.quadraticCurveTo(x, y, x + r, y)
        }

        function line(x1, y1, x2, y2) {
            ctx.beginPath()
            ctx.moveTo(ox + x1 * s, oy + y1 * s)
            ctx.lineTo(ox + x2 * s, oy + y2 * s)
            ctx.stroke()
        }

        function drawThumb() {
            ctx.beginPath()
            ctx.moveTo(ox + 0.20 * s, oy + 0.46 * s)
            ctx.lineTo(ox + 0.34 * s, oy + 0.46 * s)
            ctx.lineTo(ox + 0.44 * s, oy + 0.22 * s)
            ctx.quadraticCurveTo(ox + 0.49 * s, oy + 0.16 * s, ox + 0.54 * s, oy + 0.22 * s)
            ctx.lineTo(ox + 0.52 * s, oy + 0.43 * s)
            ctx.lineTo(ox + 0.76 * s, oy + 0.43 * s)
            ctx.quadraticCurveTo(ox + 0.84 * s, oy + 0.43 * s, ox + 0.82 * s, oy + 0.52 * s)
            ctx.lineTo(ox + 0.75 * s, oy + 0.78 * s)
            ctx.quadraticCurveTo(ox + 0.73 * s, oy + 0.86 * s, ox + 0.64 * s, oy + 0.86 * s)
            ctx.lineTo(ox + 0.34 * s, oy + 0.86 * s)
            ctx.lineTo(ox + 0.20 * s, oy + 0.76 * s)
            ctx.closePath()
            ctx.fill()
        }

        switch (icon.name) {
        case "panel":
            rr(ox + 0.11 * s, oy + 0.13 * s, 0.78 * s, 0.70 * s, 0.11 * s)
            ctx.stroke()
            rr(ox + 0.20 * s, oy + 0.24 * s, 0.22 * s, 0.17 * s, 0.04 * s)
            ctx.fill()
            rr(ox + 0.48 * s, oy + 0.24 * s, 0.32 * s, 0.17 * s, 0.04 * s)
            ctx.fill()
            rr(ox + 0.20 * s, oy + 0.51 * s, 0.20 * s, 0.17 * s, 0.04 * s)
            ctx.fill()
            rr(ox + 0.48 * s, oy + 0.51 * s, 0.32 * s, 0.17 * s, 0.04 * s)
            ctx.stroke()
            break
        case "host":
            rr(ox + 0.12 * s, oy + 0.20 * s, 0.76 * s, 0.48 * s, 0.06 * s)
            ctx.stroke()
            line(0.50, 0.68, 0.50, 0.82)
            line(0.34, 0.82, 0.66, 0.82)
            ctx.beginPath()
            ctx.arc(ox + 0.72 * s, oy + 0.34 * s, 0.055 * s, 0, Math.PI * 2)
            ctx.fill()
            break
        case "thumb-up":
            drawThumb()
            break
        case "thumb-down":
            ctx.translate(w, h)
            ctx.scale(-1, -1)
            drawThumb()
            break
        case "clock":
            ctx.beginPath()
            ctx.arc(ox + 0.50 * s, oy + 0.50 * s, 0.34 * s, 0, Math.PI * 2)
            ctx.stroke()
            line(0.50, 0.50, 0.50, 0.30)
            line(0.50, 0.50, 0.64, 0.62)
            break
        case "pause":
            rr(ox + 0.27 * s, oy + 0.20 * s, 0.15 * s, 0.60 * s, 0.03 * s)
            ctx.fill()
            rr(ox + 0.58 * s, oy + 0.20 * s, 0.15 * s, 0.60 * s, 0.03 * s)
            ctx.fill()
            break
        case "play":
            ctx.beginPath()
            ctx.moveTo(ox + 0.34 * s, oy + 0.22 * s)
            ctx.lineTo(ox + 0.76 * s, oy + 0.50 * s)
            ctx.lineTo(ox + 0.34 * s, oy + 0.78 * s)
            ctx.closePath()
            ctx.fill()
            break
        case "stop":
            rr(ox + 0.25 * s, oy + 0.25 * s, 0.50 * s, 0.50 * s, 0.05 * s)
            ctx.fill()
            break
        case "save":
            rr(ox + 0.18 * s, oy + 0.15 * s, 0.64 * s, 0.70 * s, 0.08 * s)
            ctx.stroke()
            rr(ox + 0.28 * s, oy + 0.18 * s, 0.34 * s, 0.20 * s, 0.03 * s)
            ctx.stroke()
            rr(ox + 0.30 * s, oy + 0.58 * s, 0.40 * s, 0.22 * s, 0.03 * s)
            ctx.fill()
            break
        case "prev":
            line(0.25, 0.24, 0.25, 0.76)
            ctx.beginPath()
            ctx.moveTo(ox + 0.74 * s, oy + 0.22 * s)
            ctx.lineTo(ox + 0.36 * s, oy + 0.50 * s)
            ctx.lineTo(ox + 0.74 * s, oy + 0.78 * s)
            ctx.closePath()
            ctx.fill()
            break
        case "next":
            line(0.75, 0.24, 0.75, 0.76)
            ctx.beginPath()
            ctx.moveTo(ox + 0.26 * s, oy + 0.22 * s)
            ctx.lineTo(ox + 0.64 * s, oy + 0.50 * s)
            ctx.lineTo(ox + 0.26 * s, oy + 0.78 * s)
            ctx.closePath()
            ctx.fill()
            break
        case "image":
            rr(ox + 0.14 * s, oy + 0.20 * s, 0.72 * s, 0.56 * s, 0.06 * s)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(ox + 0.68 * s, oy + 0.34 * s, 0.06 * s, 0, Math.PI * 2)
            ctx.fill()
            ctx.beginPath()
            ctx.moveTo(ox + 0.22 * s, oy + 0.70 * s)
            ctx.lineTo(ox + 0.40 * s, oy + 0.50 * s)
            ctx.lineTo(ox + 0.52 * s, oy + 0.62 * s)
            ctx.lineTo(ox + 0.62 * s, oy + 0.48 * s)
            ctx.lineTo(ox + 0.78 * s, oy + 0.70 * s)
            ctx.stroke()
            break
        case "grid":
            for (var gx = 0; gx < 3; ++gx) {
                for (var gy = 0; gy < 3; ++gy) {
                    rr(ox + (0.18 + gx * 0.23) * s, oy + (0.18 + gy * 0.23) * s, 0.12 * s, 0.12 * s, 0.02 * s)
                    ctx.stroke()
                }
            }
            break
        case "camera":
            rr(ox + 0.18 * s, oy + 0.27 * s, 0.64 * s, 0.50 * s, 0.10 * s)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(ox + 0.50 * s, oy + 0.52 * s, 0.16 * s, 0, Math.PI * 2)
            ctx.stroke()
            line(0.66, 0.22, 0.76, 0.22)
            break
        case "projector":
            rr(ox + 0.18 * s, oy + 0.18 * s, 0.64 * s, 0.42 * s, 0.04 * s)
            ctx.stroke()
            line(0.50, 0.60, 0.50, 0.82)
            line(0.32, 0.82, 0.68, 0.82)
            line(0.40, 0.70, 0.28, 0.82)
            line(0.60, 0.70, 0.72, 0.82)
            break
        case "audio":
            ctx.beginPath()
            ctx.moveTo(ox + 0.20 * s, oy + 0.42 * s)
            ctx.lineTo(ox + 0.36 * s, oy + 0.42 * s)
            ctx.lineTo(ox + 0.55 * s, oy + 0.25 * s)
            ctx.lineTo(ox + 0.55 * s, oy + 0.75 * s)
            ctx.lineTo(ox + 0.36 * s, oy + 0.58 * s)
            ctx.lineTo(ox + 0.20 * s, oy + 0.58 * s)
            ctx.closePath()
            ctx.fill()
            ctx.beginPath()
            ctx.arc(ox + 0.58 * s, oy + 0.50 * s, 0.15 * s, -0.65, 0.65)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(ox + 0.60 * s, oy + 0.50 * s, 0.28 * s, -0.58, 0.58)
            ctx.stroke()
            break
        case "up":
            ctx.beginPath()
            ctx.moveTo(ox + 0.50 * s, oy + 0.24 * s)
            ctx.lineTo(ox + 0.78 * s, oy + 0.58 * s)
            ctx.lineTo(ox + 0.62 * s, oy + 0.58 * s)
            ctx.lineTo(ox + 0.62 * s, oy + 0.78 * s)
            ctx.lineTo(ox + 0.38 * s, oy + 0.78 * s)
            ctx.lineTo(ox + 0.38 * s, oy + 0.58 * s)
            ctx.lineTo(ox + 0.22 * s, oy + 0.58 * s)
            ctx.closePath()
            ctx.fill()
            break
        case "down":
            ctx.beginPath()
            ctx.moveTo(ox + 0.50 * s, oy + 0.76 * s)
            ctx.lineTo(ox + 0.22 * s, oy + 0.42 * s)
            ctx.lineTo(ox + 0.38 * s, oy + 0.42 * s)
            ctx.lineTo(ox + 0.38 * s, oy + 0.22 * s)
            ctx.lineTo(ox + 0.62 * s, oy + 0.22 * s)
            ctx.lineTo(ox + 0.62 * s, oy + 0.42 * s)
            ctx.lineTo(ox + 0.78 * s, oy + 0.42 * s)
            ctx.closePath()
            ctx.fill()
            break
        case "repeat":
            ctx.beginPath()
            ctx.arc(ox + 0.50 * s, oy + 0.50 * s, 0.30 * s, Math.PI * 0.12, Math.PI * 1.38)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(ox + 0.24 * s, oy + 0.32 * s)
            ctx.lineTo(ox + 0.20 * s, oy + 0.56 * s)
            ctx.lineTo(ox + 0.40 * s, oy + 0.46 * s)
            ctx.closePath()
            ctx.fill()
            ctx.beginPath()
            ctx.arc(ox + 0.50 * s, oy + 0.50 * s, 0.30 * s, Math.PI * 1.12, Math.PI * 2.38)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(ox + 0.76 * s, oy + 0.68 * s)
            ctx.lineTo(ox + 0.80 * s, oy + 0.44 * s)
            ctx.lineTo(ox + 0.60 * s, oy + 0.54 * s)
            ctx.closePath()
            ctx.fill()
            break
        case "restart":
            ctx.beginPath()
            ctx.arc(ox + 0.52 * s, oy + 0.52 * s, 0.30 * s, Math.PI * 0.22, Math.PI * 1.75)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(ox + 0.24 * s, oy + 0.30 * s)
            ctx.lineTo(ox + 0.22 * s, oy + 0.54 * s)
            ctx.lineTo(ox + 0.42 * s, oy + 0.42 * s)
            ctx.closePath()
            ctx.fill()
            break
        case "plus":
            line(0.50, 0.20, 0.50, 0.80)
            line(0.20, 0.50, 0.80, 0.50)
            break
        case "edit":
            line(0.24, 0.74, 0.70, 0.28)
            line(0.58, 0.18, 0.82, 0.42)
            line(0.20, 0.80, 0.36, 0.76)
            break
        case "file":
            rr(ox + 0.22 * s, oy + 0.13 * s, 0.56 * s, 0.74 * s, 0.05 * s)
            ctx.stroke()
            line(0.58, 0.13, 0.78, 0.33)
            line(0.34, 0.52, 0.66, 0.52)
            line(0.34, 0.64, 0.62, 0.64)
            break
        case "trash":
            line(0.26, 0.30, 0.74, 0.30)
            line(0.40, 0.20, 0.60, 0.20)
            rr(ox + 0.30 * s, oy + 0.36 * s, 0.40 * s, 0.46 * s, 0.04 * s)
            ctx.stroke()
            line(0.42, 0.46, 0.42, 0.72)
            line(0.58, 0.46, 0.58, 0.72)
            break
        case "folder":
            rr(ox + 0.13 * s, oy + 0.30 * s, 0.74 * s, 0.48 * s, 0.06 * s)
            ctx.stroke()
            line(0.16, 0.34, 0.36, 0.22)
            line(0.36, 0.22, 0.54, 0.30)
            break
        case "check":
            line(0.22, 0.54, 0.42, 0.72)
            line(0.42, 0.72, 0.78, 0.30)
            break
        case "close":
            line(0.24, 0.24, 0.76, 0.76)
            line(0.76, 0.24, 0.24, 0.76)
            break
        case "min":
            line(0.24, 0.62, 0.76, 0.62)
            break
        case "max":
            rr(ox + 0.22 * s, oy + 0.22 * s, 0.56 * s, 0.56 * s, 0.03 * s)
            ctx.stroke()
            break
        case "restore":
            rr(ox + 0.30 * s, oy + 0.18 * s, 0.48 * s, 0.48 * s, 0.03 * s)
            ctx.stroke()
            rr(ox + 0.20 * s, oy + 0.34 * s, 0.46 * s, 0.46 * s, 0.03 * s)
            ctx.stroke()
            break
        default:
            ctx.beginPath()
            ctx.arc(ox + 0.50 * s, oy + 0.50 * s, 0.19 * s, 0, Math.PI * 2)
            ctx.fill()
            break
        }

        ctx.restore()
    }
}
