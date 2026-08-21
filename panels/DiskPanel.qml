import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../format.js" as Fmt

// Disk detail panel — partition usage, mount points, free space.
Panel {
  id: root
  moduleName: "io.github.arslan.sysmon.disk"
  ipcTarget: "io.github.arslan.sysmon.disk"

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false
  readonly property string icon: "\udb83\udcab"
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

  function mountLabel(mount) {
    if (mount === "/") return "root"
    var parts = mount.split("/")
    return parts[parts.length - 1] || mount
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
        title: coreData ? Math.round(coreData.diskPercent) + "%" : "—"
        meta: "DISK"
        detail: coreData ? Fmt.bytes(coreData.diskUsed) + " / " + Fmt.bytes(coreData.diskTotal) : ""
        iconComponent: Text {
          text: root.icon
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
        }
      }

      PanelSeparator { width: parent.width; foreground: root.foreground }

      // ── Partitions ─────────────────────────────────────────────
      PanelSectionHeader {
        text: "PARTITIONS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: coreData ? coreData.diskPartitions : []
        delegate: Column {
          width: parent.width
          spacing: Style.space(6)

          Row {
            width: parent.width
            Text {
              width: parent.width * 0.35
              text: mountLabel(modelData.mount)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              width: parent.width * 0.35
              text: Fmt.bytes(modelData.used) + " / " + Fmt.bytes(modelData.total)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              width: parent.width * 0.3
              text: Fmt.bytes(modelData.avail) + " free"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }

          // Usage bar
          Item {
            width: parent.width
            height: Style.space(14)

            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
              radius: Style.space(4)
            }

            Rectangle {
              width: Math.max(2, parent.width * modelData.percent / 100)
              height: parent.height
              color: modelData.percent >= 90 ? Color.urgent : Color.accent
              radius: Style.space(4)
            }

            Text {
              anchors.centerIn: parent
              text: modelData.percent + "%"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          // Device path
          Text {
            text: modelData.device
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 2
          }
        }
      }

      Item { height: 1; width: 1 }
    }
  }
}
