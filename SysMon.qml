import QtQuick
import qs.Ui
import qs.Commons
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.arslan.sysmon"

  // ---- live data for the bar labels (panel collects its own via collector.py)
  SysMonCore {
    id: sys
    intervalMs: 2000
  }

  readonly property color white: "#ffffff"

  // Prefer panel snapshot data when panel is open, fall back to SysMonCore
  readonly property var snap: panelLoader.item && panelLoader.item.snapshot ? panelLoader.item.snapshot : null
  readonly property real cpuPercent: snap && snap.cpu ? snap.cpu.total : sys.cpuPercent
  readonly property real memPercent: snap ? (snap.mem && snap.mem.total > 0 ? (snap.mem.used / snap.mem.total * 100) : sys.memPercent) : sys.memPercent
  readonly property real tempC: snap && snap.cpu && snap.cpu.temp !== null && snap.cpu.temp !== undefined ? snap.cpu.temp : sys.tempCurrent / 1000
  readonly property real diskPercent: snap && snap.disk && snap.disk.total > 0 ? (snap.disk.used / snap.disk.total * 100) : sys.diskPercent
  readonly property string cpuFreqText: snap && snap.cpu && snap.cpu.freq_mhz ? (snap.cpu.freq_mhz >= 1000 ? (snap.cpu.freq_mhz / 1000).toFixed(1) + "GHz" : snap.cpu.freq_mhz + "MHz") : freqText()

  function stateColor(val, base) {
    if (val >= 80) return "#ff3333"
    if (val >= 60) return "#ffb800"
    return base
  }

  function textColor(val) {
    return val >= 80 ? "#ff3333" : white
  }

  function pillColor(active) {
    return active ? Qt.lighter(Color.bar.background, 1.5) : Qt.lighter(Color.bar.background, 1.2)
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
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch)
      panelLoader.item.closeForPopoutSwitch()
  }

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
      color: "transparent"

      WidgetButton {
        id: cpuBtn
        anchors.fill: parent
        bar: root.bar
        text: "\u{F035B} " + root.cpuFreqText + " (" + Math.round(root.cpuPercent) + "%)"
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
      color: "transparent"

      WidgetButton {
        id: memBtn
        anchors.fill: parent
        bar: root.bar
        text: "\u{F046D} " + Math.round(root.memPercent) + "%"
        fontSize: Style.font.body
        horizontalMargin: 5
        verticalPadding: 2
        tooltipText: snap && snap.mem ? Model.bytes(snap.mem.used) + " / " + Model.bytes(snap.mem.total) : Model.bytes(sys.memUsed) + " / " + Model.bytes(sys.memTotal)
        onPressed: function(b) { if (b === Qt.LeftButton) root.openTab("mem") }
      }
    }

    Rectangle {
      implicitWidth: tempBtn.implicitWidth
      implicitHeight: tempBtn.implicitHeight
      radius: height / 2
      color: "transparent"

      WidgetButton {
        id: tempBtn
        anchors.fill: parent
        bar: root.bar
        text: tempIcon() + " " + Math.round(root.tempC) + "\u00B0C"
        fontSize: Style.font.body
        horizontalMargin: 5
        verticalPadding: 2
        tooltipText: Math.round(root.tempC) + "°C / " + Math.round(root.tempC * 1.8 + 32) + "°F"
        onPressed: function(b) { if (b === Qt.LeftButton) root.openTab("temp") }
      }
    }

    Rectangle {
      implicitWidth: diskBtn.implicitWidth
      implicitHeight: diskBtn.implicitHeight
      radius: height / 2
      color: "transparent"

      WidgetButton {
        id: diskBtn
        anchors.fill: parent
        bar: root.bar
        text: "\u{F02CA} " + Math.round(root.diskPercent) + "%"
        fontSize: Style.font.body
        horizontalMargin: 5
        verticalPadding: 2
        tooltipText: snap && snap.disk ? Model.bytes(snap.disk.used) + " / " + Model.bytes(snap.disk.total) : Model.bytes(sys.diskUsed) + " / " + Model.bytes(sys.diskTotal)
        onPressed: function(b) { if (b === Qt.LeftButton) root.openTab("disk") }
      }
    }
  }
}
