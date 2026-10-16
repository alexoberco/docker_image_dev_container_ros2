#!/usr/bin/env bash
# Diagnóstico de la red por cable con el Quest. No cambia nada: solo mira, y
# dice qué falta. Sin root.
set -u
ok()   { echo "  OK   $*"; }
bad()  { echo "  FALLA $*"; FAIL=1; }
FAIL=0

echo "Casco"
SERIAL=$(adb get-serialno 2>/dev/null) && [ "$SERIAL" != "unknown" ] &&
    ok "adb ve el Quest ($SERIAL)" || bad "adb no ve el Quest (cable, popup de depuración USB, autosuspend)"

echo "PC"
systemctl --user is-active -q quest-ncm.service &&
    ok "servicio quest-ncm activo" || bad "quest-ncm parado: systemctl --user status quest-ncm"
IFACE=""
for path in /sys/class/net/*; do
    [ -e "$path/device/driver" ] || continue
    [ "$(basename "$(readlink -f "$path/device/driver")")" = "cdc_ncm" ] && IFACE=$(basename "$path")
done
[ -n "$IFACE" ] && ok "interfaz cdc_ncm: $IFACE" || bad "no hay interfaz cdc_ncm (el casco no está en NCM)"
if [ -n "$IFACE" ]; then
    nmcli -g GENERAL.CONNECTION device show "$IFACE" 2>/dev/null | grep -qx quest-usb &&
        ok "perfil quest-usb activo en $IFACE" || bad "quest-usb no está activo en $IFACE: nmcli connection up quest-usb"
    ip -4 addr show "$IFACE" | grep -q "192.168.42.1/" &&
        ok "PC en 192.168.42.1" || bad "el PC no tiene 192.168.42.1 en $IFACE"
fi

echo "Red del casco"
# 'ip addr' está bloqueado por SELinux en el casco; 'ip route' no.
QUEST_IP=$(adb shell ip route 2>/dev/null | grep usb0 | grep -oP 'src \K[\d.]+' | head -1)
if [ -n "$QUEST_IP" ]; then
    ok "casco en $QUEST_IP"
    ping -c 2 -q -W 2 "$QUEST_IP" >/dev/null 2>&1 &&
        ok "ping al casco" || bad "hay IPs a ambos lados pero el ping falla: firewall del PC"
else
    bad "el casco no tiene IP en usb0 (DHCP del modo shared: journalctl -u NetworkManager)"
fi
# Android solo usa una red por defecto y exige que tenga internet para
# validarla; si no, las apps siguen saliendo por Wi-Fi.
DEFAULT_IF=$(adb shell dumpsys connectivity 2>/dev/null |
             grep -A1 "Active default network" | grep -oP 'InterfaceName: \K\S+' | head -1)
[ "$DEFAULT_IF" = "usb0" ] && ok "red por defecto del casco: usb0" ||
    bad "red por defecto del casco: ${DEFAULT_IF:-desconocida} (¿NAT? apaga el Wi-Fi del casco para forzarlo)"

[ $FAIL -eq 0 ] && echo "Todo listo: en Unity, el PC es 192.168.42.1"
exit $FAIL
