import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property string key: ""
  property string text: ""
  property bool alignRight: false
  property bool activeSort: false
  property bool sortReverse: false
  property color foreground: "#ffffff"
  property color faint: "#808080"
  property string fontFamily: ""

  signal sortRequested(string key)

  height: parent ? parent.height : Style.space(20)

  Text {
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: root.alignRight ? undefined : parent.left
    anchors.leftMargin: Style.space(6)
    anchors.right: root.alignRight ? parent.right : undefined
    anchors.rightMargin: Style.space(6)
    text: root.text.toUpperCase() + (root.activeSort ? (root.sortReverse ? " ▲" : " ▼") : "")
    textFormat: Text.PlainText
    color: root.activeSort || headerHover.containsMouse ? root.foreground : root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
  }

  MouseArea {
    id: headerHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.sortRequested(root.key)
  }
}
