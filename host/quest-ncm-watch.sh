#!/usr/bin/env bash
# Pone el Meta Quest en modo red USB (CDC-NCM) cada vez que aparece por el cable.
#
# Corre como servicio de usuario (quest-ncm.service), sin root: adb es del
# usuario, y un adb lanzado como root arranca otro servidor con otra clave, que
# el casco ve como un PC sin autorizar. Lo que sí pide root (IP, DHCP, NAT,
# firewall) lo hace NetworkManager con el perfil 'quest-usb' que deja
# install.sh, en cuanto aparece la interfaz cdc_ncm.
#
# Por qué no lo hace la app del casco: 'svc usb setFunctions' exige el permiso
# MANAGE_USB, que es de sistema. La API de apps de Horizon OS (ConnectivityManager
# con TRANSPORT_USB) sí la levanta desde la app, pero solo da IPv6 link-local,
# y ros_tcp_endpoint escucha solo en IPv4 (ver README).
#
# El cambio de modo no persiste: al reiniciar el casco vuelve a MTP (cambiar
# persist.sys.usb.config pide root), así que hay que reaplicarlo en cada conexión.
set -u

has_ncm_iface() {
    for path in /sys/class/net/*; do
        [ -e "$path/device/driver" ] || continue
        [ "$(basename "$(readlink -f "$path/device/driver")")" = "cdc_ncm" ] && return 0
    done
    return 1
}

while true; do
    # Solo un dispositivo USB: si hay un adb por Wi-Fi, no es este cable.
    adb wait-for-usb-device 2>/dev/null || { sleep 5; continue; }

    if has_ncm_iface; then
        # Ya en NCM (lo puso una vuelta anterior o a mano): no tocar, porque
        # cambiar de función reenumera el USB y corta adb y la red un segundo.
        adb wait-for-usb-disconnect 2>/dev/null || sleep 5
        continue
    fi

    # setFunctions admite UNA sola función; Android añade adb solo cuando la
    # depuración USB está activa, así que el cable sigue sirviendo para adb.
    if adb shell svc usb setFunctions ncm >/dev/null 2>&1; then
        echo "Quest $(adb get-serialno 2>/dev/null) pasado a NCM"
        # El casco reenumera el USB: esperar a que aparezca la interfaz para no
        # repetir el cambio en bucle mientras el kernel la registra.
        for _ in $(seq 1 15); do
            sleep 1
            has_ncm_iface && break
        done
        has_ncm_iface || echo "Aviso: no apareció ninguna interfaz cdc_ncm" >&2
    else
        # Presente pero sin autorizar (falta aceptar el popup de depuración USB
        # en el casco) o dormido: reintentar sin quemar CPU.
        sleep 5
    fi
done
