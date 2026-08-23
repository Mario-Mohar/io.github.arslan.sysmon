import QtQuick
import Quickshell.Io

QtObject {
  id: root

  property int intervalMs: 2000
  property bool running: true

  // CPU
  property real cpuPercent: 0
  property real cpuFreqMhz: 0
  property real cpuFreqGhz: 0
  property string cpuModelName: ""
  property var corePercents: []
  property var loadAvg: [0, 0, 0]

  // Memory
  property real memTotal: 0
  property real memUsed: 0
  property real memFree: 0
  property real memBuffers: 0
  property real memCached: 0
  property real memPercent: 0
  property real swapTotal: 0
  property real swapUsed: 0
  property real swapPercent: 0

  // Temperature
  property real tempCurrent: 0
  property var thermalZones: []

  // Disk
  property real diskTotal: 0
  property real diskUsed: 0
  property real diskPercent: 0

  property FileView _statFile: FileView { path: "/proc/stat" }
  property FileView _memFile: FileView { path: "/proc/meminfo" }
  property FileView _loadFile: FileView { path: "/proc/loadavg" }
  property FileView _cpuInfoFile: FileView { path: "/proc/cpuinfo" }
  property FileView _thermalFile: FileView { path: "/sys/class/thermal/thermal_zone0/temp" }

  property var _diskProc: Process {
    command: ["df", "-B1", "--output=size,used,pcent", "/"]
    stdout: SplitParser { onRead: function(line) { root._parseDiskLine(line) } }
  }

  property var _tempProc: Process {
    command: ["sh", "-c", "for z in /sys/class/thermal/thermal_zone*; do echo $(basename $z):$(cat $z/temp 2>/dev/null); done"]
    stdout: SplitParser { onRead: function(line) { root._parseThermalZone(line) } }
  }

  property Timer _timer: Timer {
    interval: Math.max(500, root.intervalMs)
    running: root.running
    repeat: true
    triggeredOnStart: true
    onTriggered: root._tick()
  }

  property var _prevCpu: null

  function _tick() {
    _parseCpu(_statFile.text())
    _parseMem(_memFile.text())
    _parseLoad(_loadFile.text())
    _parseCpuFreq(_cpuInfoFile.text())
    _parseThermal(_thermalFile.text())
    _diskProc.running = true
    _tempProc.running = true
    _statFile.reload()
    _memFile.reload()
    _loadFile.reload()
    _cpuInfoFile.reload()
    _thermalFile.reload()
  }

  function _parseCpu(text) {
    var lines = String(text || "").split("\n")
    var cores = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line.substring(0, 4) === "cpu ") {
        var f = line.trim().split(/\s+/)
        var total = 0
        for (var j = 1; j < f.length; j++) total += Number(f[j])
        var idle = Number(f[4])
        if (_prevCpu) {
          var dTotal = total - _prevCpu.total
          var dIdle = idle - _prevCpu.idle
          cpuPercent = dTotal > 0 ? Math.round((1 - dIdle / dTotal) * 100) : 0
        }
        _prevCpu = { total: total, idle: idle }
      } else if (line.match(/^cpu\d/)) {
        var f2 = line.trim().split(/\s+/)
        var idx = parseInt(f2[0].substring(3))
        var total2 = 0
        for (var k = 1; k < f2.length; k++) total2 += Number(f2[k])
        var idle2 = Number(f2[4])
        while (cores.length <= idx) cores.push(0)
        if (total2 > 0) cores[idx] = Math.round((1 - idle2 / total2) * 100)
      }
    }
    corePercents = cores
  }

  function _parseMem(text) {
    var lines = String(text || "").split("\n")
    var vals = ({})
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^(\w+):\s+(\d+)/)
      if (m) vals[m[1]] = Number(m[2]) * 1024
    }
    memTotal = vals["MemTotal"] || 0
    memFree = vals["MemFree"] || 0
    memBuffers = vals["Buffers"] || 0
    memCached = vals["Cached"] || 0
    swapTotal = vals["SwapTotal"] || 0
    var swapFree = vals["SwapFree"] || 0

    if (memTotal > 0) {
      memUsed = memTotal - memFree - memBuffers - memCached
      memPercent = Math.round((memUsed / memTotal) * 100)
    }
    if (swapTotal > 0) {
      swapUsed = swapTotal - swapFree
      swapPercent = Math.round((swapUsed / swapTotal) * 100)
    }
  }

  function _parseLoad(text) {
    var parts = String(text || "").trim().split(/\s+/)
    if (parts.length >= 3) {
      loadAvg = [Number(parts[0]), Number(parts[1]), Number(parts[2])]
    }
  }

  function _parseCpuFreq(text) {
    var lines = String(text || "").split("\n")
    var freqDone = false
    var nameDone = false
    for (var i = 0; i < lines.length; i++) {
      if (!freqDone) {
        var m = lines[i].match(/cpu MHz\s*:\s*([\d.]+)/)
        if (m) {
          cpuFreqMhz = Math.round(Number(m[1]))
          cpuFreqGhz = (Number(m[1]) / 1000).toFixed(1)
          freqDone = true
        }
      }
      if (!nameDone) {
        var mName = lines[i].match(/model name\s*:\s*(.+)/)
        if (mName) {
          cpuModelName = mName[1].trim()
          nameDone = true
        }
      }
      if (freqDone && nameDone) return
    }
  }

  function _parseThermal(text) {
    var val = parseInt(String(text || "").trim())
    if (!isNaN(val)) tempCurrent = val
  }

  function _parseThermalZone(line) {
    var parts = line.split(":")
    if (parts.length !== 2) return
    var name = parts[0].trim()
    var temp = parseInt(parts[1].trim())
    if (isNaN(temp)) return
    var zones = thermalZones.slice()
    // Update existing or add new
    var found = false
    for (var i = 0; i < zones.length; i++) {
      if (zones[i].name === name) {
        zones[i] = { name: name, temp: temp }
        found = true
        break
      }
    }
    if (!found) zones.push({ name: name, temp: temp })
    thermalZones = zones
  }

  function _parseDiskLine(line) {
    var parts = line.trim().split(/\s+/)
    if (parts.length < 3) return
    if (parts[0] === "Size") return
    diskTotal = Number(parts[0])
    diskUsed = Number(parts[1])
    if (diskTotal > 0) diskPercent = Math.round((diskUsed / diskTotal) * 100)
  }
}
