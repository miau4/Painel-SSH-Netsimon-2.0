#!/bin/bash
# NETSIMON - SISTEMA DE AUTORECOVERY

BASE="/etc/painel"
XRAY_CONF="/etc/xray/config.json"
USERDB="/etc/xray-manager/users.db"

# Espera a rede estar 100% pronta
sleep 15

# 1. Recupera Limiter
if ! pgrep -f "limit.sh" > /dev/null; then
    nohup bash "$BASE/limit.sh" > /dev/null 2>&1 &
fi

# 2. Recupera Xray
if [ -f "$XRAY_CONF" ]; then
    systemctl restart xray
fi

# 3. Recupera WebSocket (Busca a última porta usada)
LAST_WS_PORT=$(cat "$BASE/.last_ws_port" 2>/dev/null || echo "80")
if ! pgrep -f "proxy.py" > /dev/null; then
    nohup python3 "$BASE/proxy.py" "$LAST_WS_PORT" > /dev/null 2>&1 &
fi

# 4. Recupera SlowDNS
if [ -f "/etc/slowdns/server.key" ]; then
    NS=$(cat "/etc/slowdns/ns_name" 2>/dev/null)
    if [ -n "$NS" ] && ! pgrep -f "dnstt-server" > /dev/null; then
        systemctl stop systemd-resolved
        iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
        nohup /etc/slowdns/dnstt-server -udp :5300 -privkey /etc/slowdns/server.key "$NS" 127.0.0.1:22 > /dev/null 2>&1 &
    fi
fi
