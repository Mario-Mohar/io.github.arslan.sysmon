import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../format.js" as Fmt

// Memory detail panel — used/free/cached/swap with usage bars.
Panel {
  id: root
  moduleName: "io.github.arslan.sysmon.mem"
  ipcTarget: "io.github.arslan.sysmon.mem"

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false
  readonly property string icon: "\udb81\ude1a"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)

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
        title: coreData ? Math.round(coreData.memPercent) + "%" : "—"
        meta: "MEMORY"
        detail: coreData ? Fmt.bytes(coreData.memUsed) + " / " + Fmt.bytes(coreData.memTotal) : ""
        iconComponent: Text {
          text: root.icon
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
        }
      }

      PanelSeparator { width: parent.width; foreground: root.foreground }

      // ── Memory breakdown ────────────────────────────────────────
      PanelSectionHeader {
        text: "BREAKDOWN"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: coreData ? [
          { label: "Used", value: coreData.memUsed, color: Color.accent },
          { label: "Free", value: coreData.memFree, color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15) },
          { label: "Buffers", value: coreData.memBuffers, color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.25) },
          { label: "Cached", value: coreData.memCached, color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.35) }
        ] : []
        delegate: Column {
          width: parent.width
          spacing: Style.space(4)

          Row {
            width: parent.width
            Text {
              width: parent.width * 0.4
              text: modelData.label
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              width: parent.width * 0.35
              text: Fmt.bytes(modelData.value)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              width: parent.width * 0.25
              text: coreData.memTotal > 0 ? Math.round(modelData.value / coreData.memTotal * 100) + "%" : "0%"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }

          // Usage bar
          Item {
            width: parent.width
            height: Style.space(8)

            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
              radius: Style.space(4)
            }

            Rectangle {
              width: coreData && coreData.memTotal > 0
                ? Math.max(2, parent.width * modelData.value / coreData.memTotal) : 0
              height: parent.height
              color: modelData.color
              radius: Style.space(4)
            }
          }
        }
      }

      PanelSeparator { width: parent.width; foreground: root.foreground }

      // ── Swap ────────────────────────────────────────────────────
      PanelSectionHeader {
        text: "SWAP"
        foreground: root.foreground
        fontFamily: root.fontFamily
        visible: coreData && coreData.swapTotal > 0
      }

      Row {
        width: parent.width
        visible: coreData && coreData.swapTotal > 0
        spacing: Style.space(12)

        Text {
          text: Fmt.bytes(coreData ? coreData.swapUsed : 0) + " / " + Fmt.bytes(coreData ? coreData.swapTotal : 0)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          text: coreData ? Math.round(coreData.swapPercent) + "%" : "0%"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Item { height: 1; width: 1 }
    }
  }
}
