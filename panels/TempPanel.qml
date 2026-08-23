import QtQuick
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "io.github.arslan.sysmon.temp"

  property var sys: null
  property var anchorItem: null
  property var hostWidget: null

  function tempColor(c) {
    if (c >= 80) return "#ff3333"
    if (c >= 65) return "#ff9933"
    if (c >= 50) return "#ffcc00"
    return "#4da6ff"
  }

  function tempLabel(c) {
    if (c >= 80) return "Critical"
    if (c >= 65) return "Hot"
    if (c >= 50) return "Warm"
    return "Cool"
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
        Text {
          text: sys && sys.tempCurrent / 1000 >= 65 ? "\u{F0510}" : "\u{F050F}"
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          color: tempColor(sys ? sys.tempCurrent / 1000 : 0)
        }
        Text { text: "Temperature"; font.family: Style.font.family; font.pixelSize: Style.font.title; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
      }

      PanelSeparator {}

      Row {
        width: parent.width
        spacing: 8
        Text { text: "Current"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted; width: 90; anchors.verticalCenter: parent.verticalCenter }
        Text {
          text: sys ? Math.round(sys.tempCurrent / 1000) + "\u00B0C" : "-"
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          color: tempColor(sys ? sys.tempCurrent / 1000 : 0)
          anchors.verticalCenter: parent.verticalCenter
        }
        Text { text: sys ? tempLabel(sys.tempCurrent / 1000) : ""; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted; anchors.verticalCenter: parent.verticalCenter }
      }

      Row {
        width: parent.width
        spacing: 8
        Text { text: "Level"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted; width: 82; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
          width: parent.width - 140
          height: 14
          radius: 7
          color: Qt.darker(Color.foreground, 1.6)
          anchors.verticalCenter: parent.verticalCenter
          Rectangle {
            width: parent.width * Math.min(1, (sys ? sys.tempCurrent / 1000 : 0) / 100)
            height: parent.height
            radius: 7
            color: tempColor(sys ? sys.tempCurrent / 1000 : 0)
            Behavior on width { NumberAnimation { duration: 250 } }
          }
        }
      }

      PanelSeparator {}

      Text { text: "Thermal Zones"; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Color.muted }

      Repeater {
        model: sys ? sys.thermalZones.length : 0
        Row {
          required property int index
          width: parent.width
          Text {
            text: sys.thermalZones[index].name
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: Color.muted
            width: 150
            elide: Text.ElideRight
          }
          Text {
            text: Math.round(sys.thermalZones[index].temp / 1000) + "\u00B0C"
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: tempColor(sys.thermalZones[index].temp / 1000)
          }
        }
      }

      Text {
        text: !sys || sys.thermalZones.length === 0 ? "No thermal zones found" : ""
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: Color.muted
        visible: !sys || sys.thermalZones.length === 0
      }
    }
  }
}
