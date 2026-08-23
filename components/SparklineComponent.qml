import QtQuick
import "../Model.js" as Model

Canvas {
  id: spark

  property var values: []
  property var values2: []
  property real maxValue: 100     // <= 0 means autoscale to the data
  property color lineColor: "#ffffff"
  property int historyLength: 120

  function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
  }

  onValuesChanged: requestPaint()
  onValues2Changed: requestPaint()
  onLineColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var w = width, h = height
    var cap = spark.historyLength
    var pad = 2
    var peak = spark.maxValue > 0 ? spark.maxValue : Math.max(Model.maxOf(spark.values, 0), Model.maxOf(spark.values2, 0))
    if (peak <= 0) peak = 1
    var fgc = String(spark.lineColor)

    // Faint baseline so an idle machine still reads as "a graph".
    ctx.globalAlpha = 0.12
    ctx.strokeStyle = fgc
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(0, h - 0.5)
    ctx.lineTo(w, h - 0.5)
    ctx.stroke()

    function drawSeries(vals, alphaLine, alphaFill) {
      var n = vals.length
      if (n < 2) return
      var step = w / Math.max(1, cap - 1)
      function x(i) { return w - (n - 1 - i) * step }
      function y(v) { return pad + (1 - spark.clamp(v / peak, 0, 1)) * (h - pad * 2) }

      ctx.beginPath()
      ctx.moveTo(x(0), y(vals[0]))
      for (var i = 1; i < n; i++) ctx.lineTo(x(i), y(vals[i]))
      ctx.lineTo(x(n - 1), h)
      ctx.lineTo(x(0), h)
      ctx.closePath()
      ctx.globalAlpha = alphaFill
      ctx.fillStyle = fgc
      ctx.fill()

      ctx.beginPath()
      ctx.moveTo(x(0), y(vals[0]))
      for (i = 1; i < n; i++) ctx.lineTo(x(i), y(vals[i]))
      ctx.globalAlpha = alphaLine
      ctx.strokeStyle = fgc
      ctx.lineWidth = 1.5
      ctx.lineJoin = "round"
      ctx.stroke()
    }

    drawSeries(spark.values2 || [], 0.45, 0.04)
    drawSeries(spark.values || [], 1, 0.08)
  }
}
