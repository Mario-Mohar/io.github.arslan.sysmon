import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root
  property string caption: ""
  property string value: ""
  property color foreground: "#ffffff"
  property color dim: "#808080"
  property string fontFamily: ""
  spacing: Style.space(4)

  Text {
    text: root.caption
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
  }
  Text {
    text: root.value
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.subtitle
    font.bold: true
  }
}
