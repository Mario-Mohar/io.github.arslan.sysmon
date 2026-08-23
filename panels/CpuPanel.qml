import QtQuick
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "io.github.arslan.sysmon.cpu"

  property var sys: null
  property var anchorItem: null
  property var hostWidget: null

  function stateColor(val) {
    if (val >= 80) return "#ff3333"
    if (val >= 60) return "#ffb800"
    return "#4da6ff"
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

      // Header
      Row {
        spacing: 8
        Text { text: "\u{F035B}"; font.family: Style.font.family; font.pixelSize: Style.font.title; color: "#4da6ff" }
        Text { text: "CPU"; font.family: Style.font.family; font.pixelSize: Style.font.title; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
      }

      PanelSeparator {}

      Row {
        width: parent.width
        Text { text: "Frequency"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted; width: 90 }
        Text { text: sys ? sys.cpuFreqGhz + " GHz" : "-"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }
      }

      Row {
        width: parent.width
        Text { text: "Load"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted; width: 90 }
        Text { text: sys && sys.loadAvg ? sys.loadAvg[0].toFixed(2) + "  " + sys.loadAvg[1].toFixed(2) + "  " + sys.loadAvg[2].toFixed(2) : "-"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground }
      }

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
            width: parent.width * (sys ? sys.cpuPercent / 100 : 0)
            height: parent.height
            radius: 7
            color: stateColor(sys ? sys.cpuPercent : 0)
            Behavior on width { NumberAnimation { duration: 250 } }
          }
        }
        Text { text: sys ? Math.round(sys.cpuPercent) + "%" : "-"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
      }

      PanelSeparator {}

      Repeater {
        model: sys ? sys.corePercents.length : 0
        Row {
          width: parent.width
          spacing: 8
          required property int index
          Text {
            text: "Core " + index
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: Color.muted
            width: 60
            anchors.verticalCenter: parent.verticalCenter
          }
          Rectangle {
            width: parent.width - 130
            height: 10
            radius: 5
            color: Qt.darker(Color.foreground, 1.6)
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
              width: parent.width * ((sys && sys.corePercents[parent.parent.index]) ? sys.corePercents[parent.parent.index] / 100 : 0)
              height: parent.height
              radius: 5
              color: stateColor(sys && sys.corePercents[parent.parent.index] ? sys.corePercents[parent.parent.index] : 0)
              Behavior on width { NumberAnimation { duration: 250 } }
            }
          }
          Text {
            text: (sys && sys.corePercents[index] !== undefined ? Math.round(sys.corePercents[index]) : 0) + "%"
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: Color.foreground
            width: 36
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
