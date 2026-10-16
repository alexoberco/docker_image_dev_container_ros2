#!/usr/bin/env bash
# Deshace install.sh. Como tu usuario, sin sudo delante.
set -u
systemctl --user disable --now quest-ncm.service 2>/dev/null
rm -f "$HOME/.config/systemd/user/quest-ncm.service" "$HOME/.local/bin/quest-ncm-watch.sh"
systemctl --user daemon-reload
sudo nmcli connection delete quest-usb 2>/dev/null
sudo rm -f /etc/NetworkManager/dispatcher.d/90-sentinel-quest-usb
# La regla udev del autosuspend se queda: arregla un fallo del controlador USB
# que no es de Sentinel. Bórrala a mano si quieres: /etc/udev/rules.d/60-usb-no-autosuspend.rules
# El casco vuelve a su modo USB normal al desconectarlo o reiniciarlo.
echo "Desinstalado."
