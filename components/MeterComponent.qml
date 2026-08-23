import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property real value: 0
  property color fillColor: "#ffffff"
  property color trackColor: "#333333"
  property real thickness: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

  function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
  }

  width: parent ? parent.width : implicitWidth
  implicitHeight: thickness

  Rectangle {
    id: meterTrack
    anchors.fill: parent
    radius: height / 2
    color: root.trackColor
  }

  Rectangle {
    anchors.left: meterTrack.left
    anchors.verticalCenter: meterTrack.verticalCenter
    height: meterTrack.height
    radius: meterTrack.radius
    width: meterTrack.width * root.clamp(root.value, 0, 1)
    color: root.fillColor
  }
}
