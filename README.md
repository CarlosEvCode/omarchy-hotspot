# Wi-Fi Hotspot & Repeater for Omarchy (`evcode.hotspot`)

A native, high-performance status bar widget and interactive control panel for the [Omarchy](https://omarchy.org/) desktop shell. Create and manage Wi-Fi Hotspots and **simultaneous Wi-Fi Repeater chaining** directly from your top bar with dynamic upstream source routing, instant QR code pairing, real-time connected client monitor, and complete Omarchy theme integration.

---

## 🚀 Key Features

- 📡 **Simultaneous Wi-Fi Repeater & AP Chaining**:
  - Keep your active Wi-Fi connection alive while simultaneously broadcasting a secondary access point without needing third-party AUR daemons.
  - Automatic on-demand `ap0` interface lifecycle management (created only when active, destroyed when stopped).
- 🔀 **Dynamic Upstream Internet Selection**:
  - Route internet from **Automatic**, **Ethernet** (`enp...`), or **Wi-Fi** (`wlo...`).
  - Dropdown dynamically lists only active, connected interfaces in real-time.
- 📲 **Instant QR Code Sharing**:
  - Crisp, scannable QR matrix rendered directly in QML for instant smartphone pairing (iOS & Android).
  - One-click copy buttons for SSID and WPA2 passphrase.
- 👥 **Connected Devices & Traffic Monitor**:
  - Live list of connected devices with Hostname, IP address, and MAC address.
  - Wi-Fi signal strength meter (dBm with adaptive icons `󰤨`, `󰤥`, `󰤢`, `󰤟`).
  - Real-time download/upload traffic counters and connection duration.
- ⚙️ **Inline Network Settings**:
  - Customize SSID, WPA2-PSK password (with toggle visibility), and Wi-Fi frequency band (2.4 GHz / 5 GHz).
- 🎨 **100% Theme Integrated**:
  - Strictly follows Omarchy theme tokens (`root.bar.foreground`, `root.bar.background`, `Color.accent`, `root.bar.urgent`). Zero hardcoded colors.

---

## 📦 Dependencies

Install the core networking and QR tools via `pacman`:

```bash
sudo pacman -S --needed networkmanager iw iproute2 qrencode
```

---

## 🛠️ Installation

### Option 1: Via Omarchy Plugin Manager (Recommended once published)
```bash
omarchy plugin add https://github.com/evcode/omarchy-hotspot.git --enable
omarchy restart shell
```

### Option 2: Automatic Local Installer
Clone this repository and run the included installer:
```bash
git clone https://github.com/evcode/omarchy-hotspot.git
cd omarchy-hotspot
chmod +x install.sh
./install.sh
```

The installer will automatically:
1. Verify and install any missing system dependencies.
2. Configure passwordless `sudoers.d` rules for virtual AP interface management (`ap0`).
3. Deploy the backend CLI helper to `~/.local/bin/omarchy-hotspot`.
4. Install and enable the plugin in `~/.config/omarchy/plugins/evcode.hotspot/`.
5. Clear QML cache and restart Omarchy Shell.

---

## 💻 CLI Helper Usage

The backend can be controlled or scripted directly via `omarchy-hotspot`:

```bash
# View complete JSON state (SSID, IP, upstream, clients, QR matrix)
omarchy-hotspot status

# Start / Stop / Toggle Hotspot
omarchy-hotspot start [SSID] [PASSWORD] [BAND] [CHANNEL] [SECURITY] [UPSTREAM]
omarchy-hotspot stop
omarchy-hotspot toggle

# List connected clients
omarchy-hotspot clients

# Save default hotspot configuration
omarchy-hotspot save "MyHotspot" "mypassword123" "bg" "0" "wpa-psk" "auto"
```

---

## ⌨️ Controls & Shortcuts

| Action | Control |
|---|---|
| Open / Close Hotspot Panel | Left Click on bar widget |
| Toggle Hotspot Power On / Off | Right Click on bar widget |
| Dismiss Panel | `Esc` key or click outside |
| Toggle QR Code Overlay | Click **󰤨 Ver QR** |
| Configure SSID & Password | Click **󰒓 Ajustes** |

---

## 📄 License

[MIT](LICENSE) © 2026 evcode
