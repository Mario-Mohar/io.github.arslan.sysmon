import QtQuick
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "io.github.arslan.sysmon.disk"

  property var sys: null
  property var anchorItem: null
  property var hostWidget: null

  function stateColor(val) {
    if (val >= 80) return "#ff3333"
    if (val >= 60) return "#ffb800"
    return "#ffffff"
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
        Text { text: "\u{F02CA}"; font.family: Style.font.family; font.pixelSize: Style.font.title; color: stateColor(sys ? sys.diskPercent : 0) }
        Text { text: "Disk"; font.family: Style.font.family; font.pixelSize: Style.font.title; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
      }

      PanelSeparator {}

      Row {
        width: parent.width
        spacing: 8
        Text { text: "Usage"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted; width: 82; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
          width: parent.width - 140
          height: 14
          radius: 7
          color: Qt.darker(Color.foreground, 1.6)
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            width: parent.width * (sys ? sys.diskPercent / 100 : 0)
            height: parent.height
            radius: 7
            color: stateColor(sys ? sys.diskPercent : 0)
            Behavior on width { NumberAnimation { duration: 250 } }
          }
        }
        Text { text: sys ? Math.round(sys.diskPercent) + "%" : "-"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
      }

      PanelSeparator {}

      Repeater {
        model: [
          { label: "Total", value: fmtBytes(sys ? sys.diskTotal : 0) },
          { label: "Used", value: fmtBytes(sys ? sys.diskUsed : 0) },
          { label: "Free", value: fmtBytes(sys && sys.diskTotal > 0 ? sys.diskTotal - sys.diskUsed : 0) }
        ]
        Row {
          required property var modelData
          width: parent.width
          Text { text: modelData.label; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted; width: 90 }
          Text { text: modelData.value; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }
        }
      }
    }
  }
}
