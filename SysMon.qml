import QtQuick
import qs.Ui
import qs.Commons

// SysMon bar widget: CPU, memory, temperature, and disk stats.
// Each segment opens its own detail panel.
BarWidget {
  id: root
  moduleName: "io.github.arslan.sysmon"

  // ── Settings ────────────────────────────────────────────────────────
  readonly property int intervalSec: setting("interval", 2)
  readonly property bool showCpu: setting("showCpu", true)
  readonly property bool showMemory: setting("showMemory", true)
  readonly property bool showTemp: setting("showTemp", true)
  readonly property bool showDisk: setting("showDisk", true)
  readonly property bool showIcons: setting("showIcons", true)
  readonly property real cpuWarnPercent: setting("cpuWarnPercent", 90)
  readonly property real memWarnPercent: setting("memWarnPercent", 90)
  readonly property string clickCommand: setting("onClick", "omarchy-launch-or-focus-tui btop")

  // Nerd Font glyphs
  readonly property string cpuIcon: "\uf4bc"        // nf-md-chip
  readonly property string memIcon: "\udb81\ude1a"  // nf-md-memory
  readonly property string tempIcon: "\udb81\udc5b" // nf-md-thermometer
  readonly property string diskIcon: "\udb83\udcab" // nf-harddisk

  SysMonCore {
    id: sys
    interval: root.intervalSec
  }

  function withIcon(icon, body) {
    return showIcons && icon !== "" ? icon + " " + body : body
  }

  // ── Bar labels ──────────────────────────────────────────────────────
  readonly property string cpuText: Math.round(sys.cpuPercent) + "%"
  readonly property string cpuLabel: withIcon(cpuIcon, sys.cpuFreqGhz + "GHz (" + cpuText + ")")
  readonly property string memLabel: withIcon(memIcon, Math.round(sys.memPercent) + "%")
  readonly property string tempLabel: withIcon(tempIcon, Math.round(sys.tempCurrent / 1000) + "°")
  readonly property string diskLabel: withIcon(diskIcon, Math.round(sys.diskPercent) + "%")

  readonly property string cpuTooltip: "CPU " + sys.cpuFreqGhz + "GHz · " + cpuText
    + (sys.loadAvg[0] > 0 ? " · load " + sys.loadAvg[0].toFixed(2) : "")
  readonly property string memTooltip: "RAM " + Math.round(sys.memPercent) + "%"
    + (sys.swapTotal > 0 ? " · swap " + Math.round(sys.swapPercent) + "%" : "")
  readonly property string tempTooltip: "Temperature " + Math.round(sys.tempCurrent / 1000) + "°C"
  readonly property string diskTooltip: "Disk " + Math.round(sys.diskPercent) + "% used"

  // ── Panel loaders ───────────────────────────────────────────────────
  function injectPanel(loader) {
    if (!loader.item) return
    if ("bar" in loader.item) loader.item.bar = root.bar
    if ("settings" in loader.item) loader.item.settings = root.settings
    if ("anchorItem" in loader.item) loader.item.anchorItem = loader.anchorRef
    if ("hostWidget" in loader.item) loader.item.hostWidget = root
  }

  Loader {
    id: cpuPanelLoader
    active: true
    source: Qt.resolvedUrl("panels/CpuPanel.qml")
    visible: false
    property var anchorRef: cpuBtn
    onLoaded: { injectPanel(this); Qt.callLater(function() { injectPanel(cpuPanelLoader) }) }
  }
  Loader {
    id: memPanelLoader
    active: true
    source: Qt.resolvedUrl("panels/MemPanel.qml")
    visible: false
    property var anchorRef: memBtn
    onLoaded: { injectPanel(this); Qt.callLater(function() { injectPanel(memPanelLoader) }) }
  }
  Loader {
    id: tempPanelLoader
    active: true
    source: Qt.resolvedUrl("panels/TempPanel.qml")
    visible: false
    property var anchorRef: tempBtn
    onLoaded: { injectPanel(this); Qt.callLater(function() { injectPanel(tempPanelLoader) }) }
  }
  Loader {
    id: diskPanelLoader
    active: true
    source: Qt.resolvedUrl("panels/DiskPanel.qml")
    visible: false
    property var anchorRef: diskBtn
    onLoaded: { injectPanel(this); Qt.callLater(function() { injectPanel(diskPanelLoader) }) }
  }

  // ── IPC targets for hotkey toggling ─────────────────────────────────
  IpcHandler {
    target: "io.github.arslan.sysmon.cpu"
    function toggle(): void { cpuPanelLoader.item && cpuPanelLoader.item.toggle() }
  }
  IpcHandler {
    target: "io.github.arslan.sysmon.mem"
    function toggle(): void { memPanelLoader.item && memPanelLoader.item.toggle() }
  }
  IpcHandler {
    target: "io.github.arslan.sysmon.temp"
    function toggle(): void { tempPanelLoader.item && tempPanelLoader.item.toggle() }
  }
  IpcHandler {
    target: "io.github.arslan.sysmon.disk"
    function toggle(): void { diskPanelLoader.item && diskPanelLoader.item.toggle() }
  }

  // ── Bar layout ──────────────────────────────────────────────────────
  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  Grid {
    id: layout
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 99

    WidgetButton {
      id: cpuBtn
      bar: root.bar
      visible: root.showCpu
      text: root.cpuLabel
      active: root.cpuWarnPercent > 0 && sys.cpuPercent >= root.cpuWarnPercent
      fontSize: Style.font.caption
      horizontalMargin: 5
      tooltipText: root.cpuTooltip
      onPressed: function(b) {
        if (b === Qt.LeftButton) {
          if (cpuPanelLoader.item) cpuPanelLoader.item.toggle()
        } else {
          root.bar.run(root.clickCommand)
        }
      }
    }

    WidgetButton {
      id: memBtn
      bar: root.bar
      visible: root.showMemory
      text: root.memLabel
      active: root.memWarnPercent > 0 && sys.memPercent >= root.memWarnPercent
      fontSize: Style.font.caption
      horizontalMargin: 5
      tooltipText: root.memTooltip
      onPressed: function(b) {
        if (b === Qt.LeftButton) {
          if (memPanelLoader.item) memPanelLoader.item.toggle()
        } else {
          root.bar.run(root.clickCommand)
        }
      }
    }

    WidgetButton {
      id: tempBtn
      bar: root.bar
      visible: root.showTemp
      text: root.tempLabel
      fontSize: Style.font.caption
      horizontalMargin: 5
      tooltipText: root.tempTooltip
      onPressed: function(b) {
        if (b === Qt.LeftButton) {
          if (tempPanelLoader.item) tempPanelLoader.item.toggle()
        } else {
          root.bar.run(root.clickCommand)
        }
      }
    }

    WidgetButton {
      id: diskBtn
      bar: root.bar
      visible: root.showDisk
      text: root.diskLabel
      fontSize: Style.font.caption
      horizontalMargin: 5
      tooltipText: root.diskTooltip
      onPressed: function(b) {
        if (b === Qt.LeftButton) {
          if (diskPanelLoader.item) diskPanelLoader.item.toggle()
        } else {
          root.bar.run(root.clickCommand)
        }
      }
    }
  }
}
