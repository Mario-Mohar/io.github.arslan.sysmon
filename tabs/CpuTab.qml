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

  component Meter: MeterComponent {
    fillColor: panel.foreground
    trackColor: panel.track
  }

  component Sparkline: SparklineComponent {
    lineColor: panel.foreground
    historyLength: panel.historyLength
  }

  component InfoPair: InfoPairComponent {
    foreground: panel.foreground
    fontFamily: panel.fontFamily
  }

  spacing: Style.space(10)

  SectionRow {
    label: panel.cpu ? panel.cpu.model : "CPU"
    value: panel.cpu ? [Model.mhz(panel.cpu.freq_mhz), Model.temp(panel.cpu.temp)].filter(function(s) { return s !== "—" }).join("  ·  ") : ""
    valueDim: true
  }

  Meter { value: panel.cpu ? panel.cpu.total / 100 : 0; fillColor: panel.stateColor(panel.cpu ? panel.cpu.total : 0) }

  Sparkline {
    width: parent.width
    height: Style.space(56)
    values: panel.cpuHistory
    maxValue: 100
  }

  PanelSectionHeader {
    text: "CORES"
    foreground: panel.foreground
    fontFamily: panel.fontFamily
  }

  Grid {
    id: coreGrid
    width: parent.width
    readonly property int coreCount: panel.cpu ? panel.cpu.cores.length : 0
    columns: coreCount > 32 ? 4 : (coreCount > 12 ? 2 : 1)
    columnSpacing: Style.space(20)
    rowSpacing: Style.space(4)
    readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

    Repeater {
      model: coreGrid.coreCount

      Item {
        required property int index
        width: coreGrid.cellWidth
        implicitHeight: coreLabel.implicitHeight + Style.space(4)

        readonly property real load: panel.cpu ? panel.cpu.cores[index] : 0
        readonly property bool hasTemp: panel.cpu && panel.cpu.core_temps && panel.cpu.core_temps.length === panel.cpu.cores.length
        readonly property var coreTemp: hasTemp ? panel.cpu.core_temps[index] : null

        Text {
          id: coreLabel
          text: "C" + index
          color: panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(28)
        }

        Rectangle {
          anchors.left: coreLabel.right
          anchors.right: coreValue.left
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
          radius: height / 2
          color: panel.track

          Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            radius: parent.radius
            width: parent.width * panel.clamp(load / 100, 0, 1)
            color: panel.stateColor(load)
          }
        }

        Text {
          id: coreValue
          text: Model.percent(load) + (hasTemp ? "  " + (coreTemp === null ? "   " : Model.temp(coreTemp)) : "")
          color: panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignRight
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: hasTemp ? Style.space(76) : Style.space(36)
        }
      }
    }
  }

  PanelSeparator { foreground: panel.foreground }

  Row {
    width: parent.width
    spacing: Style.space(20)

    Column {
      width: (parent.width - parent.spacing) / 2
      spacing: Style.spacing.labelGap
      InfoPair { label: "Load average"; value: panel.snapshot ? Model.loadAvg(panel.snapshot.load) : "—" }
      InfoPair { label: "Cores"; value: panel.cpu ? Model.count(panel.cpu.cores.length) : "—" }
      InfoPair {
        visible: panel.cpu && panel.cpu.power_w !== null && panel.cpu.power_w !== undefined
        label: "Package power"; value: panel.cpu ? Model.watts(panel.cpu.power_w) : "—"
      }
    }

    Column {
      width: (parent.width - parent.spacing) / 2
      spacing: Style.spacing.labelGap
      InfoPair { label: "Uptime"; value: panel.snapshot ? Model.uptime(panel.snapshot.uptime) : "—" }
      InfoPair {
        visible: panel.cpu && panel.cpu.fans && panel.cpu.fans.length > 0
        label: panel.cpu && panel.cpu.fans && panel.cpu.fans.length > 1 ? "Fans" : "Fan"
        value: {
          if (!panel.cpu || !panel.cpu.fans) return "—"
          var spinning = panel.cpu.fans.filter(function(f) { return f.rpm > 0 })
          if (spinning.length === 0) return "idle"
          return spinning.map(function(f) { return f.rpm + " rpm" }).join(" · ")
        }
      }
    }
  }
}
