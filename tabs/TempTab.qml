import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../Model.js" as Model
import "../components"

Column {
  required property var panel

  component SectionRow: SectionRowComponent {
    foreground: panel.foreground
    dim: panel.dim
    fontFamily: panel.fontFamily
  }

  component Sparkline: SparklineComponent {
    lineColor: panel.foreground
    historyLength: panel.historyLength
  }

  spacing: Style.space(10)

  SectionRow {
    label: "Temperature"
    value: panel.cpu && panel.cpu.temp !== null && panel.cpu.temp !== undefined ? Model.temp(panel.cpu.temp) : ""
    valueDim: true
  }

  Sparkline {
    width: parent.width
    height: Style.space(56)
    values: panel.tempHistory
    maxValue: 100
  }

  Row {
    visible: panel.currentTempBand >= 0
    spacing: Style.space(6)

    Rectangle {
      width: Style.space(8)
      height: width
      radius: width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: panel.tempBands[panel.currentTempBand >= 0 ? panel.currentTempBand : 0].color
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: panel.currentTempBand >= 0 ? "Thermal status \u00B7 " + panel.tempBands[panel.currentTempBand].label : ""
      color: panel.dim
      font.family: panel.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Row {
    id: tempStatRow
    width: parent.width
    spacing: Style.space(20)

    Repeater {
      model: [
        { l: "NOW", v: panel.cpu && panel.cpu.temp !== null && panel.cpu.temp !== undefined ? Model.temp(panel.cpu.temp) : "\u2014", band: true },
        { l: "MIN", v: panel.tempStats ? Model.temp(panel.tempStats.min) : "\u2014" },
        { l: "AVG", v: panel.tempStats ? Model.temp(panel.tempStats.avg) : "\u2014" },
        { l: "PEAK", v: panel.tempStats ? Model.temp(panel.tempStats.max) : "\u2014" }
      ]

      delegate: Column {
        required property int index
        required property var modelData
        width: (tempStatRow.width - tempStatRow.spacing * 3) / 4
        spacing: 2

        Text {
          text: modelData.l
          color: panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          text: modelData.v
          color: modelData.band && panel.currentTempBand >= 0 ? panel.tempBands[panel.currentTempBand].color : panel.foreground
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }

  PanelSeparator { foreground: panel.foreground }

  PanelSectionHeader {
    text: "DEVICES"
    foreground: panel.foreground
    fontFamily: panel.fontFamily
  }

  // Cross-device glance. Each row jumps to the tab that owns the details,
  // so temperatures are never duplicated across tabs.
  Repeater {
    model: {
      var rows = []
      var gpus = panel.gpus || []
      for (var i = 0; i < gpus.length; i++) {
        var g = gpus[i]
        if (g && g.temp !== null && g.temp !== undefined)
          rows.push({ label: gpus.length > 1 ? "GPU " + (i + 1) : "GPU", value: Model.temp(g.temp), tab: "gpu", target: "GPU" })
      }
      if (panel.snapshot && panel.snapshot.nvme_temp !== null && panel.snapshot.nvme_temp !== undefined)
        rows.push({ label: "NVMe", value: Model.temp(panel.snapshot.nvme_temp), tab: "disk", target: "Disk" })
      return rows
    }

    delegate: Item {
      required property int index
      required property var modelData
      width: parent.width
      implicitHeight: devLabel.implicitHeight

      Text {
        id: devLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: modelData.label
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        anchors.right: devJump.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: modelData.value
        color: panel.foreground
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        id: devJump
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "\u2192 " + modelData.target
        color: panel.dim
        opacity: devArea.containsMouse ? 1 : 0.55
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      MouseArea {
        id: devArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: panel.showTab(modelData.tab)
      }
    }
  }

  Text {
    visible: (panel.gpus || []).length === 0 && !(panel.snapshot && panel.snapshot.nvme_temp !== null && panel.snapshot.nvme_temp !== undefined)
    width: parent.width
    text: "No device sensors detected"
    color: panel.dim
    font.family: panel.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    width: parent.width
    horizontalAlignment: Text.AlignRight
    text: (panel.cpu && panel.cpu.temp_source ? panel.cpu.temp_source : "hwmon") + " \u00B7 every " + panel.refreshSeconds + "s \u00B7 window " + panel.historyLength + " samples"
    color: panel.dim
    opacity: 0.7
    font.family: panel.fontFamily
    font.pixelSize: Style.font.caption
  }
}
