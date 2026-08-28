import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../Model.js" as Model
import "../components"
import ".."

Column {
  required property var panel

  component SectionRow: SectionRowComponent {
    foreground: panel.foreground
    dim: panel.dim
    fontFamily: panel.fontFamily
  }

  spacing: Style.space(10)

  SectionRow {
    label: "Memory"
    value: panel.mem ? Model.bytes(panel.mem.used) + " of " + Model.bytes(panel.mem.total) : ""
    valueDim: true
  }

  Row {
    width: parent.width
    spacing: Style.space(24)

    MemRing {
      id: memRing
      width: Style.space(148)
      height: width
      size: width
      usedFrac: panel.mem && panel.mem.total > 0 ? panel.mem.used / panel.mem.total : 0
      cacheFrac: panel.mem && panel.mem.total > 0 ? Math.min(1, (panel.mem.cached + panel.mem.buffers) / panel.mem.total) : 0
      hasSwap: panel.mem && panel.mem.swap_total > 0
      swapPct: panel.mem && panel.mem.swap_total > 0 ? panel.mem.swap_used / panel.mem.swap_total : 0
      trackColor: panel.track
      textColor: panel.foreground
      dimColor: panel.dim
      fontFamily: panel.fontFamily
    }

    Column {
      width: parent.width - memRing.width - parent.spacing
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)

      Repeater {
        model: [
          { c: memRing.usedColor, l: "Used", v: panel.mem ? Model.bytes(panel.mem.used) : "\u2014", strong: true },
          { c: memRing.cacheColor, l: "Cached + Buffers", v: panel.mem ? Model.bytes((panel.mem.cached || 0) + (panel.mem.buffers || 0)) : "\u2014" },
          { c: memRing.trackColor, l: "Free", v: panel.mem ? Model.bytes(Math.max(0, panel.mem.total - panel.mem.used - (panel.mem.cached || 0) - (panel.mem.buffers || 0))) : "\u2014" },
          { c: memRing.swapColor, l: "Swap", v: panel.mem && panel.mem.swap_total > 0 ? Model.bytes(panel.mem.swap_used) + " / " + Model.bytes(panel.mem.swap_total) : "none" }
        ]

        delegate: Row {
          required property int index
          required property var modelData
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(8)
            height: Style.space(8)
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: modelData.c
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.l
            textFormat: Text.PlainText
            color: panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
            width: Style.space(108)
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.v
            textFormat: Text.PlainText
            color: modelData.strong ? panel.foreground : panel.dim
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
