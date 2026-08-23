import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property string glyphText: ""
  property string title: ""
  property real titleSize: Style.font.caption
  property string meta: ""
  property color accent: "#808080"
  property color foreground: "#ffffff"
  property color dim: "#808080"
  property string fontFamily: ""

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(headingGlyph.implicitHeight, headingName.implicitHeight)

  Text {
    id: headingGlyph
    text: root.glyphText
    color: root.accent
    font.family: Style.font.family
    font.pixelSize: Style.font.caption + 2
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
  }

  Text {
    id: headingName
    text: root.title
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.titleSize
    elide: Text.ElideRight
    anchors.left: headingGlyph.right
    anchors.leftMargin: Style.space(8)
    anchors.right: headingMeta.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
  }

  Text {
    id: headingMeta
    text: root.meta
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
  }
}
