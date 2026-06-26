#!/bin/bash

# Ensure /dev/net/tun exists for AmneziaWG
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

# Use amneziawg-go user-space implementation
export WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go

echo "Starting AmneziaWG..."
if [ -f /etc/amnezia/awg0.conf ]; then
    # Start AmneziaWG interface
    awg-quick up /etc/amnezia/awg0.conf
else
    echo "ERROR: /etc/amnezia/awg0.conf not found!"
    exit 1
fi

echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1

echo "Setting up NAT for L2TP clients to access AmneziaWG..."
# Accept traffic from ppp interfaces (L2TP clients)
iptables -A FORWARD -i ppp+ -j ACCEPT
iptables -A FORWARD -o ppp+ -j ACCEPT

# Masquerade traffic going out via awg0 to the VPS
iptables -t nat -A POSTROUTING -o awg0 -j MASQUERADE

echo "Starting xl2tpd..."
exec /usr/sbin/xl2tpd -D
