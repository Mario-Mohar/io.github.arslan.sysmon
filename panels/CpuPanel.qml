import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../format.js" as Fmt

// CPU detail panel — cores, frequency, load average, usage sparkline.
Panel {
  id: root
  moduleName: "io.github.arslan.sysmon.cpu"
  ipcTarget: "io.github.arslan.sysmon.cpu"

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false
  readonly property string icon: "\uf4bc"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color faint: Qt.darker(foreground, 1.4)

  // Reference to core data — walk up to the bar widget
  readonly property var coreData: hostWidget ? hostWidget.sys : null

  function open() { openedFromHotkey = false; root.controller.show() }
  function openFromHotkey() { openedFromHotkey = true; root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? close() : openFromHotkey() }

  onOpenedChanged: {
    if (opened) Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    Keys.onLeftPressed: root.switchPanel(-1)
    Keys.onRightPressed: root.switchPanel(1)
    Keys.onEscapePressed: root.close()

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.space(12)

      PanelHero {
        width: parent.width
        title: coreData ? Fmt.mhz(coreData.cpuFreqMhz) : "—"
        meta: "CPU FREQUENCY"
        detail: coreData ? Math.round(coreData.cpuPercent) + "%" : ""
        iconComponent: Text {
          text: root.icon
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
        }
      }

      PanelSeparator { width: parent.width; foreground: root.foreground }

      // ── Load Average ──────────────────────────────────────────────
      PanelSectionHeader {
        text: "LOAD AVERAGE"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Row {
        width: parent.width
        spacing: Style.space(12)

        Repeater {
          model: coreData ? coreData.loadAvg : [0, 0, 0]
          delegate: Row {
            spacing: Style.space(4)
            Text {
              text: ["1m", "5m", "15m"][index] || ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              text: Number(modelData).toFixed(2)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }
        }
      }

      PanelSeparator { width: parent.width; foreground: root.foreground }

      // ── Per-core usage ──────────────────────────────────────────
      PanelSectionHeader {
        text: "CORES"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: coreData ? coreData.corePercents : []
        delegate: Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            width: Style.space(40)
            text: "Core " + index
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Item {
            width: parent.width - Style.space(80)
            height: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
              radius: Style.space(4)
            }

            Rectangle {
              width: Math.max(2, parent.width * modelData / 100)
              height: parent.height
              color: modelData >= 90 ? Color.urgent : Color.accent
              radius: Style.space(4)
            }
          }

          Text {
            width: Style.space(32)
            text: modelData + "%"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            horizontalAlignment: Text.AlignRight
          }
        }
      }

      Item { height: 1; width: 1 } // spacer
    }
  }
}
