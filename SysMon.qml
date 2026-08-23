import QtQuick
import qs.Ui
import qs.Commons
import "format.js" as Fmt

BarWidget {
  id: root
  moduleName: "io.github.arslan.sysmon"

  // ---- live data for the bar labels (panel collects its own via collector.py)
  SysMonCore {
    id: sys
    intervalMs: 2000
  }

  readonly property color white: "#ffffff"
  readonly property real tempC: sys.tempCurrent / 1000

  function stateColor(val, base) {
    if (val >= 80) return "#ff3333"
    if (val >= 60) return "#ffb800"
    return base
  }

  function textColor(val) {
    return val >= 80 ? "#ff3333" : white
  }

  function pillColor() {
    return Qt.lighter(Color.bar.background, 1.2)
  }

  function tempIcon() {
    var c = Math.round(tempC)
    if (c >= 80) return "\u{F1807}"
    if (c >= 65) return "\u{F0510}"
    if (c >= 50) return "\u{F10C2}"
    return "\u{F050F}"
  }

  function freqText() {
    return sys.cpuFreqMhz >= 1000 ? sys.cpuFreqGhz + "GHz" : sys.cpuFreqMhz + "MHz"
  }

  // ---- panel wiring (vitals pattern) ---------------------------------------
  function injectPanel() {
    var p = panelLoader.item
    if (!p) return
    if ("bar" in p) p.bar = root.bar
    if ("settings" in p) p.settings = root.settings
    if ("anchorItem" in p) p.anchorItem = cpuBtn
    if ("hostWidget" in p) p.hostWidget = root
  }

  function openTab(key) {
    var p = panelLoader.item
    if (!p) return
    if (p.showTab && p.showTab(key)) { /* switched */ }
    if (!p.opened) p.openFromHotkey()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // ---- bar widget: 4 colored metric buttons ---------------------------------
  implicitWidth: row.implicitWidth
  implicitHeight: Style.bar.sizeHorizontal

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6

    Rectangle {
      implicitWidth: cpuBtn.implicitWidth
      implicitHeight: cpuBtn.implicitHeight
      radius: height / 2
      color: pillColor()

      WidgetButton {
        id: cpuBtn
        anchors.fill: parent
        bar: root.bar
        text: "<font color='" + stateColor(sys.cpuPercent, "#4da6ff") + "'>\u{F035B}</font> <font color='" + textColor(sys.cpuPercent) + "'>" + freqText() + " (" + Math.round(sys.cpuPercent) + "%)</font>"
        fontSize: Style.font.body
        horizontalMargin: 5
        verticalPadding: 2
        tooltipText: sys.cpuModelName ? sys.cpuModelName : "CPU"
        onPressed: function(b) { if (b === Qt.LeftButton) root.openTab("cpu") }
      }
    }

    Rectangle {
      implicitWidth: memBtn.implicitWidth
      implicitHeight: memBtn.implicitHeight
      radius: height / 2
      color: pillColor()

      WidgetButton {
        id: memBtn
        anchors.fill: parent
        bar: root.bar
        text: "<font color='" + stateColor(sys.memPercent, "#66ff66") + "'>\u{F046D}</font> <font color='" + textColor(sys.memPercent) + "'>" + Math.round(sys.memPercent) + "%</font>"
        fontSize: Style.font.body
        horizontalMargin: 5
        verticalPadding: 2
        tooltipText: Fmt.bytes(sys.memUsed) + " / " + Fmt.bytes(sys.memTotal)
        onPressed: function(b) { if (b === Qt.LeftButton) root.openTab("mem") }
      }
    }

    Rectangle {
      implicitWidth: tempBtn.implicitWidth
      implicitHeight: tempBtn.implicitHeight
      radius: height / 2
      color: pillColor()

      WidgetButton {
        id: tempBtn
        anchors.fill: parent
        bar: root.bar
        text: "<font color='" + stateColor(tempC, tempC >= 50 ? "#ff9933" : "#4da6ff") + "'>" + tempIcon() + "</font> <font color='" + textColor(tempC >= 80 ? 100 : 0) + "'>" + Math.round(tempC) + "\u00B0</font>"
        fontSize: Style.font.body
        horizontalMargin: 5
        verticalPadding: 2
        tooltipText: Math.round(tempC) + "°C / " + Math.round(tempC * 1.8 + 32) + "°F"
        onPressed: function(b) { if (b === Qt.LeftButton) root.openTab("temp") }
      }
    }

    Rectangle {
      implicitWidth: diskBtn.implicitWidth
      implicitHeight: diskBtn.implicitHeight
      radius: height / 2
      color: pillColor()

      WidgetButton {
        id: diskBtn
        anchors.fill: parent
        bar: root.bar
        text: "<font color='" + stateColor(sys.diskPercent, white) + "'>\u{F02CA}</font> <font color='" + textColor(sys.diskPercent) + "'>" + Math.round(sys.diskPercent) + "%</font>"
        fontSize: Style.font.body
        horizontalMargin: 5
        verticalPadding: 2
        tooltipText: Fmt.bytes(sys.diskUsed) + " / " + Fmt.bytes(sys.diskTotal)
        onPressed: function(b) { if (b === Qt.LeftButton) root.openTab("disk") }
      }
    }
  }
}
