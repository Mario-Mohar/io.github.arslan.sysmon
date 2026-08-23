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

  spacing: Style.space(12)

  Text {
    visible: panel.hasData && panel.gpus.length === 0
    text: "No GPU detected"
    color: panel.dim
    font.family: panel.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Repeater {
    model: panel.gpus

    Column {
      required property var modelData
      required property int index
      width: parent.width
      spacing: Style.space(10)

      readonly property bool hasBusy: modelData.busy !== null && modelData.busy !== undefined

      PanelSeparator { visible: index > 0; foreground: panel.foreground }

      SectionRow {
        label: modelData.name
        value: {
          var bits = []
          if (hasBusy) bits.push(Model.percent(modelData.busy))
          if (modelData.temp !== null && modelData.temp !== undefined) bits.push(Model.temp(modelData.temp))
          return bits.join("  ·  ")
        }
        valueDim: false
      }

      Meter { visible: hasBusy; value: hasBusy ? modelData.busy / 100 : 0; fillColor: panel.stateColor(hasBusy ? modelData.busy : 0) }

      Sparkline {
        visible: index === 0 && hasBusy
        width: parent.width
        height: Style.space(56)
        values: panel.gpuHistory
        maxValue: 100
      }

      Row {
        width: parent.width
        spacing: Style.space(20)

        Column {
          width: (parent.width - parent.spacing) / 2
          spacing: Style.spacing.labelGap
          InfoPair { visible: value !== "—"; label: "Frequency"; value: Model.mhz(modelData.freq_mhz) }
          InfoPair { visible: value !== "—"; label: "Temperature"; value: Model.temp(modelData.temp) }
          InfoPair {
            visible: modelData.mem_total !== null && modelData.mem_total !== undefined && modelData.mem_total > 0
            label: "Memory"; value: Model.bytes(modelData.mem_used) + " of " + Model.bytes(modelData.mem_total)
          }
        }
        Column {
          width: (parent.width - parent.spacing) / 2
          spacing: Style.spacing.labelGap
          InfoPair { visible: value !== "—"; label: "Max frequency"; value: Model.mhz(modelData.max_freq_mhz) }
          InfoPair { visible: value !== "—"; label: "Power"; value: Model.watts(modelData.power_w) }
          InfoPair { visible: value !== "—"; label: "Vendor"; value: Model.gpuVendorLabel(modelData.vendor) || "—" }
        }
      }
    }
  }
}
