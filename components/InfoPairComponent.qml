import QtQuick
import qs.Commons
import qs.Ui

Row {
  id: root
  property string label: ""
  property string value: ""
  property color foreground: "#ffffff"
  property string fontFamily: ""

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(8)

  Text {
    id: pairLabel
    text: root.label
    textFormat: Text.PlainText
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Item {
    width: Math.max(0, parent.width - pairLabel.implicitWidth - pairValue.implicitWidth - parent.spacing * 2)
    height: 1
  }

  Text {
    id: pairValue
    text: root.value
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
