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

  component StatCell: StatCellComponent {
    foreground: panel.foreground
    dim: panel.dim
    fontFamily: panel.fontFamily
  }

  component Sparkline: SparklineComponent {
    lineColor: panel.foreground
    historyLength: panel.historyLength
  }

  spacing: Style.space(10)

  Text {
    visible: panel.hasData && panel.ifaces.length === 0
    text: "No network interfaces found"
    color: panel.dim
    font.family: panel.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  // Interface picker, only when there is a choice to make.
  Row {
    id: ifaceRow
    visible: panel.ifaces.length > 1
    width: parent.width
    spacing: Style.space(6)

    readonly property int count: Math.min(panel.ifaces.length, 5)
    readonly property real cellWidth: count > 0 ? (width - spacing * (count - 1)) / count : 0

    Repeater {
      model: panel.ifaces.slice(0, 5)

      Button {
        required property var modelData
        width: ifaceRow.cellWidth
        text: modelData.name
        fontSize: Style.font.caption
        foreground: modelData.up ? panel.foreground : panel.dim
        fontFamily: panel.fontFamily
        horizontalPadding: Style.space(4)
        verticalPadding: Style.spacing.controlPaddingY
        bordered: true
        active: panel.iface && panel.iface.name === modelData.name
        onClicked: panel.selectIface(modelData.name)
      }
    }
  }

  SectionRow {
    visible: !!panel.iface
    label: panel.iface ? (panel.iface.ssid || panel.iface.name) : ""
    value: {
      if (!panel.iface) return ""
      var bits = []
      if (panel.iface.ssid) bits.push(panel.iface.name)
      if (panel.iface.ip) bits.push(panel.iface.ip)
      if (!panel.iface.up) bits.push("down")
      return bits.join("  ·  ")
    }
    valueDim: true
  }

  Row {
    visible: !!panel.iface
    width: parent.width
    spacing: 0
    readonly property real cellWidth: width / 4

    StatCell { width: parent.cellWidth; caption: "RECEIVING"; value: panel.iface ? Model.rate(panel.iface.rx_bps) : "—" }
    StatCell { width: parent.cellWidth; caption: "SENDING"; value: panel.iface ? Model.rate(panel.iface.tx_bps) : "—" }
    StatCell { width: parent.cellWidth; caption: "DOWNLOADED"; value: panel.iface ? Model.bytes(panel.iface.rx_total) : "—" }
    StatCell { width: parent.cellWidth; caption: "UPLOADED"; value: panel.iface ? Model.bytes(panel.iface.tx_total) : "—" }
  }

  Sparkline {
    visible: !!panel.iface
    width: parent.width
    height: Style.space(72)
    values: panel.rxHistory
    values2: panel.txHistory
    maxValue: 0
  }

  Item {
    visible: !!panel.iface
    width: parent.width
    implicitHeight: legendLeft.implicitHeight

    Row {
      id: legendLeft
      spacing: Style.space(14)
      anchors.left: parent.left

      Row {
        spacing: Style.space(6)
        Rectangle { width: Style.space(10); height: 2; radius: 1; color: panel.foreground; anchors.verticalCenter: parent.verticalCenter }
        Text { text: "download"; color: panel.dim; font.family: panel.fontFamily; font.pixelSize: Style.font.caption }
      }
      Row {
        spacing: Style.space(6)
        Rectangle { width: Style.space(10); height: 2; radius: 1; color: panel.alpha(panel.foreground, 0.45); anchors.verticalCenter: parent.verticalCenter }
        Text { text: "upload"; color: panel.dim; font.family: panel.fontFamily; font.pixelSize: Style.font.caption }
      }
    }

    Text {
      anchors.right: parent.right
      text: "peak " + Model.rate(Math.max(Model.maxOf(panel.rxHistory, 0), Model.maxOf(panel.txHistory, 0)))
      color: panel.dim
      font.family: panel.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  PanelSeparator { visible: panel.ifaces.length > 1; foreground: panel.foreground }

  // The other interfaces at a glance.
  Column {
    visible: panel.ifaces.length > 1
    width: parent.width
    spacing: Style.spacing.labelGap

    Repeater {
      model: panel.ifaces

      Item {
        required property var modelData
        visible: !panel.iface || modelData.name !== panel.iface.name
        width: parent.width
        implicitHeight: visible ? otherName.implicitHeight : 0

        Text {
          id: otherName
          text: modelData.name + (modelData.ip ? "  " + modelData.ip : "")
          color: modelData.up ? panel.foreground : panel.dim
          opacity: modelData.up ? 0.75 : 1
          font.family: panel.fontFamily
          font.pixelSize: Style.font.bodySmall
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: modelData.up ? "󰇚 " + Model.rate(modelData.rx_bps) + "   󰕒 " + Model.rate(modelData.tx_bps) : "down"
          color: panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }
  }
}
