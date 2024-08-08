mkdir -p ~/wireguard
cp wireguard-configs/wg0-server.conf ~/wireguard/
cp wireguard-configs/server_private.key ~/wireguard/

sudo wg-quick up ~/wireguard/wg0-server.conf

