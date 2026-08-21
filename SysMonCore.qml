import QtQuick
import Quickshell.Io

/**
 * SysMonCore — shared data sampler for the SysMon plugin.
 *
 * Reads /proc/stat, /proc/meminfo, /proc/cpuinfo, thermal zones, and disk
 * usage via FileView (live-updated) and Process (df). Exposes properties
 * that bar segments and panels bind to.
 */
QtObject {
  id: core

  property int interval: 2
  property var history: ({ cpu: [], mem: [], temp: [] })
  property int maxHistory: 30

  // ── CPU ──────────────────────────────────────────────────────────────
  property real cpuPercent: 0
  property real cpuFreqMhz: 0
  property real cpuFreqGhz: 0
  property var corePercents: []
  property var loadAvg: [0, 0, 0]

  // Raw previous sample for delta calculation
  property var _prevCpu: null

  // ── Memory ───────────────────────────────────────────────────────────
  property real memTotal: 0
  property real memUsed: 0
  property real memFree: 0
  property real memBuffers: 0
  property real memCached: 0
  property real memPercent: 0
  property real swapTotal: 0
  property real swapUsed: 0
  property real swapPercent: 0

  // ── Temperature ──────────────────────────────────────────────────────
  property real tempCurrent: 0
  property var thermalZones: []

  // ── Disk ─────────────────────────────────────────────────────────────
  property real diskUsed: 0
  property real diskTotal: 0
  property real diskPercent: 0
  property var diskPartitions: []

  // ── Timers ───────────────────────────────────────────────────────────
  property var _timers: []

  Component.onCompleted: {
    _startTimers()
    _readAll()
  }

  function _startTimers() {
    // Main sample timer
    var t = Qt.createQmlObject(`
      import QtQuick
      Timer {
        interval: ${interval * 1000}
        running: true
        repeat: true
        onTriggered: _readAll()
      }
    `, core)
    _timers.push(t)
  }

  function _readAll() {
    _readCpuStat()
    _readCpuFreq()
    _readLoadAvg()
    _readMemInfo()
    _readThermal()
    _readDisk()
  }

  // ── /proc/stat (CPU usage) ──────────────────────────────────────────
  function _readCpuStat() {
    var proc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["head", "-n", "-1", "/proc/stat"]
        stdout: SplitParser { onRead: function(line) { core._parseCpuLine(line) } }
      }
    `, core)
    proc.running = true
    // Self-destruct after one shot
    proc.onRunningChanged.connect(function() {
      if (!proc.running) proc.destroy()
    })
  }

  function _parseCpuLine(line) {
    var parts = line.trim().split(/\s+/)
    if (parts.length < 5) return

    if (parts[0] === "cpu") {
      var idle = Number(parts[4])
      var total = 0
      for (var i = 1; i < parts.length; i++) total += Number(parts[i])

      if (_prevCpu) {
        var dTotal = total - _prevCpu.total
        var dIdle = idle - _prevCpu.idle
        cpuPercent = dTotal > 0 ? Math.round((1 - dIdle / dTotal) * 100) : 0
      }
      _prevCpu = { total: total, idle: idle }
      return
    }

    // Per-core: cpu0, cpu1, ...
    if (parts[0].match(/^cpu\d+$/)) {
      var coreIdle = Number(parts[4])
      var coreTotal = 0
      for (var j = 1; j < parts.length; j++) coreTotal += Number(parts[j])
      var idx = parseInt(parts[0].substring(3))
      // Extend array if needed
      while (corePercents.length <= idx) corePercents.push(0)
      if (coreTotal > 0) {
        // Simple approximation: use idle/total ratio
        var util = 1 - coreIdle / coreTotal
        corePercents[idx] = Math.round(util * 100)
      }
    }
  }

  // ── /proc/cpuinfo (frequency) ───────────────────────────────────────
  function _readCpuFreq() {
    var proc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["grep", "-m1", "cpu MHz", "/proc/cpuinfo"]
        stdout: SplitParser { onRead: function(line) { core._parseFreq(line) } }
      }
    `, core)
    proc.running = true
    proc.onRunningChanged.connect(function() {
      if (!proc.running) proc.destroy()
    })
  }

  function _parseFreq(line) {
    var match = line.match(/:\s*([\d.]+)/)
    if (match) {
      cpuFreqMhz = Math.round(Number(match[1]))
      cpuFreqGhz = (Number(match[1]) / 1000).toFixed(1)
    }
  }

  // ── /proc/loadavg ──────────────────────────────────────────────────
  function _readLoadAvg() {
    var proc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["cat", "/proc/loadavg"]
        stdout: SplitParser { onRead: function(line) { core._parseLoadAvg(line) } }
      }
    `, core)
    proc.running = true
    proc.onRunningChanged.connect(function() {
      if (!proc.running) proc.destroy()
    })
  }

  function _parseLoadAvg(line) {
    var parts = line.trim().split(/\s+/)
    if (parts.length >= 3) {
      loadAvg = [Number(parts[0]), Number(parts[1]), Number(parts[2])]
    }
  }

  // ── /proc/meminfo ──────────────────────────────────────────────────
  function _readMemInfo() {
    var proc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["grep", "-E", "^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree):", "/proc/meminfo"]
        stdout: SplitParser { onRead: function(line) { core._parseMemLine(line) } }
      }
    `, core)
    proc.running = true
    proc.onRunningChanged.connect(function() {
      if (!proc.running) proc.destroy()
    })
  }

  function _parseMemLine(line) {
    var match = line.match(/^(\w+):\s+(\d+)/)
    if (!match) return
    var key = match[1]
    var val = Number(match[2]) * 1024 // kB to bytes

    if (key === "MemTotal") memTotal = val
    else if (key === "MemFree") memFree = val
    else if (key === "Buffers") memBuffers = val
    else if (key === "Cached") memCached = val
    else if (key === "SwapTotal") swapTotal = val
    else if (key === "SwapFree") swapUsed = val // will compute

    // Derive
    if (memTotal > 0) {
      memUsed = memTotal - memFree - memBuffers - memCached
      memPercent = Math.round((memUsed / memTotal) * 100)
      _pushHistory("mem", memPercent)
    }
    if (swapTotal > 0) {
      swapUsed = swapTotal - swapUsed
      swapPercent = Math.round((swapUsed / swapTotal) * 100)
    }
  }

  // ── Thermal zones ──────────────────────────────────────────────────
  function _readThermal() {
    var proc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["sh", "-c", "for z in /sys/class/thermal/thermal_zone*; do echo $(cat $z/type 2>/dev/null)$(cat $z/temp 2>/dev/null); done"]
        stdout: SplitParser { onRead: function(line) { core._parseThermalLine(line) } }
      }
    `, core)
    proc.running = true
    proc.onRunningChanged.connect(function() {
      if (!proc.running) proc.destroy()
    })
    // Reset before re-read
    thermalZones = []
  }

  function _parseThermalLine(line) {
    if (line.trim() === "") return
    var match = line.trim().match(/^(.+?)(\d+)$/)
    if (match) {
      var zones = thermalZones.slice()
      zones.push({ name: match[1], temp: Number(match[2]) })
      thermalZones = zones
      if (zones.length === 1 || match[1].toLowerCase().indexOf("core") >= 0 || match[1].toLowerCase().indexOf("cpu") >= 0) {
        tempCurrent = Number(match[2])
      }
    }
    // Push history with last zone read
    if (tempCurrent > 0) _pushHistory("temp", tempCurrent)
  }

  // ── Disk usage ─────────────────────────────────────────────────────
  function _readDisk() {
    var proc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["df", "-B1", "--output=source,size,used,avail,pcent,target", "/"]
        stdout: SplitParser { onRead: function(line) { core._parseDiskLine(line) } }
      }
    `, core)
    proc.running = true
    proc.onRunningChanged.connect(function() {
      if (!proc.running) proc.destroy()
    })
    diskPartitions = []
  }

  function _parseDiskLine(line) {
    var parts = line.trim().split(/\s+/)
    if (parts.length < 6) return
    if (parts[0] === "Filesystem") return // header

    diskTotal = Number(parts[1])
    diskUsed = Number(parts[2])
    if (diskTotal > 0) {
      diskPercent = Math.round((diskUsed / diskTotal) * 100)
    }

    var partitions = diskPartitions.slice()
    partitions.push({
      device: parts[0],
      total: Number(parts[1]),
      used: Number(parts[2]),
      avail: Number(parts[3]),
      percent: Number(parts[4]),
      mount: parts[5]
    })
    diskPartitions = partitions
  }

  // ── History ─────────────────────────────────────────────────────────
  function _pushHistory(key, value) {
    var arr = history[key] ? history[key].slice() : []
    arr.push(value)
    if (arr.length > maxHistory) arr.shift()
    var h = ({})
    for (var k in history) h[k] = history[k]
    h[key] = arr
    history = h
  }

  function cpuHistory() { return history.cpu || [] }
  function memHistory() { return history.mem || [] }
  function tempHistory() { return history.temp || [] }
}
