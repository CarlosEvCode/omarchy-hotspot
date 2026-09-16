// JavaScript helpers for evcode.hotspot plugin

function formatBytes(bytes) {
  if (bytes === undefined || bytes === null || isNaN(bytes) || bytes < 0) return "0 B"
  if (bytes < 1024) return bytes + " B"
  var kb = bytes / 1024
  if (kb < 1024) return kb.toFixed(1) + " KB"
  var mb = kb / 1024
  if (mb < 1024) return mb.toFixed(1) + " MB"
  var gb = mb / 1024
  return gb.toFixed(2) + " GB"
}

function formatDuration(seconds) {
  if (!seconds || seconds <= 0) return "Just now"
  var s = Math.floor(seconds)
  if (s < 60) return s + "s"
  var m = Math.floor(s / 60)
  if (m < 60) return m + "m"
  var h = Math.floor(m / 60)
  var remM = m % 60
  if (remM === 0) return h + "h"
  return h + "h " + remM + "m"
}

function signalDbmToPercent(dbm) {
  if (!dbm || isNaN(dbm)) return 50
  var d = Number(dbm)
  if (d <= -100) return 0
  if (d >= -50) return 100
  return Math.round(2 * (d + 100))
}

function signalIcon(dbm) {
  var pct = signalDbmToPercent(dbm)
  if (pct >= 75) return "󰤨"
  if (pct >= 50) return "󰤥"
  if (pct >= 25) return "󰤢"
  return "󰤟"
}

function parseQrMatrix(rows) {
  if (!rows || !rows.length) return { size: 0, rows: [] }
  var size = rows.length
  return { size: size, rows: rows }
}

if (typeof module !== "undefined") {
  module.exports = {
    formatBytes: formatBytes,
    formatDuration: formatDuration,
    signalDbmToPercent: signalDbmToPercent,
    signalIcon: signalIcon,
    parseQrMatrix: parseQrMatrix
  }
}
