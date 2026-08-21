/**
 * Format helpers — adapted from omarchy-vitals Model.js
 *
 * Each function is exported as a standalone JS object property so QML can
 * call e.g. `Fmt.bytes(value)` or `Fmt.percent(value)`.
 */
.pragma library

function bytes(value) {
  if (value === undefined || value === null || isNaN(value)) return "0 B"
  var units = ["B", "KB", "MB", "GB", "TB"]
  var i = 0
  var v = Math.abs(Number(value))
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
  return (i === 0 ? v : v.toFixed(1)) + " " + units[i]
}

function percent(value) {
  if (value === undefined || value === null || isNaN(value)) return "0%"
  return Math.round(Number(value)) + "%"
}

function temp(value) {
  if (value === undefined || value === null || isNaN(value)) return "0°C"
  var v = Number(value)
  // If value looks like millidegrees (>= 1000), convert
  if (Math.abs(v) >= 1000) v = v / 1000
  return Math.round(v) + "°C"
}

function mhz(value) {
  if (value === undefined || value === null || isNaN(value)) return "0 MHz"
  var v = Number(value)
  // If value is in KHz (>= 100000), convert to MHz
  if (v >= 100000) v = v / 1000
  if (v >= 1000) return (v / 1000).toFixed(1) + " GHz"
  return Math.round(v) + " MHz"
}

function rate(bytesPerSec) {
  if (bytesPerSec === undefined || bytesPerSec === null || isNaN(bytesPerSec)) return "0 B/s"
  var units = ["B/s", "KB/s", "MB/s", "GB/s"]
  var i = 0
  var v = Math.abs(Number(bytesPerSec))
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
  return (i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i]
}

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v))
}
