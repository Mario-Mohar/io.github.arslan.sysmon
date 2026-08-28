import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Item {
  id: root
  property string label: ""
  property real amount: 0
  property real total: 1
  property bool strong: false
  property color foreground: "#ffffff"
  property color dim: "#808080"
  property color track: "#333333"
  property string fontFamily: ""

  function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
  }

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(shareLabel.implicitHeight, shareValue.implicitHeight) + Style.spacing.sm

  Text {
    id: shareLabel
    text: root.label
    textFormat: Text.PlainText
    color: root.strong ? root.foreground : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: root.strong
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(76)
  }

  Rectangle {
    anchors.left: shareLabel.right
    anchors.right: shareValue.left
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
    radius: height / 2
    color: root.track

    Rectangle {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height
      radius: parent.radius
      width: parent.width * root.clamp(root.total > 0 ? root.amount / root.total : 0, 0, 1)
      color: root.strong ? root.foreground : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
    }
  }

  Text {
    id: shareValue
    text: Model.bytes(root.amount)
    textFormat: Text.PlainText
    color: root.strong ? root.foreground : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: root.strong
    horizontalAlignment: Text.AlignRight
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(70)
  }
}
