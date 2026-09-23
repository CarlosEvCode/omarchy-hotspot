#!/bin/bash

# Script de instalación automática para el plugin evcode.hotspot en Omarchy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Instalando Plugin Hotspot para Omarchy ==="

# 1. Derivar identidad de usuario de forma segura desde el sistema operativo
TARGET_UID="${SUDO_UID:-$UID}"
TARGET_USER="$(id -un "$TARGET_UID" 2>/dev/null || true)"

if [[ -z "$TARGET_USER" ]] || ! [[ "$TARGET_USER" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
  echo "Error: No se pudo determinar un nombre de usuario de SO válido." >&2
  exit 1
fi

PASSWD_ENTRY="$(getent passwd "$TARGET_USER" 2>/dev/null || true)"
if [[ -z "$PASSWD_ENTRY" ]]; then
  echo "Error: El usuario '$TARGET_USER' no existe en la base de datos de usuarios." >&2
  exit 1
fi

TARGET_HOME="$(echo "$PASSWD_ENTRY" | cut -d: -f6)"
if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
  echo "Error: Directorio home inválido para el usuario '$TARGET_USER'." >&2
  exit 1
fi

TARGET_DIR="$TARGET_HOME/.config/omarchy/plugins/evcode.hotspot"
BIN_DIR="$TARGET_HOME/.local/bin"

# 2. Verificar e instalar dependencias del sistema
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

# 3. Instalar root wrapper verificado con rutas absolutas e instalación atómica
ROOT_HELPER_DEST="/usr/local/bin/omarchy-hotspot-ap-helper"
echo "[*] Instalando root helper verificado en $ROOT_HELPER_DEST..."

TMP_HELPER="$(sudo mktemp /usr/local/bin/.omarchy-hotspot-ap-helper.XXXXXX)"
sudo tee "$TMP_HELPER" >/dev/null <<'EOF'
#!/bin/bash
# Root helper for managing the virtual AP interface (ap0) in Omarchy
# Installed to /usr/local/bin/omarchy-hotspot-ap-helper (mode 0755 root:root)

set -euo pipefail
export PATH="/usr/bin:/bin"

case "${1:-}" in
  add)
    if ! /usr/bin/ip link show ap0 >/dev/null 2>&1; then
      /usr/bin/iw phy phy0 interface add ap0 type __ap 2>/dev/null || true
      /usr/bin/ip link set ap0 up 2>/dev/null || true
    fi
    ;;
  del)
    if /usr/bin/ip link show ap0 >/dev/null 2>&1; then
      /usr/bin/iw dev ap0 del 2>/dev/null || true
    fi
    ;;
  up)
    /usr/bin/ip link set ap0 up 2>/dev/null || true
    ;;
  down)
    /usr/bin/ip link set ap0 down 2>/dev/null || true
    ;;
  *)
    echo "Usage: $0 {add|del|up|down}" >&2
    exit 1
    ;;
esac
EOF

sudo chown root:root "$TMP_HELPER"
sudo chmod 0755 "$TMP_HELPER"
sudo mv -f "$TMP_HELPER" "$ROOT_HELPER_DEST"
echo "[✓] Root helper instalado atómicamente con permisos 0755 root:root"

# 4. Configurar e instalar política sudoers atómica validada con visudo -cf
SUDOERS_FILE="/etc/sudoers.d/omarchy-hotspot-ap"
echo "[*] Generando y validando política sudoers estricta..."

TMP_SUDOERS="$(sudo mktemp /etc/sudoers.d/.hotspot.XXXXXX)"
sudo chmod 0440 "$TMP_SUDOERS"

printf '%s ALL=(ALL) NOPASSWD: %s add, %s del, %s up, %s down\n' \
  "$TARGET_USER" "$ROOT_HELPER_DEST" "$ROOT_HELPER_DEST" "$ROOT_HELPER_DEST" "$ROOT_HELPER_DEST" | sudo tee "$TMP_SUDOERS" >/dev/null

if ! sudo visudo -cf "$TMP_SUDOERS"; then
  echo "Error: La política de sudoers generada no superó la validación de sintaxis de visudo." >&2
  sudo rm -f "$TMP_SUDOERS"
  exit 1
fi

sudo chmod 0440 "$TMP_SUDOERS"
sudo mv -f "$TMP_SUDOERS" "$SUDOERS_FILE"
echo "[✓] Regla sudoers validada con visudo e instalada atómicamente en $SUDOERS_FILE"

# 5. Asegurar permisos 0600 en directorio y archivo de configuración
CONFIG_DIR="$TARGET_HOME/.config/omarchy"
mkdir -p "$CONFIG_DIR"
chmod 0700 "$CONFIG_DIR" 2>/dev/null || true
if [[ -f "$CONFIG_DIR/hotspot.json" ]]; then
  chmod 0600 "$CONFIG_DIR/hotspot.json" 2>/dev/null || true
  chown "$TARGET_USER":"$TARGET_USER" "$CONFIG_DIR/hotspot.json" 2>/dev/null || true
fi

# 6. Instalar CLI helper en ~/.local/bin
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/bin/omarchy-hotspot" "$BIN_DIR/omarchy-hotspot"
chmod +x "$BIN_DIR/omarchy-hotspot"
chown "$TARGET_USER":"$TARGET_USER" "$BIN_DIR/omarchy-hotspot" 2>/dev/null || true
echo "[✓] Helper instalado en $BIN_DIR/omarchy-hotspot"

# 7. Instalar Plugin en ~/.config/omarchy/plugins/evcode.hotspot
mkdir -p "$TARGET_DIR/bin"
cp "$SCRIPT_DIR/manifest.json" "$TARGET_DIR/"
cp "$SCRIPT_DIR/Panel.qml" "$TARGET_DIR/"
cp "$SCRIPT_DIR/Model.js" "$TARGET_DIR/"
cp "$SCRIPT_DIR/bin/omarchy-hotspot" "$TARGET_DIR/bin/"
cp "$SCRIPT_DIR/bin/omarchy-hotspot-ap-helper" "$TARGET_DIR/bin/"
chmod +x "$TARGET_DIR/bin/omarchy-hotspot"
chmod +x "$TARGET_DIR/bin/omarchy-hotspot-ap-helper"
chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_DIR" 2>/dev/null || true
echo "[✓] Plugin instalado en $TARGET_DIR"

# 8. Validar y habilitar plugin en Omarchy
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "$TARGET_DIR" 2>/dev/null || true
  omarchy plugin enable evcode.hotspot 2>/dev/null || true
  echo "[✓] Plugin evcode.hotspot habilitado"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi

# 9. Limpiar caché QML y reiniciar shell
rm -rf "$TARGET_HOME/.cache/quickshell/qmlcache"/* 2>/dev/null || true

if command -v omarchy-restart-shell >/dev/null 2>&1; then
  echo "[*] Reiniciando Omarchy Shell..."
  if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1t /run/user/$(id -u "$TARGET_USER" 2>/dev/null || echo $UID)/hypr 2>/dev/null | head -n1)
  fi
  omarchy-restart-shell 2>/dev/null || true
fi

echo "=== Instalación completada correctamente ==="
