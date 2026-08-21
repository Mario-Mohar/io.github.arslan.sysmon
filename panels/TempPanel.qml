import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../format.js" as Fmt

// Temperature detail panel — thermal zones with current readings.
Panel {
  id: root
  moduleName: "io.github.arslan.sysmon.temp"
  ipcTarget: "io.github.arslan.sysmon.temp"

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false
  readonly property string icon: "\udb81\udc5b"
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

  function tempColor(temp) {
    if (temp >= 80000) return Color.urgent
    if (temp >= 65000) return Color.accent
    return root.foreground
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
        title: coreData ? Math.round(coreData.tempCurrent / 1000) + "°C" : "—"
        meta: "TEMPERATURE"
        detail: coreData && coreData.thermalZones.length > 0
          ? coreData.thermalZones[0].name : ""
        iconComponent: Text {
          text: root.icon
          color: root.tempColor(coreData ? coreData.tempCurrent : 0)
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
        }
      }

      PanelSeparator { width: parent.width; foreground: root.foreground }

      // ── Thermal zones ──────────────────────────────────────────
      PanelSectionHeader {
        text: "THERMAL ZONES"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: coreData ? coreData.thermalZones : []
        delegate: Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            width: parent.width * 0.5
            text: modelData.name
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          // Temperature bar
          Item {
            width: parent.width * 0.3
            height: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
              radius: Style.space(4)
            }

            Rectangle {
              width: Math.max(2, parent.width * Math.min(1, modelData.temp / 100000))
              height: parent.height
              color: root.tempColor(modelData.temp)
              radius: Style.space(4)
            }
          }

          Text {
            width: parent.width * 0.2
            text: Fmt.temp(modelData.temp)
            color: root.tempColor(modelData.temp)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            horizontalAlignment: Text.AlignRight
          }
        }
      }

      Item { height: 1; width: 1 }
    }
  }
}
