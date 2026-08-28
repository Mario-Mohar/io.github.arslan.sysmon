import QtQuick
import QtQuick.Shapes

// Stacked-segment donut for memory: outer ring = RAM (used + cached),
// inner ring = swap. Drawn with PathAngleArc strokes, 12 o'clock start.
Item {
  id: ring

  property real size: 150
  property real usedFrac: 0
  property real cacheFrac: 0
  property bool hasSwap: false
  property real swapPct: 0
  property color trackColor: "#333333"
  property color usedColor: "#4da6ff"
  property color cacheColor: "#ffb800"
  property color swapColor: "#b366ff"
  property color textColor: "#ffffff"
  property color dimColor: "#888888"
  property string fontFamily: ""

  readonly property real strokeW: Math.max(6, size * 0.085)
  readonly property real innerStrokeW: strokeW * 0.65
  readonly property real outerR: (size - strokeW) / 2
  readonly property real innerR: outerR - strokeW / 2 - innerStrokeW / 2 - size * 0.04
  readonly property real cx: size / 2
  readonly property real cy: size / 2
  readonly property real gapDeg: 4
  readonly property real clampedUsed: Math.max(0, Math.min(1, usedFrac))
  readonly property real usedSweep: clampedUsed * 360
  readonly property real cacheSweep: Math.max(0, Math.min(1, cacheFrac)) * 360

  implicitWidth: size
  implicitHeight: size

  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: ring.trackColor
      strokeWidth: ring.strokeW
      fillColor: "transparent"
      PathAngleArc {
        centerX: ring.cx; centerY: ring.cy
        radiusX: ring.outerR; radiusY: ring.outerR
        startAngle: 0; sweepAngle: 360
      }
    }

    ShapePath {
      strokeColor: ring.usedSweep > ring.gapDeg ? ring.usedColor : "transparent"
      strokeWidth: ring.strokeW
      fillColor: "transparent"
      PathAngleArc {
        centerX: ring.cx; centerY: ring.cy
        radiusX: ring.outerR; radiusY: ring.outerR
        startAngle: -90 + ring.gapDeg / 2
        sweepAngle: Math.max(0.5, ring.usedSweep - ring.gapDeg)
      }
    }

    ShapePath {
      strokeColor: ring.cacheSweep > ring.gapDeg ? ring.cacheColor : "transparent"
      strokeWidth: ring.strokeW
      fillColor: "transparent"
      PathAngleArc {
        centerX: ring.cx; centerY: ring.cy
        radiusX: ring.outerR; radiusY: ring.outerR
        startAngle: -90 + ring.usedSweep + ring.gapDeg / 2
        sweepAngle: Math.max(0.5, Math.min(ring.cacheSweep, 360 - ring.usedSweep - ring.gapDeg))
      }
    }

    ShapePath {
      strokeColor: ring.hasSwap ? ring.trackColor : "transparent"
      strokeWidth: ring.innerStrokeW
      fillColor: "transparent"
      PathAngleArc {
        centerX: ring.cx; centerY: ring.cy
        radiusX: ring.innerR; radiusY: ring.innerR
        startAngle: 0; sweepAngle: 360
      }
    }

    ShapePath {
      strokeColor: ring.hasSwap && ring.swapPct > 0 ? ring.swapColor : "transparent"
      strokeWidth: ring.innerStrokeW
      fillColor: "transparent"
      PathAngleArc {
        centerX: ring.cx; centerY: ring.cy
        radiusX: ring.innerR; radiusY: ring.innerR
        startAngle: -90
        sweepAngle: Math.max(1, Math.min(1, ring.swapPct) * 358)
      }
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 0

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Math.round(ring.clampedUsed * 100) + "%"
      textFormat: Text.PlainText
      color: ring.textColor
      font.family: ring.fontFamily
      font.pixelSize: ring.size * 0.19
      font.weight: Font.DemiBold
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "RAM"
      textFormat: Text.PlainText
      color: ring.dimColor
      font.family: ring.fontFamily
      font.pixelSize: ring.size * 0.085
      font.letterSpacing: 1.5
    }
  }
}
