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

// User-facing strings, selected by system language (default: English)
var STRINGS = {
  en: {
    copied: "Copied to clipboard!",
    starting: "Starting Hotspot...",
    stopping: "Stopping Hotspot...",
    switchingSource: "Switching source to %1...",
    automatic: "Automatic",
    autoRecommended: "Automatic (Recommended)",
    applyingSettings: "Applying settings...",
    hotspotActive: "Hotspot active",
    hotspotStopped: "Hotspot stopped",
    actionError: "Action failed",
    clientsConnected: "%1 connected",
    hotspotInactiveTooltip: "Hotspot: Inactive",
    disableHotspot: "Disable Hotspot",
    enableHotspot: "Enable Hotspot",
    title: "Wi-Fi Hotspot",
    inactiveShare: "Inactive (click to share internet)",
    shareFrom: "Share internet from:",
    tipEthernet: "Share exclusively from Ethernet cable",
    tipWifi: "Share from Wi-Fi connection (repeater mode)",
    tipAuto: "Automatic (uses the main network with internet access)",
    activeSource: "Active source: ",
    client: "Client",
    network: "Network",
    hideQr: "󰅁 Hide QR",
    showQr: "󰤨 View QR",
    closeSettings: "󰅁 Close Settings",
    settings: "󰒓 Settings",
    refreshStatus: "Refresh status",
    connectDevices: "Connect Devices",
    scanQr: "Scan the QR code with your phone's camera to connect:",
    copySsid: "Copy SSID",
    passwordLabel: "Password: ",
    copyPassword: "Copy Password",
    networkSettings: "Network Settings",
    ssidLabel: "Network Name (SSID):",
    ssidPlaceholder: "E.g. MyHotspot",
    passwordMin: "Password (minimum 8 characters):",
    wpa2Placeholder: "WPA2 Password",
    bandLabel: "Frequency Band:",
    securityLabel: "Security:",
    openNetwork: "Open Network",
    saveRestart: "󰄬 Save & Restart Hotspot",
    saveSettings: "󰄬 Save Settings",
    connectedDevices: "Connected Devices",
    device: "Device",
    signalLabel: "Signal: ",
    noDevices: "No devices connected yet",
    enableToShare: "Enable the Hotspot to share your connection"
  },
  es: {
    copied: "¡Copiado al portapapeles!",
    starting: "Iniciando Hotspot...",
    stopping: "Deteniendo Hotspot...",
    switchingSource: "Cambiando fuente a %1...",
    automatic: "Automático",
    autoRecommended: "Automático (Recomendado)",
    applyingSettings: "Aplicando configuración...",
    hotspotActive: "Hotspot activo",
    hotspotStopped: "Hotspot detenido",
    actionError: "Error al ejecutar la acción",
    clientsConnected: "%1 conectados",
    hotspotInactiveTooltip: "Hotspot: Inactivo",
    disableHotspot: "Desactivar Hotspot",
    enableHotspot: "Activar Hotspot",
    title: "Zona Wi-Fi / Hotspot",
    inactiveShare: "Inactivo (Haz clic para compartir internet)",
    shareFrom: "Compartir internet desde:",
    tipEthernet: "Compartir exclusivamente desde cable Ethernet",
    tipWifi: "Compartir desde conexión Wi-Fi (Modo repetidor)",
    tipAuto: "Automático (Usa la red principal con salida a internet)",
    activeSource: "Fuente activa: ",
    client: "Cliente",
    network: "Red",
    hideQr: "󰅁 Ocultar QR",
    showQr: "󰤨 Ver QR",
    closeSettings: "󰅁 Cerrar Ajustes",
    settings: "󰒓 Configuración",
    refreshStatus: "Actualizar estado",
    connectDevices: "Conectar Dispositivos",
    scanQr: "Escanea el código QR con la cámara de tu móvil para conectarte:",
    copySsid: "Copiar Red",
    passwordLabel: "Contraseña: ",
    copyPassword: "Copiar Clave",
    networkSettings: "Configuración de Red",
    ssidLabel: "Nombre de la Red (SSID):",
    ssidPlaceholder: "Ej. MiHotspot",
    passwordMin: "Contraseña (mínimo 8 caracteres):",
    wpa2Placeholder: "Contraseña WPA2",
    bandLabel: "Banda de Frecuencia:",
    securityLabel: "Seguridad:",
    openNetwork: "Red Abierta",
    saveRestart: "󰄬 Guardar y Reiniciar Hotspot",
    saveSettings: "󰄬 Guardar Configuración",
    connectedDevices: "Dispositivos Conectados",
    device: "Dispositivo",
    signalLabel: "Señal: ",
    noDevices: "No hay dispositivos conectados aún",
    enableToShare: "Activa el Hotspot para compartir conexión"
  }
}

function lang() {
  var name = "en"
  try {
    if (typeof Qt !== "undefined" && Qt.locale) name = Qt.locale().name || "en"
  } catch (e) {}
  name = String(name).replace(/\..*$/, "").split(/[_-]/)[0].toLowerCase()
  return STRINGS[name] ? name : "en"
}

function tr(key) {
  var s = STRINGS[lang()][key] || STRINGS.en[key] || key
  for (var i = 1; i < arguments.length; i++) {
    s = s.split("%" + i).join(arguments[i])
  }
  return s
}

if (typeof module !== "undefined") {
  module.exports = {
    formatBytes: formatBytes,
    formatDuration: formatDuration,
    signalDbmToPercent: signalDbmToPercent,
    signalIcon: signalIcon,
    parseQrMatrix: parseQrMatrix,
    lang: lang,
    tr: tr
  }
}
