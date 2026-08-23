import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property string label: ""
  property string value: ""
  property bool valueDim: false
  property color foreground: "#ffffff"
  property color dim: "#808080"
  property string fontFamily: ""

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(sectionLabel.implicitHeight, sectionValue.implicitHeight)

  Text {
    id: sectionLabel
    text: root.label
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
    anchors.left: parent.left
    anchors.right: sectionValue.left
    anchors.rightMargin: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
  }

  Text {
    id: sectionValue
    text: root.value
    color: root.valueDim ? root.dim : root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.valueDim ? Style.font.caption : Style.font.body
    font.bold: !root.valueDim
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
  }
}
