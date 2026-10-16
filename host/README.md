# host/ — preparar el PC (fuera del contenedor)

Lo que Sentinel necesita **en el host** y no puede vivir en el devcontainer ni en la
app del Quest: la red por el cable USB con el casco y el arreglo del USB. Se
instala **una vez** por PC; después basta con conectar el Quest.

```bash
./install.sh        # como tu usuario, sin sudo delante (lo pide él)
./quest-status.sh   # diagnóstico: qué funciona y qué falta
./uninstall.sh
```

## Qué hace

El vídeo (WebRTC/UDP), el puente ROS-TCP y la pose van por una red IP real sobre
el cable: el Quest expone un adaptador **CDC-NCM** y el PC es `192.168.42.1`
(3 ms de ida y vuelta, contra 96 ms por Wi-Fi). Montarlo pide cuatro piezas:

| Pieza | Dónde queda | Para qué |
|---|---|---|
| `quest-ncm.service` + `quest-ncm-watch.sh` | servicio **de usuario** | Al conectar el casco, `adb shell svc usb setFunctions ncm`. No persiste en el casco: se reaplica en cada conexión. |
| Perfil NM `quest-usb` | NetworkManager | `match.driver cdc_ncm` + `ipv4.method shared`: cualquier interfaz NCM recibe `192.168.42.1/24`, y NM pone DHCP, DNS, NAT e `ip_forward`. |
| `90-sentinel-quest-usb` | `/etc/NetworkManager/dispatcher.d/` | Abre el firewall (ufw) a esa interfaz al subir: ROS-TCP, señalización y medio WebRTC. |
| `60-usb-no-autosuspend.rules` | `/etc/udev/rules.d/` | Sin autosuspend en los controladores xHCI: el Quest desaparecía de adb. |

Sustituye a `~/.local/bin/quest-usb-network.sh` (había que lanzarlo con sudo en
cada sesión) y a `quest-adb-reverse.service` (obsoleto desde el 24-09-2026: ROS-TCP
ya no va por `adb reverse`); el instalador desactiva este último.

Por qué así, y no como en el script antiguo:

- **El nombre de la interfaz cambia** (`enx` + MAC, y la MAC del NCM es nueva en
  cada arranque del casco): el perfil se ata al driver, no al nombre.
- **El modo `shared` de NM** hace lo que el script hacía a mano (dnsmasq, NAT,
  forward) y además sirve DNS de verdad. Android solo usa como red por defecto
  una que valide con internet; sin NAT ni DNS, las apps siguen saliendo por Wi-Fi.
- **adb es del usuario**: un adb lanzado como root arranca otro servidor con otra
  clave y el casco lo ve sin autorizar. Por eso el vigilante es un servicio de
  usuario y lo que pide root lo hace NetworkManager.

## Por qué no lo hace la app del Quest

- `svc usb setFunctions` pide `MANAGE_USB`, un permiso de sistema: una app no
  puede cambiar el modo USB.
- Horizon OS sí tiene una API oficial para apps ([USB networking
  (NCM)](https://developers.meta.com/horizon/documentation/android-apps/usb-networking/)):
  `ConnectivityManager.requestNetwork` con `TRANSPORT_USB`, con un diálogo de
  consentimiento y sin adb ni modo desarrollador. Es la que usa Steam Link por cable.
  Pero el enlace es **solo IPv6 link-local**, sin internet, y el PC se descubre por
  mDNS. Todo Sentinel habla IPv4 con `192.168.42.1`, y `ros_tcp_endpoint` (que no se
  modifica) abre su socket solo en `AF_INET`. Pasarse exigiría un relé IPv6→IPv4 en
  `sentinel_ros_pkgs`, ICE en link-local en los dos emisores y en el receptor nativo,
  y descubrimiento por mDNS en Unity. Es el camino para no depender de adb; no está
  hecho.

## Si algo falla

`./quest-status.sh` dice qué pieza falta. Lo más habitual:

- *adb no ve el Quest*: popup de depuración USB sin aceptar, o el autosuspend
  (`journalctl -k | grep xhci`; ver `skills/meta-quest-adb-usb-setup`).
- *No hay interfaz cdc_ncm*: `systemctl --user status quest-ncm` y
  `journalctl --user -u quest-ncm`.
- *El casco no toma IP*: `journalctl -u NetworkManager | grep -i dnsmasq`. Un
  dnsmasq suelto del script antiguo ocupa el puerto 67; el instalador lo mata.
- *La red por defecto del casco es wlan0*: el NAT no sale (¿no hay uplink?). Apagar
  el Wi-Fi del casco lo fuerza.
- Para volver al modo USB normal (MTP), desconectar el cable o
  `systemctl --user stop quest-ncm` y reiniciar el casco.
