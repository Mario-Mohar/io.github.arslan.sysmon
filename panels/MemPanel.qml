import QtQuick
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "io.github.arslan.sysmon.mem"

  property var sys: null
  property var anchorItem: null
  property var hostWidget: null

  function stateColor(val) {
    if (val >= 80) return "#ff3333"
    if (val >= 60) return "#ffb800"
    return "#66ff66"
  }

  function fmtBytes(b) {
    if (!b || b <= 0) return "-"
    if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB"
    if (b >= 1048576) return (b / 1048576).toFixed(0) + " MB"
    return (b / 1024).toFixed(0) + " KB"
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    contentWidth: Style.space(300)
    contentHeight: column.implicitHeight + Style.space(32)

    Column {
      id: column
      width: parent.width
      spacing: 10

      Row {
        spacing: 8
        Text { text: "\u{F046D}"; font.family: Style.font.family; font.pixelSize: Style.font.title; color: "#66ff66" }
        Text { text: "Memory"; font.family: Style.font.family; font.pixelSize: Style.font.title; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
      }

      PanelSeparator {}

      Row {
        width: parent.width
        spacing: 8
        Text { text: "RAM"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted; width: 82; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
          width: parent.width - 140
          height: 14
          radius: 7
          color: Qt.darker(Color.foreground, 1.6)
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            width: parent.width * (sys ? sys.memPercent / 100 : 0)
            height: parent.height
            radius: 7
            color: stateColor(sys ? sys.memPercent : 0)
            Behavior on width { NumberAnimation { duration: 250 } }
          }
        }
        Text { text: sys ? Math.round(sys.memPercent) + "%" : "-"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
      }

      PanelSeparator {}

      Repeater {
        model: [
          { label: "Total", value: fmtBytes(sys ? sys.memTotal : 0) },
          { label: "Used", value: fmtBytes(sys ? sys.memUsed : 0) },
          { label: "Free", value: fmtBytes(sys ? sys.memFree : 0) },
          { label: "Cached", value: fmtBytes(sys ? sys.memCached : 0) }
        ]
        Row {
          required property var modelData
          width: parent.width
          Text { text: modelData.label; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted; width: 90 }
          Text { text: modelData.value; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }
        }
      }

      PanelSeparator {}

      Row {
        width: parent.width
        spacing: 8
        Text { text: "Swap"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted; width: 82; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
          width: parent.width - 140
          height: 10
          radius: 5
          color: Qt.darker(Color.foreground, 1.6)
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            width: parent.width * (sys && sys.swapTotal > 0 ? sys.swapPercent / 100 : 0)
            height: parent.height
            radius: 5
            color: "#66ff66"
            Behavior on width { NumberAnimation { duration: 250 } }
          }
        }
        Text { text: sys && sys.swapTotal > 0 ? Math.round(sys.swapPercent) + "%" : "-"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
      }
    }
  }
}
