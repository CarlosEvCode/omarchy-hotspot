import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "evcode.hotspot"
  ipcTarget: "evcode.hotspot"
  manageIpc: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function close() {
    root.controller.hide()
    qrViewOpen = false
    settingsOpen = false
  }

  // Path to backend helper
  readonly property string pluginDir: {
    var url = Qt.resolvedUrl(".").toString()
    if (url.indexOf("file://") === 0) url = url.substring(7)
    if (url.length > 1 && url.charAt(url.length - 1) === "/") url = url.substring(0, url.length - 1)
    return decodeURIComponent(url)
  }
  readonly property string helperBin: pluginDir + "/bin/omarchy-hotspot"

  // Live status data
  property var statusData: ({})
  readonly property bool active: statusData && statusData.active === true
  property bool desiredActive: false
  readonly property string ssid: statusData && statusData.ssid ? statusData.ssid : "Omarchy-Hotspot"
  readonly property string password: statusData && statusData.password ? statusData.password : ""
  readonly property string band: statusData && statusData.band ? statusData.band : "bg"
  readonly property string channel: statusData && statusData.channel ? String(statusData.channel) : "0"
  readonly property string security: statusData && statusData.security ? statusData.security : "wpa-psk"
  readonly property string upstreamPreference: statusData && statusData.upstream_preference ? statusData.upstream_preference : "auto"
  readonly property string ipAddress: statusData && statusData.ip ? statusData.ip : "10.42.0.1"
  readonly property var upstream: statusData && statusData.upstream ? statusData.upstream : ({})
  readonly property int clientsCount: statusData && statusData.clients_count ? Number(statusData.clients_count) : 0
  readonly property var clientsList: statusData && statusData.clients ? statusData.clients : []
  readonly property var upstreamsList: statusData && statusData.upstreams && statusData.upstreams.length > 0 ? statusData.upstreams : [{ id: "auto", label: Model.tr("autoRecommended"), available: true }]
  readonly property var qrData: statusData && statusData.qr ? statusData.qr : ({ size: 0, rows: [] })

  // UI state
  property bool qrViewOpen: false
  property bool settingsOpen: false
  property bool showPassword: false
  property bool busy: false
  property string statusMsg: ""
  property bool statusIsError: false

  // Settings form model
  property string editSsid: ""
  property string editPassword: ""
  property string editBand: "bg"
  property string editSecurity: "wpa-psk"
  property string editUpstreamPref: "auto"

  // Icon for bar and hero
  readonly property string iconText: active ? "󱛂" : "󱛄"

  onActiveChanged: {
    desiredActive = active
  }

  function copyToClipboard(text) {
    if (!text) return
    Quickshell.execDetached(["wl-copy", String(text)])
    statusMsg = Model.tr("copied")
    statusIsError = false
    msgTimer.restart()
  }

  function refreshStatus() {
    if (!statusProc.running) {
      statusProc.running = true
    }
  }

  function toggleHotspot() {
    if (busy) return
    busy = true
    desiredActive = !active
    statusMsg = Model.tr(desiredActive ? "starting" : "stopping")
    statusIsError = false
    actionProc.secret = editPassword || root.password
    actionProc.command = [root.helperBin, "toggle"]
    actionProc.running = true
  }

  function startHotspot() {
    if (busy) return
    busy = true
    desiredActive = true
    statusMsg = Model.tr("starting")
    statusIsError = false
    actionProc.secret = editPassword || root.password
    actionProc.command = [root.helperBin, "start", editSsid || root.ssid, editBand || root.band, "0", editSecurity || root.security, editUpstreamPref || root.upstreamPreference]
    actionProc.running = true
  }

  function stopHotspot() {
    if (busy) return
    busy = true
    desiredActive = false
    statusMsg = Model.tr("stopping")
    statusIsError = false
    actionProc.secret = ""
    actionProc.command = [root.helperBin, "stop"]
    actionProc.running = true
  }

  function setUpstream(prefId) {
    if (busy) return
    editUpstreamPref = prefId
    busy = true
    statusMsg = Model.tr("switchingSource", prefId === "ethernet" ? "Ethernet" : (prefId === "wifi" ? "Wi-Fi" : Model.tr("automatic")))
    statusIsError = false
    actionProc.secret = ""
    actionProc.command = [root.helperBin, "set-upstream", prefId]
    actionProc.running = true
  }

  function applySettings() {
    if (busy) return
    busy = true
    statusMsg = Model.tr("applyingSettings")
    statusIsError = false
    actionProc.secret = editPassword || root.password
    if (active) {
      actionProc.command = [root.helperBin, "start", editSsid || root.ssid, editBand || root.band, "0", editSecurity || root.security, editUpstreamPref || root.upstreamPreference]
    } else {
      actionProc.command = [root.helperBin, "save", editSsid || root.ssid, editBand || root.band, "0", editSecurity || root.security, editUpstreamPref || root.upstreamPreference]
    }
    actionProc.running = true
  }

  function syncFormFromStatus() {
    editSsid = root.ssid
    editPassword = root.password
    editBand = root.band
    editSecurity = root.security
    editUpstreamPref = root.upstreamPreference
    desiredActive = root.active
  }

  onOpenedChanged: {
    if (root.opened) {
      refreshStatus()
      syncFormFromStatus()
    }
  }

  Component.onCompleted: {
    refreshStatus()
  }

  // Periodic status poll
  Timer {
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    id: msgTimer
    interval: 3500
    repeat: false
    onTriggered: {
      root.statusMsg = ""
      root.statusIsError = false
    }
  }

  // Status fetch process
  Process {
    id: statusProc
    command: [root.helperBin, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var res = JSON.parse(text || "{}")
          if (res && res.active !== undefined) {
            root.statusData = res
            root.desiredActive = res.active === true
            if (!root.settingsOpen && (!root.editSsid || root.editSsid === "")) {
              root.syncFormFromStatus()
            }
          }
        } catch (e) {}
      }
    }
  }

  // Action execution process
  Process {
    id: actionProc
    property string secret: ""
    stdinEnabled: true
    onStarted: {
      if (secret) {
        write(secret + "\n")
        secret = ""
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var res = JSON.parse(text || "{}")
          if (res && res.active !== undefined) {
            root.statusData = res
            root.desiredActive = res.active === true
            root.syncFormFromStatus()
          }
        } catch (e) {}
      }
    }
    onExited: function(exitCode, exitStatus) {
      root.busy = false
      if (exitCode === 0) {
        root.statusMsg = Model.tr(root.active ? "hotspotActive" : "hotspotStopped")
        root.statusIsError = false
      } else {
        root.statusMsg = Model.tr("actionError")
        root.statusIsError = true
      }
      msgTimer.restart()
      root.refreshStatus()
    }
  }

  IpcHandler {
    target: "evcode.hotspot"
    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function toggleHotspot() { root.toggleHotspot() }
  }

  // Bar Widget Icon Button
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.iconText
    active: root.active
    tooltipText: {
      if (root.active) {
        return "Hotspot: " + root.ssid + (root.clientsCount > 0 ? " (" + Model.tr("clientsConnected", root.clientsCount) + ")" : "")
      }
      return Model.tr("hotspotInactiveTooltip")
    }
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleHotspot()
      else root.toggle()
    }
  }

  // Popup panel surface
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: mainColumn
        anchors.fill: parent
        spacing: Style.space(12)

        // ==========================================
        // 1. Hero Card: Hotspot State & Power Switch
        // ==========================================
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, powerSwitch.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconText
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            opacity: root.active ? 1.0 : 0.5
          }

          ToggleSwitch {
            id: powerSwitch
            checked: root.desiredActive
            busy: root.busy
            foreground: root.bar.foreground
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onToggled: {
              root.desiredActive = !root.active
              root.toggleHotspot()
            }

            PanelToolTip {
              visible: powerSwitch.containsMouse
              text: Model.tr(root.active ? "disableHotspot" : "enableHotspot")
              fontFamily: root.bar.fontFamily
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: powerSwitch.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: Model.tr("title")
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: {
                if (root.active) {
                  return root.ssid + " · " + root.ipAddress
                }
                return Model.tr("inactiveShare")
              }
              color: root.active ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.4)
              opacity: root.active ? 0.9 : 0.6
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        // ==========================================
        // 2. Upstream Internet Source Selector
        // ==========================================
        Column {
          width: parent.width
          spacing: Style.space(6)

          Text {
            text: Model.tr("shareFrom")
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            opacity: 0.8
          }

          RowLayout {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.upstreamsList

              Button {
                Layout.fillWidth: true
                text: {
                  if (modelData.id === "ethernet") return "󰈀 Ethernet"
                  if (modelData.id === "wifi") return "󰤨 Wi-Fi"
                  return "󰛳 Auto"
                }
                tooltipText: {
                  if (modelData.id === "ethernet") return Model.tr("tipEthernet")
                  if (modelData.id === "wifi") return Model.tr("tipWifi")
                  return Model.tr("tipAuto")
                }
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.bodySmall
                bordered: true
                selected: (root.editUpstreamPref === modelData.id) || (root.upstreamPreference === modelData.id)
                enabled: !root.busy
                onClicked: root.setUpstream(modelData.id)
              }
            }
          }

          // Active source subtitle
          Item {
            width: parent.width
            implicitHeight: activeSourceRow.implicitHeight + Style.space(6)
            visible: !!(root.upstream && root.upstream.type && root.upstream.type !== "none")

            Rectangle {
              anchors.fill: parent
              color: root.bar.background
              opacity: 0.4
              radius: Style.cornerRadius
            }

            RowLayout {
              id: activeSourceRow
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                text: root.upstream.type === "ethernet" ? "󰈀" : (root.upstream.type === "wifi" ? "󰤨" : "󰛳")
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
              }

              Text {
                Layout.fillWidth: true
                text: {
                  var t = root.upstream.type === "ethernet" ? "Ethernet" : (root.upstream.type === "wifi" ? "Wi-Fi (" + (root.upstream.name || Model.tr("client")) + ")" : Model.tr("network"))
                  var ip = root.upstream.ip ? " · " + root.upstream.ip : ""
                  return Model.tr("activeSource") + t + ip
                }
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                opacity: 0.8
                elide: Text.ElideRight
              }
            }
          }
        }

        // Status or feedback message
        Item {
          width: parent.width
          implicitHeight: statusMsgText.implicitHeight
          visible: root.statusMsg !== ""

          Text {
            id: statusMsgText
            anchors.fill: parent
            text: root.statusMsg
            color: root.statusIsError ? root.bar.urgent : root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
          }
        }

        // ==========================================
        // 3. Quick Action Pills (QR / Config / Refresh)
        // ==========================================
        RowLayout {
          width: parent.width
          spacing: Style.space(8)

          Button {
            Layout.fillWidth: true
            text: Model.tr(root.qrViewOpen ? "hideQr" : "showQr")
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            bordered: true
            selected: root.qrViewOpen
            onClicked: {
              root.qrViewOpen = !root.qrViewOpen
              if (root.qrViewOpen) root.settingsOpen = false
            }
          }

          Button {
            Layout.fillWidth: true
            text: Model.tr(root.settingsOpen ? "closeSettings" : "settings")
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            bordered: true
            selected: root.settingsOpen
            onClicked: {
              root.settingsOpen = !root.settingsOpen
              if (root.settingsOpen) {
                root.qrViewOpen = false
                root.syncFormFromStatus()
              }
            }
          }

          PanelActionButton {
            iconText: "󰑐"
            tooltipText: Model.tr("refreshStatus")
            fontFamily: root.bar.fontFamily
            onClicked: root.refreshStatus()
          }
        }

        // ==========================================
        // 4. QR Code View (Expandable Card)
        // ==========================================
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.qrViewOpen

          Rectangle {
            width: parent.width
            implicitHeight: qrCardCol.implicitHeight + Style.space(16)
            color: root.bar.background
            opacity: 0.6
            radius: Style.cornerRadius
            border.color: root.bar.foreground
            border.width: 1

            Column {
              id: qrCardCol
              anchors.centerIn: parent
              width: parent.width - Style.space(24)
              spacing: Style.space(10)

              Text {
                text: Model.tr("connectDevices")
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
              }

              Text {
                text: Model.tr("scanQr")
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                opacity: 0.8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
              }

              // QR Code Graphic Matrix
              Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.space(160)
                height: Style.space(160)
                visible: root.qrData && root.qrData.size > 0

                Rectangle {
                  anchors.fill: parent
                  color: "white"
                  radius: Style.cornerRadius

                  Grid {
                    id: qrGrid
                    anchors.centerIn: parent
                    columns: root.qrData.size || 1
                    rows: root.qrData.size || 1
                    spacing: 0

                    Repeater {
                      model: (root.qrData.size || 0) * (root.qrData.size || 0)
                      Rectangle {
                        readonly property int rSize: root.qrData.size || 1
                        readonly property int rIdx: Math.floor(index / rSize)
                        readonly property int cIdx: index % rSize
                        readonly property string rowStr: root.qrData.rows && root.qrData.rows[rIdx] ? root.qrData.rows[rIdx] : ""
                        readonly property bool isDark: rowStr.length > cIdx && rowStr.charAt(cIdx) === "1"

                        width: Math.floor(Style.space(144) / rSize)
                        height: width
                        color: isDark ? "black" : "white"
                      }
                    }
                  }
                }
              }

              // Network Name & Password details with copy buttons
              RowLayout {
                width: parent.width
                spacing: Style.space(6)

                Text {
                  text: "SSID: " + root.ssid
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Button {
                  text: Model.tr("copySsid")
                  fontFamily: root.bar.fontFamily
                  fontSize: Style.font.bodySmall
                  bordered: true
                  onClicked: root.copyToClipboard(root.ssid)
                }
              }

              RowLayout {
                width: parent.width
                spacing: Style.space(6)
                visible: root.password !== ""

                Text {
                  text: Model.tr("passwordLabel") + (root.showPassword ? root.password : "••••••••")
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                PanelActionButton {
                  iconText: root.showPassword ? "󰈈" : "󰈉"
                  fontFamily: root.bar.fontFamily
                  onClicked: root.showPassword = !root.showPassword
                }

                Button {
                  text: Model.tr("copyPassword")
                  fontFamily: root.bar.fontFamily
                  fontSize: Style.font.bodySmall
                  bordered: true
                  onClicked: root.copyToClipboard(root.password)
                }
              }
            }
          }
        }

        // ==========================================
        // 5. Hotspot Configuration (Settings Card)
        // ==========================================
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.settingsOpen

          Rectangle {
            width: parent.width
            implicitHeight: settingsCol.implicitHeight + Style.space(16)
            color: root.bar.background
            opacity: 0.6
            radius: Style.cornerRadius
            border.color: root.bar.foreground
            border.width: 1

            Column {
              id: settingsCol
              anchors.centerIn: parent
              width: parent.width - Style.space(24)
              spacing: Style.space(8)

              Text {
                text: Model.tr("networkSettings")
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              // SSID Input
              Text {
                text: Model.tr("ssidLabel")
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                opacity: 0.8
              }

              TextField {
                id: ssidInput
                width: parent.width
                text: root.editSsid
                placeholderText: Model.tr("ssidPlaceholder")
                onTextChanged: root.editSsid = text
              }

              // Password Input
              Text {
                text: Model.tr("passwordMin")
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                opacity: 0.8
              }

              RowLayout {
                width: parent.width
                spacing: Style.space(6)

                TextField {
                  id: passwordInput
                  Layout.fillWidth: true
                  text: root.editPassword
                  password: !root.showPassword
                  placeholderText: Model.tr("wpa2Placeholder")
                  onTextChanged: root.editPassword = text
                }

                PanelActionButton {
                  iconText: root.showPassword ? "󰈈" : "󰈉"
                  fontFamily: root.bar.fontFamily
                  onClicked: root.showPassword = !root.showPassword
                }
              }

              // Band selection
              Text {
                text: Model.tr("bandLabel")
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                opacity: 0.8
              }

              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                Button {
                  Layout.fillWidth: true
                  text: "2.4 GHz (bg)"
                  fontFamily: root.bar.fontFamily
                  fontSize: Style.font.bodySmall
                  bordered: true
                  selected: root.editBand === "bg"
                  onClicked: root.editBand = "bg"
                }

                Button {
                  Layout.fillWidth: true
                  text: "5 GHz (a)"
                  fontFamily: root.bar.fontFamily
                  fontSize: Style.font.bodySmall
                  bordered: true
                  selected: root.editBand === "a"
                  onClicked: root.editBand = "a"
                }
              }

              // Security mode selection
              Text {
                text: Model.tr("securityLabel")
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                opacity: 0.8
              }

              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                Button {
                  Layout.fillWidth: true
                  text: "WPA2-PSK"
                  fontFamily: root.bar.fontFamily
                  fontSize: Style.font.bodySmall
                  bordered: true
                  selected: root.editSecurity === "wpa-psk"
                  onClicked: root.editSecurity = "wpa-psk"
                }

                Button {
                  Layout.fillWidth: true
                  text: Model.tr("openNetwork")
                  fontFamily: root.bar.fontFamily
                  fontSize: Style.font.bodySmall
                  bordered: true
                  selected: root.editSecurity === "open"
                  onClicked: root.editSecurity = "open"
                }
              }

              // Save & Apply Button
              Button {
                width: parent.width
                text: Model.tr(root.active ? "saveRestart" : "saveSettings")
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.bodySmall
                bordered: true
                active: true
                enabled: !root.busy && (root.editSecurity === "open" || root.editPassword.length >= 8)
                onClicked: {
                  root.applySettings()
                  root.settingsOpen = false
                }
              }
            }
          }
        }

        // ==========================================
        // 6. Connected Devices Section
        // ==========================================
        Column {
          width: parent.width
          spacing: Style.space(6)

          RowLayout {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: Model.tr("connectedDevices")
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              Layout.fillWidth: true
            }

            Rectangle {
              implicitWidth: clientBadgeText.implicitWidth + Style.space(12)
              implicitHeight: clientBadgeText.implicitHeight + Style.space(4)
              color: root.active && root.clientsCount > 0 ? Style.selectedFillFor(root.bar.foreground, Color.accent) : Style.normalFillFor(root.bar.foreground)
              radius: Style.cornerRadius

              Text {
                id: clientBadgeText
                anchors.centerIn: parent
                text: String(root.clientsCount)
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
            }
          }

          // Devices list
          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.clientsList && root.clientsList.length > 0

            Repeater {
              model: root.clientsList

              Rectangle {
                width: parent.width
                implicitHeight: deviceRow.implicitHeight + Style.space(12)
                color: root.bar.background
                opacity: 0.5
                radius: Style.cornerRadius

                RowLayout {
                  id: deviceRow
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(8)

                  Text {
                    text: "󰌢"
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.title
                  }

                  Column {
                    Layout.fillWidth: true
                    spacing: Style.space(2)

                    Text {
                      text: modelData.hostname || modelData.mac || Model.tr("device")
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      text: (modelData.ip !== "unknown" ? modelData.ip + " · " : "") + modelData.mac
                      color: root.bar.foreground
                      opacity: 0.7
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      elide: Text.ElideRight
                      width: parent.width
                    }
                  }

                  // Signal strength icon
                  Text {
                    text: Model.signalIcon(modelData.signal)
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    PanelToolTip {
                      visible: parent.containsMouse
                      text: Model.tr("signalLabel") + (modelData.signal || "-60") + " dBm"
                      fontFamily: root.bar.fontFamily
                    }
                  }

                  // Transfer stats badge
                  Column {
                    spacing: 0
                    visible: modelData.rx_bytes > 0 || modelData.tx_bytes > 0

                    Text {
                      text: "↓ " + Model.formatBytes(modelData.rx_bytes)
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      opacity: 0.6
                      horizontalAlignment: Text.AlignRight
                    }

                    Text {
                      text: "↑ " + Model.formatBytes(modelData.tx_bytes)
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      opacity: 0.6
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }
              }
            }
          }

          // Empty state message
          Item {
            width: parent.width
            implicitHeight: Style.space(36)
            visible: !root.clientsList || root.clientsList.length === 0

            Text {
              anchors.centerIn: parent
              text: Model.tr(root.active ? "noDevices" : "enableToShare")
              color: root.bar.foreground
              opacity: 0.5
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }
}
