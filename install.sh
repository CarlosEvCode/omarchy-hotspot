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

# 2. Instalar root wrapper exacto para AP virtual en /usr/local/bin
ROOT_HELPER_SRC="$SCRIPT_DIR/bin/omarchy-hotspot-ap-helper"
ROOT_HELPER_DEST="/usr/local/bin/omarchy-hotspot-ap-helper"

if [[ -f "$ROOT_HELPER_SRC" ]]; then
  echo "[*] Instalando root helper en $ROOT_HELPER_DEST..."
  sudo cp "$ROOT_HELPER_SRC" "$ROOT_HELPER_DEST"
  sudo chown root:root "$ROOT_HELPER_DEST"
  sudo chmod 0755 "$ROOT_HELPER_DEST"
  echo "[✓] Root helper instalado con permisos 0755 root:root"
fi

# 3. Configurar regla de sudoers estricta sin comodines de argumentos
SUDOERS_FILE="/etc/sudoers.d/omarchy-hotspot-ap"
RULE="$REAL_USER ALL=(ALL) NOPASSWD: $ROOT_HELPER_DEST add, $ROOT_HELPER_DEST del, $ROOT_HELPER_DEST up, $ROOT_HELPER_DEST down"

echo "[*] Configurando regla sudoers estricta en $SUDOERS_FILE..."
echo "$RULE" | sudo tee "$SUDOERS_FILE" >/dev/null
sudo chmod 0440 "$SUDOERS_FILE"
echo "[✓] Regla sudoers configurada sin comodines"

# 4. Reparar y asegurar permisos 0600 en archivo de configuración si existe
CONFIG_DIR="$REAL_HOME/.config/omarchy"
mkdir -p "$CONFIG_DIR"
chmod 0700 "$CONFIG_DIR" 2>/dev/null || true
if [[ -f "$CONFIG_DIR/hotspot.json" ]]; then
  chmod 0600 "$CONFIG_DIR/hotspot.json" 2>/dev/null || true
  chown "$REAL_USER":"$REAL_USER" "$CONFIG_DIR/hotspot.json" 2>/dev/null || true
fi

# 5. Instalar CLI helper en ~/.local/bin
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/bin/omarchy-hotspot" "$BIN_DIR/omarchy-hotspot"
chmod +x "$BIN_DIR/omarchy-hotspot"
chown "$REAL_USER":"$REAL_USER" "$BIN_DIR/omarchy-hotspot" 2>/dev/null || true
echo "[✓] Helper instalado en $BIN_DIR/omarchy-hotspot"

# 6. Instalar Plugin en ~/.config/omarchy/plugins/evcode.hotspot
mkdir -p "$TARGET_DIR/bin"
cp "$SCRIPT_DIR/manifest.json" "$TARGET_DIR/"
cp "$SCRIPT_DIR/Panel.qml" "$TARGET_DIR/"
cp "$SCRIPT_DIR/Model.js" "$TARGET_DIR/"
cp "$SCRIPT_DIR/bin/omarchy-hotspot" "$TARGET_DIR/bin/"
cp "$SCRIPT_DIR/bin/omarchy-hotspot-ap-helper" "$TARGET_DIR/bin/"
chmod +x "$TARGET_DIR/bin/omarchy-hotspot"
chmod +x "$TARGET_DIR/bin/omarchy-hotspot-ap-helper"
chown -R "$REAL_USER":"$REAL_USER" "$TARGET_DIR" 2>/dev/null || true
echo "[✓] Plugin instalado en $TARGET_DIR"

# 7. Validar y habilitar plugin en Omarchy
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$TARGET_DIR" 2>/dev/null || true
  omarchy plugin enable evcode.hotspot 2>/dev/null || true
  echo "[✓] Plugin evcode.hotspot habilitado"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi

# 8. Limpiar caché QML y reiniciar shell
rm -rf "$REAL_HOME/.cache/quickshell/qmlcache"/* 2>/dev/null || true

if command -v omarchy-restart-shell >/dev/null 2>&1; then
  echo "[*] Reiniciando Omarchy Shell..."
  if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1t /run/user/$(id -u "$REAL_USER" 2>/dev/null || echo $UID)/hypr 2>/dev/null | head -n1)
  fi
  omarchy-restart-shell 2>/dev/null || true
fi

echo "=== Instalación completada correctamente ==="
