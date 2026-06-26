#!/bin/bash
# Автоматическая настройка L2TP/IPsec + AmneziaWG VPN Шлюза на Ubuntu

set -e

echo "=== Установка L2TP/IPsec VPN Gateway с маршрутизацией в AmneziaWG ==="

# 1. Добавление репозитория AmneziaWG и установка пакетов
echo "1. Обновление пакетов и установка зависимостей..."
sudo apt-get update
sudo apt-get install -y software-properties-common iptables iptables-persistent
sudo add-apt-repository -y ppa:amnezia/ppa
sudo apt-get update
sudo apt-get install -y amneziawg-tools xl2tpd ppp strongswan

# 2. Настройка xl2tpd
echo "2. Настройка xl2tpd..."
sudo tee /etc/xl2tpd/xl2tpd.conf >/dev/null << 'EOF'
[global]
ipsec saref = no
listen-addr = 0.0.0.0
port = 1701

[lns default]
ip range = 10.0.1.10-10.0.1.100
local ip = 10.0.1.1
require chap = yes
refuse pap = yes
require authentication = yes
name = LinuxVPNserver
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

sudo tee /etc/ppp/options.xl2tpd >/dev/null << 'EOF'
require-mschap-v2
ms-dns 1.1.1.1
ms-dns 1.0.0.1
auth
mtu 1200
mru 1200
nodefaultroute
lock
nobsdcomp
novj
novjccomp
nologfd
EOF

# 3. Настройка IPsec (strongswan)
echo "3. Настройка IPsec (L2TP/IPsec PSK)..."
sudo tee /etc/ipsec.conf >/dev/null << 'EOF'
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT

conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=%defaultroute
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
    dpddelay=40
    dpdtimeout=130
    dpdaction=clear
    ike=aes128-sha1-modp2048,aes128-sha256-modp2048,aes256-sha256-modp2048,aes256-sha1-modp2048,aes256-sha1-modp1024,aes128-sha1-modp1536,aes128-sha1-modp1024,3des-sha1-modp1024,aes128-md5-modp1024,3des-md5-modp1024!
    esp=aes256-sha256,aes256-sha1,aes128-sha1,3des-sha1,aes128-md5,3des-md5!
EOF

sudo tee /etc/ipsec.secrets >/dev/null << 'EOF'
: PSK "amnezia123"
EOF
sudo chmod 600 /etc/ipsec.secrets

# 4. Создание пользователей
echo "4. Настройка пользователей VPN..."
sudo tee /etc/ppp/chap-secrets >/dev/null << 'EOF'
router * secret123 *
Evgenii * secret123 *
EOF
sudo chmod 600 /etc/ppp/chap-secrets

# 5. Настройка маршрутизации и sysctl
echo "5. Настройка ядра (sysctl)..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo bash -c "echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-vpn.conf"
sudo sysctl -p /etc/sysctl.d/99-vpn.conf

# 6. Настройка iptables (NAT + TCPMSS)
echo "6. Настройка Firewall (iptables)..."
sudo iptables -t nat -A POSTROUTING -o awg0 -j MASQUERADE
sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
sudo iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -o awg0 -j TCPMSS --clamp-mss-to-pmtu
sudo netfilter-persistent save

echo "=== Установка завершена! ==="
echo "Не забудьте скопировать ваш клиентский файл AmneziaWG в /etc/amnezia/amneziawg/awg0.conf и добавить в него правила:"
echo "PostUp = ip rule add from 10.0.1.0/24 table 123; ip route add default dev awg0 table 123"
echo "Затем выполните: systemctl enable --now awg-quick@awg0"
