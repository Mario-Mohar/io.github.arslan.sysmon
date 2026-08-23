import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Vitals: a calm system monitor panel. One tab at a time — CPU, Memory,
// Disks, Network, GPU, Processes — fed by collector.py, which only runs while
// the panel is open. Each tab is a Loader that is only alive while selected,
// so a hidden tab costs nothing per sample.
Panel {
  id: root
  moduleName: "io.github.arslan.sysmon"
  ipcTarget: "io.github.arslan.sysmon"
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the showTab method below.
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel (same contract as the weather / tides plugins).
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- palette / type -----------------------------------------------------
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar && bar.urgent !== undefined ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color faint: Qt.darker(foreground, 1.4)
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string icon: "󰍛" // nf-md-memory (chip)

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  // Threshold colors shared with the bar widget: calm until 60%, amber to 80%, red beyond.
  function stateColor(pct) { return pct >= 80 ? "#ff3333" : pct >= 60 ? "#ffb800" : foreground }
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

  // ---- settings ------------------------------------------------------------
  readonly property int refreshSeconds: clamp(Number(setting("refreshSeconds", 1)) || 1, 1, 10)
  readonly property int historyLength: 90

  // ---- open / close ---------------------------------------------------------
  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    if (root.confirmOpen) root.cancelSignal()
    if (root.filtering) root.stopFiltering()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
    }
  }

  // ---- data -----------------------------------------------------------------
  property var snapshot: null
  readonly property bool hasData: snapshot !== null
  readonly property var cpu: snapshot ? snapshot.cpu : null
  readonly property var mem: snapshot ? snapshot.mem : null
  readonly property var disks: snapshot ? (snapshot.disks || []) : []
  readonly property var gpus: snapshot ? (snapshot.gpus || []) : []
  readonly property var ifaces: snapshot && snapshot.net ? (snapshot.net.ifaces || []) : []
  readonly property var processes: snapshot ? (snapshot.processes || []) : []

  property var cpuHistory: []
  property var gpuHistory: []
  property var rxHistory: []
  property var txHistory: []
  property var tempHistory: []
  readonly property var tempStats: {
    var h = root.tempHistory
    if (!h || h.length === 0) return null
    var mn = h[0], mx = h[0], sum = 0
    for (var i = 0; i < h.length; i++) {
      if (h[i] < mn) mn = h[i]
      if (h[i] > mx) mx = h[i]
      sum += h[i]
    }
    return { min: mn, max: mx, avg: sum / h.length }
  }

  function tempBand(t) { return t >= 80 ? 3 : t >= 65 ? 2 : t >= 50 ? 1 : 0 }
  readonly property var tempBands: [
    { label: "Nominal", color: "#66ff66" },
    { label: "Warm", color: "#ffcc00" },
    { label: "Hot", color: "#ff9933" },
    { label: "Critical", color: "#ff3333" }
  ]
  readonly property int currentTempBand: root.cpu && root.cpu.temp !== null && root.cpu.temp !== undefined ? tempBand(root.cpu.temp) : -1

  property int smartIndex: -1
  property string smartState: ""
  property string smartOut: ""
  property bool smartInstalled: false
  property string smartDev: ""
  // Expansion state keyed by partition path — survives delegate rebuilds
  // caused by fresh snapshot arrays every tick.
  property var expandedParts: ({})
  function togglePart(key) {
    var m = {}
    for (var k in expandedParts) m[k] = expandedParts[k]
    if (m[key]) delete m[key]
    else m[key] = true
    expandedParts = m
  }
  readonly property bool hasSmart: (root.snapshot && root.snapshot.has_smart === true) || root.smartInstalled

  readonly property string collectorPath: Qt.resolvedUrl("collector.py").toString().replace(/^file:\/\//, "")

  Process {
    id: collector
    command: ["python3", root.collectorPath, "--interval", String(root.refreshSeconds)]
    running: root.opened
    stdout: SplitParser {
      onRead: function(line) { root.ingest(line) }
    }
  }

  Process {
    id: smartProc
    property string buf: ""
    stdout: StdioCollector { onStreamFinished: smartProc.buf = this.text }
    onExited: {
      if (root.smartState === "installing") {
        if (this.exitCode === 0) { root.smartInstalled = true; root.smartState = "" }
        else root.smartState = "error"
        return
      }
      root.smartOut = smartProc.buf
      root.smartState = smartProc.buf !== "" ? "done" : "error"
    }
  }

  function querySmart(index) {
    var d = root.disks[index]
    if (!d || !d.smart_dev || !root.hasSmart) return
    smartProc.buf = ""
    smartOut = ""
    smartIndex = index
    smartDev = ""
    smartState = "running"
    smartProc.command = ["pkexec", "smartctl", "-H", "-A", "-l", "error", "/dev/" + d.smart_dev]
    smartProc.running = true
  }

  function querySmartDev(name) {
    if (!name || !root.hasSmart) return
    smartProc.buf = ""
    smartOut = ""
    smartIndex = -1
    smartDev = name
    smartState = "running"
    smartProc.command = ["pkexec", "smartctl", "-H", "-A", "-l", "error", "/dev/" + name]
    smartProc.running = true
  }

  function installSmart() {
    smartIndex = -1
    smartState = "installing"
    smartProc.buf = ""
    smartProc.command = ["pkexec", "pacman", "-S", "--needed", "--noconfirm", "smartmontools"]
    smartProc.running = true
  }

  function parseSmart(text) {
    var rows = []
    var verdict = null
    var m = text.match(/overall-health[^:\n]*:\s*([A-Za-z ]+)/)
    if (m) verdict = m[1].trim()
    var wanted = ["Percentage Used", "Data Units Read", "Data Units Written", "Power On Hours", "Power Cycles", "Unsafe Shutdowns", "Media and Data Integrity Errors", "Critical Warning"]
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var c = lines[i].indexOf(":")
      if (c > 0 && c < 42) {
        var k = lines[i].slice(0, c).trim()
        for (var w = 0; w < wanted.length; w++) {
          if (k === wanted[w]) { rows.push({ k: k, v: lines[i].slice(c + 1).trim() }); break }
        }
      }
    }
    if (rows.length === 0) {
      var ids = { "5": "Reallocated sectors", "9": "Power-on hours", "194": "Temperature", "199": "CRC errors", "233": "Media wear" }
      for (i = 0; i < lines.length; i++) {
        var f = lines[i].trim().split(/\s+/)
        if (f.length > 9 && ids[f[0]] !== undefined) rows.push({ k: ids[f[0]], v: f[f.length - 1] })
      }
    }
    return { verdict: verdict, rows: rows, raw: text.trim().split("\n").slice(-14).join("\n") }
  }

  function ingest(line) {
    var raw = String(line || "").trim()
    if (!raw) return
    var parsed
    try { parsed = JSON.parse(raw) } catch (e) { return }
    if (!parsed || !parsed.cpu) return
    snapshot = parsed
    cpuHistory = Model.pushHistory(cpuHistory, parsed.cpu.total, historyLength)
    if (parsed.cpu && parsed.cpu.temp !== null && parsed.cpu.temp !== undefined) {
      tempHistory = Model.pushHistory(tempHistory, parsed.cpu.temp, historyLength)
    }
    var g = parsed.gpus && parsed.gpus.length ? parsed.gpus[0] : null
    gpuHistory = Model.pushHistory(gpuHistory, g && g.busy !== null ? g.busy : 0, historyLength)
    var iface = currentIface(parsed.net ? (parsed.net.ifaces || []) : [])
    rxHistory = Model.pushHistory(rxHistory, iface ? iface.rx_bps : 0, historyLength)
    txHistory = Model.pushHistory(txHistory, iface ? iface.tx_bps : 0, historyLength)
    if (tabKey === "proc") rebuildProcs()
  }

  // ---- tabs ------------------------------------------------------------------
  readonly property var tabs: {
    var t = [
      { key: "cpu", label: "CPU" },
      { key: "temp", label: "Temps" },
      { key: "mem", label: "Memory" },
      { key: "disk", label: "Disks" },
      { key: "net", label: "Network" }
    ]
    if (root.gpus.length > 0 || !root.hasData) t.push({ key: "gpu", label: "GPU" })
    t.push({ key: "proc", label: "Processes" })
    return t
  }
  property string tabKey: "cpu"
  readonly property int tabIndex: {
    for (var i = 0; i < tabs.length; i++) if (tabs[i].key === tabKey) return i
    return 0
  }
  property bool cursorActive: false
  // Where the process cursor came from. A keyboard cursor follows its process
  // when the table re-sorts; a mouse hover stays under the pointer.
  property bool cursorFromKeys: false

  function selectTab(index) {
    if (tabs.length === 0) return
    var n = tabs.length
    var i = ((index % n) + n) % n
    if (tabs[i].key === tabKey) return
    if (filtering) stopFiltering()
    tabKey = tabs[i].key
    procIndex = 0
    cursorFromKeys = false
    if (tabKey === "proc") rebuildProcs()
  }

  // Jump to a tab by key: cpu · mem · disk · net · gpu · proc.
  function showTab(key) {
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].key === String(key)) { selectTab(i); return true }
    }
    return false
  }

  IpcHandler {
    target: "io.github.arslan.sysmon"

    function open() { root.openFromHotkey() }
    function close() { root.close() }
    function show() { root.openFromHotkey() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    // omarchy-shell io.github.arslan.sysmon showTab proc  — opens on that tab.
    function showTab(key) {
      var ok = root.showTab(key)
      if (ok && !root.opened) root.openFromHotkey()
      return ok ? "ok" : "unknown"
    }
  }

  // Headline number in the hero follows the tab, so the big figure is
  // always the one the current tab is about.
  readonly property string headline: {
    var snap = snapshot
    if (!snap) return "—"
    if (tabKey === "cpu") return snap.cpu ? Model.percent(snap.cpu.total) : "—"
    if (tabKey === "temp") return snap.cpu && snap.cpu.temp !== null && snap.cpu.temp !== undefined ? Model.temp(snap.cpu.temp) : "—"
    if (tabKey === "mem") return snap.mem && snap.mem.total > 0 ? Model.percent(snap.mem.used * 100 / snap.mem.total) : "—"
    if (tabKey === "disk") {
      var d = snap.disks && snap.disks.length ? snap.disks[0] : null
      return d && d.total > 0 ? Model.percent(d.used * 100 / d.total) : "—"
    }
    if (tabKey === "net") {
      var i = currentIface()
      return i ? Model.rate(i.rx_bps) : "—"
    }
    if (tabKey === "gpu") {
      var g = snap.gpus && snap.gpus.length ? snap.gpus[0] : null
      return g && g.busy !== null && g.busy !== undefined ? Model.percent(g.busy) : "—"
    }
    if (tabKey === "proc") return Model.count(snap.processes ? snap.processes.length : 0)
    return "—"
  }

  readonly property string headlineCaption: {
    if (tabKey === "cpu") return "CPU"
    if (tabKey === "temp") return "TEMPERATURE"
    if (tabKey === "mem") return "MEMORY"
    if (tabKey === "disk") return disks.length ? Model.mountLabel(disks[0].mount).toUpperCase() : "DISK"
    if (tabKey === "net") return "RECEIVING"
    if (tabKey === "gpu") return "GPU"
    if (tabKey === "proc") return "PROCESSES"
    return ""
  }

  // ---- network interface selection ------------------------------------------
  property string ifaceName: ""

  function currentIface(fromList) {
    var list = fromList || ifaces
    if (list.length === 0) return null
    for (var i = 0; i < list.length; i++) if (list[i].name === ifaceName) return list[i]
    return list[0]
  }

  readonly property var iface: currentIface()

  function selectIface(name) {
    if (name === (iface ? iface.name : "")) return
    ifaceName = name
    rxHistory = []
    txHistory = []
  }

  // ---- processes ---------------------------------------------------------------
  property string sortKey: "cpu"
  property bool sortReverse: false
  property int procIndex: 0
  property int selectedPid: -1
  property string filterText: ""
  property bool filtering: false
  property var sortedProcs: []
  readonly property var sortColumns: ["name", "pid", "user", "mem", "cpu"]
  readonly property var procTab: procLoader.item

  function setSort(key) {
    if (sortKey === key) sortReverse = !sortReverse
    else { sortKey = key; sortReverse = false }
    rebuildProcs()
  }

  function cycleSort(delta) {
    var i = sortColumns.indexOf(sortKey)
    var n = sortColumns.length
    sortKey = sortColumns[(((i + delta) % n) + n) % n]
    sortReverse = false
    rebuildProcs()
  }

  function rebuildProcs() {
    var list = Model.sortProcesses(Model.filterProcesses(processes, filterText), sortKey, sortReverse)
    // The table re-sorts on every sample, so remember which *process* the
    // cursor is on and find it again in the new order — otherwise the row
    // under the highlight would silently change identity between ticks.
    var followPid = cursorActive && cursorFromKeys && procIndex >= 0 && procIndex < sortedProcs.length ? sortedProcs[procIndex].pid : -1
    sortedProcs = list
    var n = list.length
    var selectedStillHere = false
    for (var i = 0; i < n; i++) {
      var p = list[i]
      var row = { pid: p.pid, ppid: p.ppid, name: p.name, user: p.user, cpu: p.cpu, mem: p.mem,
                  threads: p.threads, state: p.state || "", cmd: p.cmd }
      if (i < procModel.count) procModel.set(i, row)
      else procModel.append(row)
      if (p.pid === selectedPid) selectedStillHere = true
    }
    while (procModel.count > n) procModel.remove(procModel.count - 1)
    if (followPid >= 0) {
      for (var j = 0; j < n; j++) {
        if (list[j].pid === followPid) {
          if (j !== procIndex) {
            procIndex = j
            procScrollTo(j)
          }
          break
        }
      }
    }
    if (procIndex >= n) procIndex = Math.max(0, n - 1)
    if (selectedPid >= 0 && !selectedStillHere && filterText === "") selectedPid = -1
  }

  ListModel { id: procModel }

  function procScrollTo(index) {
    if (procTab && procTab.scrollTo) procTab.scrollTo(index)
  }

  function moveProcCursor(delta) {
    if (sortedProcs.length === 0) return
    cursorFromKeys = true
    procIndex = clamp(procIndex + delta, 0, sortedProcs.length - 1)
    procScrollTo(procIndex)
  }

  function jumpProcCursor(toEnd) {
    if (sortedProcs.length === 0) return
    cursorActive = true
    cursorFromKeys = true
    procIndex = toEnd ? sortedProcs.length - 1 : 0
    if (procTab && procTab.scrollToEdge) procTab.scrollToEdge(toEnd)
  }

  // Click / Enter: expand the row into its detail card with actions.
  function toggleSelected(pid) {
    selectedPid = selectedPid === pid ? -1 : pid
  }

  function activateCursor() {
    if (tabKey !== "proc") return
    if (!cursorActive) { cursorActive = true; return }
    if (procIndex >= 0 && procIndex < sortedProcs.length) toggleSelected(sortedProcs[procIndex].pid)
  }

  function startFiltering() {
    filtering = true
    if (procTab && procTab.focusFilter) procTab.focusFilter()
  }

  function stopFiltering() {
    filtering = false
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function clearFilter() {
    filterText = ""
    if (procTab && procTab.clearFilterField) procTab.clearFilterField()
    rebuildProcs()
    stopFiltering()
  }

  // ---- signals to processes -----------------------------------------------------
  // Terminate / Kill ask first; Pause / Resume are reversible so they just go.
  property bool confirmOpen: false
  property var confirmTarget: null
  property string confirmSignal: "TERM"

  readonly property var signalVerbs: ({ TERM: "Terminate", KILL: "Kill", STOP: "Pause", CONT: "Resume" })

  function requestSignal(proc, sig) {
    if (!proc) return
    if (sig === "STOP" || sig === "CONT") { sendSignal(proc.pid, sig); return }
    confirmTarget = proc
    confirmSignal = sig
    confirmOpen = true
    Qt.callLater(function() { confirmKeys.forceActiveFocus() })
  }

  function requestTerminateCursor() {
    if (tabKey !== "proc" || !cursorActive || procIndex < 0 || procIndex >= sortedProcs.length) return
    requestSignal(sortedProcs[procIndex], "TERM")
  }

  function cancelSignal() {
    confirmOpen = false
    confirmTarget = null
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function confirmSignalNow() {
    if (confirmTarget) sendSignal(confirmTarget.pid, confirmSignal)
    cancelSignal()
  }

  function sendSignal(pid, sig) {
    signalProc.command = ["kill", "-" + sig, String(pid)]
    signalProc.running = true
  }

  Process { id: signalProc }

  // ---- surface -----------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    // owner must expose close() so dismiss-clicks route through root.close()
    // -> controller.hide() instead of assigning open=false directly (which
    // breaks the open: root.opened binding and bricks reopening).
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    // A dashboard: hold a comfortable minimum so switching tabs doesn't make
    // the card breathe, and cap so it never runs off the screen.
    contentHeight: panel.fittedContentHeight(Math.max(column.implicitHeight, Style.space(430)), Style.space(760))

    // Keys while a Terminate / Kill confirmation is up.
    Item {
      id: confirmKeys
      anchors.fill: parent
      visible: root.confirmOpen
      z: 20
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (signalConfirm.handleKey(event)) event.accepted = true
      }

      ConfirmDialog {
        id: signalConfirm
        anchors.fill: parent
        opened: root.confirmOpen
        message: root.confirmTarget
          ? root.signalVerbs[root.confirmSignal] + " " + root.confirmTarget.name + " (pid " + root.confirmTarget.pid + ")?"
            + (root.confirmSignal === "KILL" ? "\nSIGKILL cannot be caught — unsaved work is lost." : "")
          : ""
        confirmText: root.signalVerbs[root.confirmSignal] || "Confirm"
        background: Color.popups.background
        foreground: root.foreground
        fontFamily: root.fontFamily
        onCanceled: root.cancelSignal()
        onConfirmed: root.confirmSignalNow()
      }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.filtering || root.confirmOpen

      onMoveRequested: function(dx, dy) {
        root.cursorActive = true
        if (dx !== 0) root.selectTab(root.tabIndex + dx)
        else if (dy !== 0) {
          if (root.tabKey === "proc") root.moveProcCursor(dy)
          else panelFlick.contentY = root.clamp(panelFlick.contentY + dy * Style.space(56), 0,
                                                Math.max(0, panelFlick.contentHeight - panelFlick.height))
        }
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: {
        if (root.selectedPid >= 0) root.selectedPid = -1
        else if (root.filterText !== "") root.clearFilter()
        else root.close()
      }
      onDeleteRequested: root.requestTerminateCursor()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var n = parseInt(t, 10)
        if (!isNaN(n) && n >= 1 && n <= root.tabs.length) { root.selectTab(n - 1); return }
        if (root.tabKey !== "proc") return
        if (t === "s") root.cycleSort(1)
        else if (t === "S") root.cycleSort(-1)
        else if (t === "r" || t === "R") { root.sortReverse = !root.sortReverse; root.rebuildProcs() }
        else if (t === "/" || t === "f" || t === "F") root.startFiltering()
        else if (t === "g") root.jumpProcCursor(false)
        else if (t === "G") root.jumpProcCursor(true)
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // ---------- Hero: chip icon · host / uptime · headline figure ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroValue.implicitHeight)

            Text {
              id: heroIcon
              text: root.icon
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: heroValue.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: root.snapshot ? root.snapshot.host : "Vitals"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: root.snapshot
                  ? ("UP " + Model.uptime(root.snapshot.uptime) + "  ·  LOAD " + Model.loadAvg(root.snapshot.load)).toUpperCase()
                  : "READING VITALS…"
                color: root.faint
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }

            Column {
              id: heroValue
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0

              Text {
                anchors.right: parent.right
                text: root.headline
                color: root.foreground
                font.family: root.fontFamily
                // Rates ("14.3 KiB/s") run long; step down so the hero labels keep room.
                font.pixelSize: root.headline.length > 5 ? Style.font.display : Style.font.displayLarge
                font.bold: true
              }

              Text {
                anchors.right: parent.right
                text: root.headlineCaption
                color: root.faint
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }
            }
          }

          // ---------- Tabs ----------
          Row {
            id: tabRow
            width: parent.width
            spacing: Style.space(6)

            readonly property real cellWidth: root.tabs.length > 0
              ? (width - spacing * (root.tabs.length - 1)) / root.tabs.length
              : 0

            Repeater {
              model: root.tabs

              Button {
                required property var modelData
                required property int index

                width: tabRow.cellWidth
                text: modelData.label
                fontSize: Style.font.bodySmall
                foreground: root.foreground
                fontFamily: root.fontFamily
                horizontalPadding: Style.space(4)
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.tabIndex === index
                hasCursor: root.cursorActive && root.tabIndex === index
                onClicked: { root.cursorActive = false; root.selectTab(index) }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ---------- Tab bodies: only the selected one is instantiated ----------
          Loader { width: parent.width; active: root.tabKey === "cpu"; visible: active; sourceComponent: cpuTab }
          Loader { width: parent.width; active: root.tabKey === "temp"; visible: active; sourceComponent: tempTab }
          Loader { width: parent.width; active: root.tabKey === "mem"; visible: active; sourceComponent: memTab }
          Loader { width: parent.width; active: root.tabKey === "disk"; visible: active; sourceComponent: diskTab }
          Loader { width: parent.width; active: root.tabKey === "net"; visible: active; sourceComponent: netTab }
          Loader { width: parent.width; active: root.tabKey === "gpu"; visible: active; sourceComponent: gpuTab }
          Loader { id: procLoader; width: parent.width; active: root.tabKey === "proc"; visible: active; sourceComponent: procTabComponent }
        }
      }
    }
  }

  // ======================================================= CPU
  Component {
    id: cpuTab

    Column {
      spacing: Style.space(10)

      SectionRow {
        label: root.cpu ? root.cpu.model : "CPU"
        value: root.cpu ? [Model.mhz(root.cpu.freq_mhz), Model.temp(root.cpu.temp)].filter(function(s) { return s !== "—" }).join("  ·  ") : ""
        valueDim: true
      }

      Meter { value: root.cpu ? root.cpu.total / 100 : 0; fillColor: root.stateColor(root.cpu ? root.cpu.total : 0) }

      Sparkline {
        width: parent.width
        height: Style.space(56)
        values: root.cpuHistory
        maxValue: 100
      }

      PanelSectionHeader {
        text: "CORES"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Grid {
        id: coreGrid
        width: parent.width
        readonly property int coreCount: root.cpu ? root.cpu.cores.length : 0
        columns: coreCount > 32 ? 4 : (coreCount > 12 ? 2 : 1)
        columnSpacing: Style.space(20)
        rowSpacing: Style.space(4)
        readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

        Repeater {
          model: coreGrid.coreCount

          Item {
            required property int index
            width: coreGrid.cellWidth
            implicitHeight: coreLabel.implicitHeight + Style.space(4)

            readonly property real load: root.cpu ? root.cpu.cores[index] : 0
            readonly property bool hasTemp: root.cpu && root.cpu.core_temps && root.cpu.core_temps.length === root.cpu.cores.length
            readonly property var coreTemp: hasTemp ? root.cpu.core_temps[index] : null

            Text {
              id: coreLabel
              text: "C" + index
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(28)
            }

            Rectangle {
              anchors.left: coreLabel.right
              anchors.right: coreValue.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
              radius: height / 2
              color: root.track

              Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: parent.radius
                width: parent.width * root.clamp(load / 100, 0, 1)
                color: root.stateColor(load)
              }
            }

            Text {
              id: coreValue
              text: Model.percent(load) + (hasTemp ? "  " + (coreTemp === null ? "   " : Model.temp(coreTemp)) : "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: hasTemp ? Style.space(76) : Style.space(36)
            }
          }
        }
      }

      PanelSeparator { foreground: root.foreground }

      Row {
        width: parent.width
        spacing: Style.space(20)

        Column {
          width: (parent.width - parent.spacing) / 2
          spacing: Style.spacing.labelGap
          InfoPair { label: "Load average"; value: root.snapshot ? Model.loadAvg(root.snapshot.load) : "—" }
          InfoPair { label: "Cores"; value: root.cpu ? Model.count(root.cpu.cores.length) : "—" }
          InfoPair {
            visible: root.cpu && root.cpu.power_w !== null && root.cpu.power_w !== undefined
            label: "Package power"; value: root.cpu ? Model.watts(root.cpu.power_w) : "—"
          }
        }

        Column {
          width: (parent.width - parent.spacing) / 2
          spacing: Style.spacing.labelGap
          InfoPair { label: "Uptime"; value: root.snapshot ? Model.uptime(root.snapshot.uptime) : "—" }
          InfoPair {
            visible: root.cpu && root.cpu.fans && root.cpu.fans.length > 0
            label: root.cpu && root.cpu.fans && root.cpu.fans.length > 1 ? "Fans" : "Fan"
            value: {
              if (!root.cpu || !root.cpu.fans) return "—"
              var spinning = root.cpu.fans.filter(function(f) { return f.rpm > 0 })
              if (spinning.length === 0) return "idle"
              return spinning.map(function(f) { return f.rpm + " rpm" }).join(" · ")
            }
          }
        }
      }
    }
  }

  // ======================================================= Temps
  Component {
    id: tempTab

    Column {
      spacing: Style.space(10)

      SectionRow {
        label: "Temperature"
        value: root.cpu && root.cpu.temp !== null && root.cpu.temp !== undefined ? Model.temp(root.cpu.temp) : ""
        valueDim: true
      }

      Sparkline {
        width: parent.width
        height: Style.space(56)
        values: root.tempHistory
        maxValue: 100
      }

      Row {
        visible: root.currentTempBand >= 0
        spacing: Style.space(6)

        Rectangle {
          width: Style.space(8)
          height: width
          radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: root.tempBands[root.currentTempBand >= 0 ? root.currentTempBand : 0].color
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.currentTempBand >= 0 ? "Thermal status \u00B7 " + root.tempBands[root.currentTempBand].label : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Row {
        id: tempStatRow
        width: parent.width
        spacing: Style.space(20)

        Repeater {
          model: [
            { l: "NOW", v: root.cpu && root.cpu.temp !== null && root.cpu.temp !== undefined ? Model.temp(root.cpu.temp) : "\u2014", band: true },
            { l: "MIN", v: root.tempStats ? Model.temp(root.tempStats.min) : "\u2014" },
            { l: "AVG", v: root.tempStats ? Model.temp(root.tempStats.avg) : "\u2014" },
            { l: "PEAK", v: root.tempStats ? Model.temp(root.tempStats.max) : "\u2014" }
          ]

          delegate: Column {
            required property int index
            required property var modelData
            width: (tempStatRow.width - tempStatRow.spacing * 3) / 4
            spacing: 2

            Text {
              text: modelData.l
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              text: modelData.v
              color: modelData.band && root.currentTempBand >= 0 ? root.tempBands[root.currentTempBand].color : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      PanelSeparator { foreground: root.foreground }

      PanelSectionHeader {
        text: "DEVICES"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      // Cross-device glance. Each row jumps to the tab that owns the details,
      // so temperatures are never duplicated across tabs.
      Repeater {
        model: {
          var rows = []
          var gpus = root.gpus || []
          for (var i = 0; i < gpus.length; i++) {
            var g = gpus[i]
            if (g && g.temp !== null && g.temp !== undefined)
              rows.push({ label: gpus.length > 1 ? "GPU " + (i + 1) : "GPU", value: Model.temp(g.temp), tab: "gpu", target: "GPU" })
          }
          if (root.snapshot && root.snapshot.nvme_temp !== null && root.snapshot.nvme_temp !== undefined)
            rows.push({ label: "NVMe", value: Model.temp(root.snapshot.nvme_temp), tab: "disk", target: "Disk" })
          return rows
        }

        delegate: Item {
          required property int index
          required property var modelData
          width: parent.width
          implicitHeight: devLabel.implicitHeight

          Text {
            id: devLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: devJump.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.value
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            id: devJump
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "\u2192 " + modelData.target
            color: root.dim
            opacity: devArea.containsMouse ? 1 : 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: devArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showTab(modelData.tab)
          }
        }
      }

      Text {
        visible: (root.gpus || []).length === 0 && !(root.snapshot && root.snapshot.nvme_temp !== null && root.snapshot.nvme_temp !== undefined)
        width: parent.width
        text: "No device sensors detected"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignRight
        text: (root.cpu && root.cpu.temp_source ? root.cpu.temp_source : "hwmon") + " \u00B7 every " + root.refreshSeconds + "s \u00B7 window " + root.historyLength + " samples"
        color: root.dim
        opacity: 0.7
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ======================================================= Memory
  Component {
    id: memTab

    Column {
      spacing: Style.space(10)

      SectionRow {
        label: "Memory"
        value: root.mem ? Model.bytes(root.mem.used) + " of " + Model.bytes(root.mem.total) : ""
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
          usedFrac: root.mem && root.mem.total > 0 ? root.mem.used / root.mem.total : 0
          cacheFrac: root.mem && root.mem.total > 0 ? Math.min(1, (root.mem.cached + root.mem.buffers) / root.mem.total) : 0
          hasSwap: root.mem && root.mem.swap_total > 0
          swapPct: root.mem && root.mem.swap_total > 0 ? root.mem.swap_used / root.mem.swap_total : 0
          trackColor: root.track
          textColor: root.foreground
          dimColor: root.dim
          fontFamily: root.fontFamily
        }

        Column {
          width: parent.width - memRing.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Repeater {
            model: [
              { c: memRing.usedColor, l: "Used", v: root.mem ? Model.bytes(root.mem.used) : "\u2014", strong: true },
              { c: memRing.cacheColor, l: "Cached + Buffers", v: root.mem ? Model.bytes((root.mem.cached || 0) + (root.mem.buffers || 0)) : "\u2014" },
              { c: memRing.trackColor, l: "Free", v: root.mem ? Model.bytes(Math.max(0, root.mem.total - root.mem.used - (root.mem.cached || 0) - (root.mem.buffers || 0))) : "\u2014" },
              { c: memRing.swapColor, l: "Swap", v: root.mem && root.mem.swap_total > 0 ? Model.bytes(root.mem.swap_used) + " / " + Model.bytes(root.mem.swap_total) : "none" }
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
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                width: Style.space(108)
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.v
                color: modelData.strong ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
    }
  }

  // ======================================================= Disks
  Component {
    id: diskTab

    Column {
      spacing: Style.space(12)

      PanelSectionHeader {
        text: "DISKS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Text {
        visible: root.hasData && (root.snapshot.blockdevs ? root.snapshot.blockdevs.length : 0) === 0 && root.disks.length === 0
        text: "No disks detected"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Repeater {
        model: root.snapshot && root.snapshot.blockdevs ? root.snapshot.blockdevs : []

        delegate: Column {
          id: driveCard
          required property var modelData
          required property int index
          width: parent.width
          spacing: Style.space(8)

          property bool expanded: false
          readonly property var partitions: {
            var name = modelData.name
            var out = []
            for (var i = 0; i < root.disks.length; i++) {
              var d = root.disks[i]
              if (!d || !d.source) continue
              if (d.smart_dev === name
                  || d.source === "/dev/" + name
                  || d.source.indexOf("/dev/" + name + "p") === 0
                  || d.source.indexOf("/dev/" + name + "/") === 0) {
                out.push(d)
              }
            }
            return out
          }
          readonly property bool activeSmart: root.smartDev === modelData.name

          PanelSeparator { visible: index > 0; foreground: root.foreground }

          DriveHeading {
            glyphText: modelData.transport === "usb" ? "\uF08EB" : modelData.transport === "nvme" ? "\uF01A0" : "\uF02CA"
            accent: modelData.removable ? "#ffb800" : root.dim
            title: modelData.model || modelData.name
            meta: Model.bytes(modelData.bytes) + " · " + modelData.transport + (modelData.removable ? " · removable" : "")
          }

          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: driveCard.partitions.length > 0

            Text {
              text: "PARTITIONS"
              color: root.faint
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1
            }

            Repeater {
              model: driveCard.partitions

              delegate: Column {
                id: partRow

                required property var modelData
                width: parent.width
                spacing: Style.space(4)

                readonly property string partKey: String(modelData.source || "") || String(modelData.mount || "") || String(modelData.label || "")
                readonly property bool isOpen: !!root.expandedParts[partKey]
                readonly property real fraction: modelData.total > 0 ? modelData.used / modelData.total : 0

                Item {
                  width: parent.width
                  implicitHeight: Math.max(partName.implicitHeight, partMeta.implicitHeight)

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePart(partRow.partKey)
                  }

                  Text {
                    id: partName
                    text: modelData.mount ? Model.mountLabel(modelData.mount) : (String(modelData.source || "").indexOf("/dev/mapper/") === 0 ? "crypt" : (String(modelData.source || "").indexOf("/dev/") === 0 ? String(modelData.source).substring(5) : "disk"))
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    id: partMeta
                    text: modelData.fstype || "filesystem"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    anchors.left: partName.right
                    anchors.leftMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    id: usageMeta
                    text: partRow.modelData.total > 0 ? Model.bytes(partRow.modelData.used) + " / " + Model.bytes(partRow.modelData.total) + " · " + Model.percent(partRow.fraction * 100) : "—"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.right: chevron.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    visible: !!partRow.modelData.mount
                    text: "(" + (partRow.modelData.mount || "") + ")"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    anchors.right: usageMeta.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    id: chevron
                    text: partRow.isOpen ? "▾" : "›"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Meter {
                  visible: partRow.modelData.total > 0
                  value: partRow.fraction
                }

                Text {
                  // Always occupies one line so rows don't shift when IO goes idle
                  text: {
                    var r = partRow.modelData.read_bps
                    var w = partRow.modelData.write_bps
                    var hR = r !== null && r !== undefined && r > 0
                    var hW = w !== null && w !== undefined && w > 0
                    if (hR && hW) return "read " + Model.rate(r) + "  ·  write " + Model.rate(w)
                    if (hR) return "read " + Model.rate(r)
                    if (hW) return "write " + Model.rate(w)
                    return " "
                  }
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Column {
                  visible: partRow.isOpen
                  width: parent.width
                  spacing: Style.space(4)

                  SectionRow {
                    visible: !!partRow.modelData.source
                    label: "Device"
                    value: String(partRow.modelData.source || "")
                    valueDim: true
                  }
                }
              }
            }
          }

          Text {
            visible: driveCard.partitions.length === 0
            text: "NO PARTITIONS"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Row {
            spacing: Style.space(10)

            Button {
              text: driveCard.activeSmart && root.smartState === "running" ? "Checking\u2026" : "SMART"
              fontSize: Style.font.caption
              foreground: driveCard.activeSmart ? root.foreground : root.dim
              fontFamily: root.fontFamily
              bordered: true
              horizontalPadding: Style.space(8)
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: {
                if (driveCard.activeSmart) { root.smartDev = ""; root.smartState = "" }
                else root.querySmartDev(modelData.name)
              }
            }

            Text {
              visible: !root.hasSmart
              anchors.verticalCenter: parent.verticalCenter
              text: "requires smartmontools"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Button {
              visible: !root.hasSmart
              text: "Install"
              fontSize: Style.font.caption
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              horizontalPadding: Style.space(8)
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: root.installSmart()
            }
          }

          Text {
            visible: driveCard.activeSmart && root.smartState === "running"
            width: parent.width
            text: "Waiting for authorization\u2026"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            visible: driveCard.activeSmart && root.smartState === "error"
            width: parent.width
            text: "Could not read SMART data (cancelled or unsupported device)"
            color: "#ff9933"
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Column {
            readonly property var report: driveCard.activeSmart && root.smartState === "done" && root.smartOut !== "" ? root.parseSmart(root.smartOut) : null
            visible: report !== null
            width: parent.width
            spacing: Style.space(6)

            Text {
              visible: parent.report && parent.report.verdict !== null
              width: parent.width
              text: {
                if (!parent.report || parent.report.verdict === null) return ""
                var extra = ""
                var mm = root.smartOut.match(/Percentage Used:\s*(\d+)%/)
                if (mm) extra = "  ·  ≈ " + Math.max(0, 100 - parseInt(mm[1])) + "% life left"
                return "Health: " + parent.report.verdict + extra
              }
              color: parent.report && String(parent.report.verdict).indexOf("PASSED") >= 0 ? "#66ff66" : "#ff3333"
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Repeater {
              model: parent.report ? parent.report.rows : []

              delegate: Row {
                required property int index
                required property var modelData
                width: parent.width
                spacing: Style.space(8)

                Text {
                  width: parent.width * 0.55
                  text: modelData.k
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                Text {
                  text: modelData.v
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }

            Text {
              visible: parent.report && parent.report.rows.length === 0
              width: parent.width
              text: parent.report ? parent.report.raw : ""
              color: root.dim
              opacity: 0.8
              wrapMode: Text.WrapAnywhere
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }

  // ======================================================= Network
  Component {
    id: netTab

    Column {
      spacing: Style.space(10)

      Text {
        visible: root.hasData && root.ifaces.length === 0
        text: "No network interfaces found"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      // Interface picker, only when there is a choice to make.
      Row {
        id: ifaceRow
        visible: root.ifaces.length > 1
        width: parent.width
        spacing: Style.space(6)

        readonly property int count: Math.min(root.ifaces.length, 5)
        readonly property real cellWidth: count > 0 ? (width - spacing * (count - 1)) / count : 0

        Repeater {
          model: root.ifaces.slice(0, 5)

          Button {
            required property var modelData
            width: ifaceRow.cellWidth
            text: modelData.name
            fontSize: Style.font.caption
            foreground: modelData.up ? root.foreground : root.dim
            fontFamily: root.fontFamily
            horizontalPadding: Style.space(4)
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            active: root.iface && root.iface.name === modelData.name
            onClicked: root.selectIface(modelData.name)
          }
        }
      }

      SectionRow {
        visible: !!root.iface
        label: root.iface ? (root.iface.ssid || root.iface.name) : ""
        value: {
          if (!root.iface) return ""
          var bits = []
          if (root.iface.ssid) bits.push(root.iface.name)
          if (root.iface.ip) bits.push(root.iface.ip)
          if (!root.iface.up) bits.push("down")
          return bits.join("  ·  ")
        }
        valueDim: true
      }

      Row {
        visible: !!root.iface
        width: parent.width
        spacing: 0
        readonly property real cellWidth: width / 4

        StatCell { width: parent.cellWidth; caption: "RECEIVING"; value: root.iface ? Model.rate(root.iface.rx_bps) : "—" }
        StatCell { width: parent.cellWidth; caption: "SENDING"; value: root.iface ? Model.rate(root.iface.tx_bps) : "—" }
        StatCell { width: parent.cellWidth; caption: "DOWNLOADED"; value: root.iface ? Model.bytes(root.iface.rx_total) : "—" }
        StatCell { width: parent.cellWidth; caption: "UPLOADED"; value: root.iface ? Model.bytes(root.iface.tx_total) : "—" }
      }

      Sparkline {
        visible: !!root.iface
        width: parent.width
        height: Style.space(72)
        values: root.rxHistory
        values2: root.txHistory
        maxValue: 0
      }

      Item {
        visible: !!root.iface
        width: parent.width
        implicitHeight: legendLeft.implicitHeight

        Row {
          id: legendLeft
          spacing: Style.space(14)
          anchors.left: parent.left

          Row {
            spacing: Style.space(6)
            Rectangle { width: Style.space(10); height: 2; radius: 1; color: root.foreground; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "download"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          }
          Row {
            spacing: Style.space(6)
            Rectangle { width: Style.space(10); height: 2; radius: 1; color: root.alpha(root.foreground, 0.45); anchors.verticalCenter: parent.verticalCenter }
            Text { text: "upload"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          }
        }

        Text {
          anchors.right: parent.right
          text: "peak " + Model.rate(Math.max(Model.maxOf(root.rxHistory, 0), Model.maxOf(root.txHistory, 0)))
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      PanelSeparator { visible: root.ifaces.length > 1; foreground: root.foreground }

      // The other interfaces at a glance.
      Column {
        visible: root.ifaces.length > 1
        width: parent.width
        spacing: Style.spacing.labelGap

        Repeater {
          model: root.ifaces

          Item {
            required property var modelData
            visible: !root.iface || modelData.name !== root.iface.name
            width: parent.width
            implicitHeight: visible ? otherName.implicitHeight : 0

            Text {
              id: otherName
              text: modelData.name + (modelData.ip ? "  " + modelData.ip : "")
              color: modelData.up ? root.foreground : root.dim
              opacity: modelData.up ? 0.75 : 1
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: modelData.up ? "󰇚 " + Model.rate(modelData.rx_bps) + "   󰕒 " + Model.rate(modelData.tx_bps) : "down"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }
  }

  // ======================================================= GPU
  Component {
    id: gpuTab

    Column {
      spacing: Style.space(12)

      Text {
        visible: root.hasData && root.gpus.length === 0
        text: "No GPU detected"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Repeater {
        model: root.gpus

        Column {
          required property var modelData
          required property int index
          width: parent.width
          spacing: Style.space(10)

          readonly property bool hasBusy: modelData.busy !== null && modelData.busy !== undefined

          PanelSeparator { visible: index > 0; foreground: root.foreground }

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

          Meter { visible: hasBusy; value: hasBusy ? modelData.busy / 100 : 0; fillColor: root.stateColor(hasBusy ? modelData.busy : 0) }

          Sparkline {
            visible: index === 0 && hasBusy
            width: parent.width
            height: Style.space(56)
            values: root.gpuHistory
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
  }

  // ======================================================= Processes
  Component {
    id: procTabComponent

    Column {
      id: procTabRoot
      spacing: Style.space(8)

      function scrollTo(index) { procList.positionViewAtIndex(index, ListView.Contain) }
      function scrollToEdge(toEnd) { if (toEnd) procList.positionViewAtEnd(); else procList.positionViewAtBeginning() }
      function focusFilter() { filterField.forceActiveFocus(); filterField.selectAll() }
      function clearFilterField() { filterField.text = "" }

      Component.onCompleted: filterField.text = root.filterText
      Component.onDestruction: if (root.filtering) root.filtering = false

      // Summary line + filter box.
      Item {
        width: parent.width
        implicitHeight: Math.max(procSummary.implicitHeight, filterField.implicitHeight)

        Text {
          id: procSummary
          text: root.snapshot
            ? (root.filterText !== ""
                ? Model.count(root.sortedProcs.length) + " OF " + Model.count(root.processes.length) + " PROCESSES"
                : Model.count(root.snapshot.procs.total) + " PROCESSES  ·  " + Model.count(root.snapshot.procs.threads) + " THREADS")
            : ""
          color: root.faint
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        TextField {
          id: filterField
          width: Style.space(170)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "Filter  ( / )"
          foreground: root.foreground
          font.family: root.fontFamily
          onTextChanged: { if (text !== root.filterText) { root.filterText = text; root.procIndex = 0; root.rebuildProcs() } }
          onActiveFocusChanged: root.filtering = activeFocus
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              if (text !== "") root.clearFilter()
              else root.stopFiltering()
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Down) {
              root.stopFiltering()
              root.cursorActive = true
              event.accepted = true
            }
          }
        }
      }

      // Column headers double as the sort controls: click to sort by
      // that column, click again to flip the direction.
      Item {
        width: parent.width
        implicitHeight: Style.space(20)

        ColumnHeader { key: "name"; text: "Name"; anchors.left: parent.left; anchors.right: pidHeader.left; anchors.rightMargin: Style.space(8) }
        ColumnHeader { id: pidHeader; key: "pid"; text: "PID"; alignRight: true; width: Style.space(58); anchors.right: userHeader.left; anchors.rightMargin: Style.space(8) }
        ColumnHeader { id: userHeader; key: "user"; text: "User"; width: Style.space(70); anchors.right: memHeader.left; anchors.rightMargin: Style.space(8) }
        ColumnHeader { id: memHeader; key: "mem"; text: "Mem"; alignRight: true; width: Style.space(58); anchors.right: cpuHeader.left; anchors.rightMargin: Style.space(8) }
        ColumnHeader { id: cpuHeader; key: "cpu"; text: "CPU"; alignRight: true; width: Style.space(58); anchors.right: parent.right }
      }

      ListView {
        id: procList
        width: parent.width
        // A whole number of rows, so the list never ends on a half-cut line.
        height: Style.space(24) * 16
        clip: true
        model: procModel
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
          id: procRow
          required property var model
          required property int index
          width: procList.width
          height: Style.space(24) + (expanded ? detailBlock.implicitHeight + Style.space(10) : 0)

          readonly property bool current: root.cursorActive && root.procIndex === index
          readonly property bool expanded: root.selectedPid === procRow.model.pid
          readonly property bool paused: procRow.model.state === "T" || procRow.model.state === "t"

          Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

          Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: procRow.expanded ? Style.selectedFillFor(root.foreground, Color.accent)
                 : (procRow.current ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
          }

          // ---- the row itself
          Item {
            id: rowLine
            width: parent.width
            height: Style.space(24)

            Text {
              text: procRow.model.name
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: procRow.expanded
              elide: Text.ElideRight
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.right: cellPid.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              id: cellPid
              text: procRow.model.pid
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignRight
              width: Style.space(58)
              anchors.right: cellUser.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              id: cellUser
              text: procRow.model.user
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: Style.space(70)
              anchors.right: cellMem.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              id: cellMem
              text: Model.bytesShort(procRow.model.mem)
              color: root.sortKey === "mem" ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignRight
              width: Style.space(58)
              anchors.right: cellCpu.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              id: cellCpu
              text: Model.percent(procRow.model.cpu, 1)
              color: root.sortKey === "cpu" ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignRight
              width: Style.space(58)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea {
              id: rowHover
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: { root.cursorActive = true; root.cursorFromKeys = false; root.procIndex = procRow.index }
              onClicked: {
                root.cursorActive = true
                root.cursorFromKeys = false
                root.procIndex = procRow.index
                root.toggleSelected(procRow.model.pid)
              }
            }

            PanelToolTip {
              visible: rowHover.containsMouse && !procRow.expanded && procRow.model.cmd !== ""
              text: procRow.model.cmd
              fontFamily: root.fontFamily
            }
          }

          // ---- detail card: full command · facts · actions
          Column {
            id: detailBlock
            visible: procRow.expanded
            anchors.top: rowLine.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(6)

            Text {
              width: parent.width
              text: procRow.model.cmd !== "" ? procRow.model.cmd : "(kernel thread)"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WrapAnywhere
              maximumLineCount: 3
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: "PID " + procRow.model.pid + "  ·  parent " + procRow.model.ppid + "  ·  " + procRow.model.threads
                + (procRow.model.threads === 1 ? " thread" : " threads") + "  ·  " + Model.bytes(procRow.model.mem)
                + (procRow.paused ? "  ·  paused" : "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Row {
              spacing: Style.space(6)
              topPadding: Style.space(2)

              ActionPill { text: "Terminate"; tooltipText: "Send SIGTERM — ask it to quit"; onClicked: root.requestSignal(procRow.model, "TERM") }
              ActionPill { text: "Kill"; tooltipText: "Send SIGKILL — end it immediately"; onClicked: root.requestSignal(procRow.model, "KILL") }
              ActionPill {
                text: procRow.paused ? "Resume" : "Pause"
                tooltipText: procRow.paused ? "Send SIGCONT" : "Send SIGSTOP — freeze it, resumable"
                onClicked: root.requestSignal(procRow.model, procRow.paused ? "CONT" : "STOP")
              }
              ActionPill { text: "Close"; tooltipText: "Collapse (Esc)"; onClicked: root.selectedPid = -1 }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- components

  // Small bordered button for row actions.
  component ActionPill: Button {
    fontSize: Style.font.caption
    foreground: root.foreground
    fontFamily: root.fontFamily
    horizontalPadding: Style.space(10)
    verticalPadding: Style.space(3)
    bordered: true
  }

  // Transport glyph + name on the left, dim metadata flush right
  // (same anchored layout idiom as SectionRow).
  component DriveHeading: Item {
    property string glyphText: ""
    property string title: ""
    property real titleSize: Style.font.caption
    property string meta: ""
    property color accent: root.dim

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(headingGlyph.implicitHeight, headingName.implicitHeight)

    Text {
      id: headingGlyph
      text: glyphText
      color: accent
      font.family: Style.font.family
      font.pixelSize: Style.font.caption + 2
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: headingName
      text: title
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: titleSize
      elide: Text.ElideRight
      anchors.left: headingGlyph.right
      anchors.leftMargin: Style.space(8)
      anchors.right: headingMeta.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: headingMeta
      text: meta
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Label on the left, value on the right; the value optionally dimmed.
  component SectionRow: Item {
    property string label: ""
    property string value: ""
    property bool valueDim: false

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(sectionLabel.implicitHeight, sectionValue.implicitHeight)

    Text {
      id: sectionLabel
      text: label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
      anchors.left: parent.left
      anchors.right: sectionValue.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: sectionValue
      text: value
      color: valueDim ? root.dim : root.foreground
      font.family: root.fontFamily
      font.pixelSize: valueDim ? Style.font.caption : Style.font.body
      font.bold: !valueDim
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Rounded track with a proportional fill. Deliberately NOT animated: the
  // panel is a full-screen layer surface, and a per-tick width animation
  // forces it to re-render for ~300 ms of every second (~2.5% of a core);
  // snapping costs ~0.4%. Interaction-only animations (hover, expand) stay.
  component Meter: Item {
    id: meter
    property real value: 0
    property color fillColor: root.foreground
    property real thickness: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

    width: parent ? parent.width : implicitWidth
    implicitHeight: thickness

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: height / 2
      color: root.track
    }

    Rectangle {
      anchors.left: meterTrack.left
      anchors.verticalCenter: meterTrack.verticalCenter
      height: meterTrack.height
      radius: meterTrack.radius
      width: meterTrack.width * root.clamp(meter.value, 0, 1)
      color: meter.fillColor
    }
  }

  // Label · bar · amount, for memory breakdown rows.
  component ShareRow: Item {
    id: shareRow
    property string label: ""
    property real amount: 0
    property real total: 1
    property bool strong: false

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(shareLabel.implicitHeight, shareValue.implicitHeight) + Style.spacing.sm

    Text {
      id: shareLabel
      text: shareRow.label
      color: shareRow.strong ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: shareRow.strong
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(76)
    }

    Rectangle {
      anchors.left: shareLabel.right
      anchors.right: shareValue.left
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
      radius: height / 2
      color: root.track

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        radius: parent.radius
        width: parent.width * root.clamp(shareRow.total > 0 ? shareRow.amount / shareRow.total : 0, 0, 1)
        color: shareRow.strong ? root.foreground : root.alpha(root.foreground, 0.55)
      }
    }

    Text {
      id: shareValue
      text: Model.bytes(shareRow.amount)
      color: shareRow.strong ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: shareRow.strong
      horizontalAlignment: Text.AlignRight
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(70)
    }
  }

  // Caption over a value, for the network stat strip.
  component StatCell: Column {
    property string caption: ""
    property string value: ""
    spacing: Style.space(4)

    Text {
      text: caption
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }
    Text {
      text: value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
    }
  }

  // Sortable column header for the process table.
  component ColumnHeader: Item {
    id: header
    property string key: ""
    property string text: ""
    property bool alignRight: false
    readonly property bool activeSort: root.sortKey === key

    height: parent ? parent.height : Style.space(20)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: header.alignRight ? undefined : parent.left
      anchors.leftMargin: Style.space(6)
      anchors.right: header.alignRight ? parent.right : undefined
      anchors.rightMargin: Style.space(6)
      text: header.text.toUpperCase() + (header.activeSort ? (root.sortReverse ? " ▲" : " ▼") : "")
      color: header.activeSort || headerHover.containsMouse ? root.foreground : root.faint
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    MouseArea {
      id: headerHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.setSort(header.key)
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    Text {
      id: pairLabel
      text: label
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Item { width: Math.max(0, parent.width - pairLabel.implicitWidth - pairValue.implicitWidth - parent.spacing * 2); height: 1 }
    Text {
      id: pairValue
      text: value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  // Quiet line chart of the last N samples. Newest sample sits at the right
  // edge; the line grows in from the left until the buffer is full.
  component Sparkline: Canvas {
    id: spark
    property var values: []
    property var values2: []
    property real maxValue: 100     // <= 0 means autoscale to the data
    property color lineColor: root.foreground

    onValuesChanged: requestPaint()
    onValues2Changed: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var w = width, h = height
      var cap = root.historyLength
      var pad = 2
      var peak = spark.maxValue > 0 ? spark.maxValue : Math.max(Model.maxOf(spark.values, 0), Model.maxOf(spark.values2, 0))
      if (peak <= 0) peak = 1
      var fgc = String(spark.lineColor)

      // Faint baseline so an idle machine still reads as "a graph".
      ctx.globalAlpha = 0.12
      ctx.strokeStyle = fgc
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(0, h - 0.5)
      ctx.lineTo(w, h - 0.5)
      ctx.stroke()

      function drawSeries(vals, alphaLine, alphaFill) {
        var n = vals.length
        if (n < 2) return
        var step = w / Math.max(1, cap - 1)
        function x(i) { return w - (n - 1 - i) * step }
        function y(v) { return pad + (1 - root.clamp(v / peak, 0, 1)) * (h - pad * 2) }

        ctx.beginPath()
        ctx.moveTo(x(0), y(vals[0]))
        for (var i = 1; i < n; i++) ctx.lineTo(x(i), y(vals[i]))
        ctx.lineTo(x(n - 1), h)
        ctx.lineTo(x(0), h)
        ctx.closePath()
        ctx.globalAlpha = alphaFill
        ctx.fillStyle = fgc
        ctx.fill()

        ctx.beginPath()
        ctx.moveTo(x(0), y(vals[0]))
        for (i = 1; i < n; i++) ctx.lineTo(x(i), y(vals[i]))
        ctx.globalAlpha = alphaLine
        ctx.strokeStyle = fgc
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.stroke()
      }

      drawSeries(spark.values2 || [], 0.45, 0.04)
      drawSeries(spark.values || [], 1, 0.08)
    }
  }
}
