#!/bin/bash

# Script de instalación automática para el plugin evcode.hotspot en Omarchy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6)"
: "${REAL_HOME:=$HOME}"

TARGET_DIR="$REAL_HOME/.config/omarchy/plugins/evcode.hotspot"
BIN_DIR="$REAL_HOME/.local/bin"

echo "=== Instalando Plugin Hotspot para Omarchy ==="

# 1. Verificar e instalar dependencias del sistema
DEPS=("networkmanager" "iw" "iproute2" "qrencode")
MISSING=()

for dep in "${DEPS[@]}"; do
  if ! pacman -Qi "$dep" >/dev/null 2>&1; then
    MISSING+=("$dep")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "[*] Instalando dependencias necesarias: ${MISSING[*]}"
  sudo pacman -S --needed --noconfirm "${MISSING[@]}"
else
  echo "[✓] Todas las dependencias están instaladas (${DEPS[*]})"
fi

# 2. Configurar regla de sudoers para AP virtual en modo repetidor (sin contraseña)
SUDOERS_FILE="/etc/sudoers.d/omarchy-hotspot-ap"
RULE="$REAL_USER ALL=(ALL) NOPASSWD: /usr/bin/iw phy * interface add ap0 type __ap, /usr/bin/iw dev ap0 del, /usr/bin/ip link set ap0 *"

if [[ ! -f "$SUDOERS_FILE" ]] || ! sudo grep -q "interface add ap0 type __ap" "$SUDOERS_FILE" 2>/dev/null; then
  echo "[*] Configurando permisos sudo para AP virtual en modo repetidor..."
  echo "$RULE" | sudo tee "$SUDOERS_FILE" >/dev/null
  sudo chmod 0440 "$SUDOERS_FILE"
  echo "[✓] Regla sudoers creada en $SUDOERS_FILE"
else
  echo "[✓] Regla sudoers ya configurada"
fi

# 3. Instalar CLI helper en ~/.local/bin
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/bin/omarchy-hotspot" "$BIN_DIR/omarchy-hotspot"
chmod +x "$BIN_DIR/omarchy-hotspot"
chown "$REAL_USER":"$REAL_USER" "$BIN_DIR/omarchy-hotspot" 2>/dev/null || true
echo "[✓] Helper instalado en $BIN_DIR/omarchy-hotspot"

# 4. Instalar Plugin en ~/.config/omarchy/plugins/evcode.hotspot
mkdir -p "$TARGET_DIR/bin"
cp "$SCRIPT_DIR/manifest.json" "$TARGET_DIR/"
cp "$SCRIPT_DIR/Panel.qml" "$TARGET_DIR/"
cp "$SCRIPT_DIR/Model.js" "$TARGET_DIR/"
cp "$SCRIPT_DIR/bin/omarchy-hotspot" "$TARGET_DIR/bin/"
chmod +x "$TARGET_DIR/bin/omarchy-hotspot"
chown -R "$REAL_USER":"$REAL_USER" "$TARGET_DIR" 2>/dev/null || true
echo "[✓] Plugin instalado en $TARGET_DIR"

# 5. Validar y habilitar plugin en Omarchy
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$TARGET_DIR" 2>/dev/null || true
  omarchy plugin enable evcode.hotspot 2>/dev/null || true
  echo "[✓] Plugin evcode.hotspot habilitado"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi

# 6. Limpiar caché QML y reiniciar shell
rm -rf "$REAL_HOME/.cache/quickshell/qmlcache"/* 2>/dev/null || true

if command -v omarchy-restart-shell >/dev/null 2>&1; then
  echo "[*] Reiniciando Omarchy Shell..."
  if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1t /run/user/$(id -u "$REAL_USER" 2>/dev/null || echo $UID)/hypr 2>/dev/null | head -n1)
  fi
  omarchy-restart-shell 2>/dev/null || true
fi

echo "=== Instalación completada correctamente ==="
