#!/bin/bash

# Define the IP addresses and other variables of my one VM to rule all services
SERVER_IP="10.0.2.2"
SERVER_PORT="51822"
SERVER_VPN_IP="192.168.11.1/24"
VM_IPS=("192.168.11.2/24")
VM_ALLOW=("192.168.11.2/32")
VM_NAMES=("vm1")
CONFIG_DIR="./wireguard-configs"

# Create the directory to store the configuration files
mkdir -p $CONFIG_DIR

# Function to generate key pairs
generate_keys() {
    wg genkey | tee $1_private.key | wg pubkey > $1_public.key
}

# Generate server keys
echo "Generating server keys..."
generate_keys "server"

# Generate VM keys
for vm in "${VM_NAMES[@]}"; do
    echo "Generating keys for $vm..."
    generate_keys $vm
done


# Create server configuration file
echo "Creating server configuration file..."
SERVER_CONFIG="$CONFIG_DIR/wg0-server.conf"

echo "[Interface]
PrivateKey = $(cat server_private.key)
Address = $SERVER_VPN_IP
ListenPort = $SERVER_PORT
" > $SERVER_CONFIG

for i in "${!VM_NAMES[@]}"; do
    echo "[Peer]
PublicKey = $(cat ${VM_NAMES[$i]}_public.key)
AllowedIPs = ${VM_ALLOW[$i]}
" >> $SERVER_CONFIG
done

# Create VM configuration files
for i in "${!VM_NAMES[@]}"; do
    VM_CONFIG="$CONFIG_DIR/wg0-${VM_NAMES[$i]}.conf"

    echo "Creating configuration file for ${VM_NAMES[$i]}..."
    echo "[Interface]
PrivateKey = $(cat ${VM_NAMES[$i]}_private.key)
Address = ${VM_IPS[$i]}

[Peer]
PublicKey = $(cat server_public.key)
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 192.168.11.0/24
PersistentKeepalive = 25
" > $VM_CONFIG
done

# Move keys to configuration dir
mv *.key $CONFIG_DIR

echo "Wireguard configuration files have been generated in $CONFIG_DIR"
ls -l $CONFIG_DIR

echo "Starting Wireguard server"
mkdir -p ~/wireguard
cp wireguard-configs/wg0-server.conf ~/wireguard/
cp wireguard-configs/server_private.key ~/wireguard/

sudo wg-quick up ~/wireguard/wg0-server.conf

