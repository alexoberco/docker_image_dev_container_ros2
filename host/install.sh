#!/usr/bin/env bash
# Prepara un PC Ubuntu para Sentinel, una sola vez. Después, conectar el Quest
# por el cable basta: no hay que lanzar nada con sudo en cada sesión.
#
# Se ejecuta como el usuario normal (NO con sudo delante): pide sudo solo para
# lo que es del sistema, y el servicio del Quest tiene que ser del usuario
# porque adb es suyo (ver quest-ncm-watch.sh). Es idempotente.
#
# Qué deja:
#  1) Regla udev que quita el autosuspend del controlador USB xHCI (el Quest
#     desaparecía de adb con un ASMedia; ver skills/meta-quest-adb-usb-setup).
#  2) Perfil de NetworkManager 'quest-usb' en modo 'shared' (192.168.42.1/24,
#     DHCP, DNS y NAT del propio NM) para CUALQUIER interfaz cdc_ncm: la MAC, y
#     con ella el nombre enx*, cambia en cada arranque del casco.
#  3) Dispatcher de NM que abre el firewall a esa interfaz cuando sube.
#  4) Servicio de usuario quest-ncm que pasa el casco a NCM al conectarlo.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CON_NAME="quest-usb"
HOST_CIDR="192.168.42.1/24"

if [ "$(id -u)" -eq 0 ]; then
    echo "Ejecútalo como tu usuario, sin sudo: el servicio del Quest es de usuario." >&2
    exit 1
fi

missing=()
command -v adb >/dev/null || missing+=("adb")
command -v nmcli >/dev/null || missing+=("network-manager")
# NM lanza su propio dnsmasq para el modo 'shared'; viene en dnsmasq-base.
command -v dnsmasq >/dev/null || missing+=("dnsmasq-base")
command -v iptables >/dev/null || missing+=("iptables")
if [ ${#missing[@]} -gt 0 ]; then
    echo "Instalando: ${missing[*]}"
    sudo apt-get install -y "${missing[@]}"
fi

echo "1/4 Regla udev contra el autosuspend del USB"
sudo install -m 644 "$HERE/60-usb-no-autosuspend.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules

echo "2/4 Perfil de red '$CON_NAME' (modo shared, cualquier cdc_ncm)"
# Un perfil viejo atado a un enx* concreto solo serviría hasta el próximo
# arranque del casco: se rehace siempre.
sudo nmcli connection delete "$CON_NAME" >/dev/null 2>&1 || true
# El dnsmasq y el NAT a mano del script antiguo chocarían con los del modo shared.
sudo pkill -F /run/dnsmasq-quest.pid 2>/dev/null || true
sudo nmcli connection add type ethernet con-name "$CON_NAME" \
    match.driver cdc_ncm \
    ipv4.method shared ipv4.addresses "$HOST_CIDR" ipv4.never-default yes \
    ipv6.method disabled \
    connection.autoconnect yes connection.autoconnect-priority 100 >/dev/null

echo "3/4 Dispatcher de firewall"
sudo install -m 755 "$HERE/90-sentinel-quest-usb" /etc/NetworkManager/dispatcher.d/

echo "4/4 Servicio de usuario quest-ncm"
install -D -m 755 "$HERE/quest-ncm-watch.sh" "$HOME/.local/bin/quest-ncm-watch.sh"
install -D -m 644 "$HERE/quest-ncm.service" "$HOME/.config/systemd/user/quest-ncm.service"
# 'adb reverse' quedó obsoleto el 24-09-2026: ROS-TCP va directo por el cable.
if systemctl --user list-unit-files quest-adb-reverse.service >/dev/null 2>&1; then
    systemctl --user disable --now quest-adb-reverse.service >/dev/null 2>&1 || true
fi
systemctl --user daemon-reload
systemctl --user enable --now quest-ncm.service >/dev/null
systemctl --user restart quest-ncm.service

# Comprobaciones que no se arreglan solas: solo avisan.
if command -v nvidia-smi >/dev/null && [ ! -f /etc/cdi/nvidia.yaml ]; then
    echo "Aviso: hay GPU NVIDIA pero no la spec CDI que pide el devcontainer:" >&2
    echo "       sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml" >&2
fi

echo
echo "Listo. Conecta el Quest y acepta la depuración USB; en unos segundos:"
echo "  $HERE/quest-status.sh"
