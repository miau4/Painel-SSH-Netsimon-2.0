#!/bin/bash

# Caminhos
BASE="/etc/painel"
XRAY_CONF="/etc/xray/config.json"
USERDB="/etc/xray-manager/users.db"

# 1. Aguardar a rede estabilizar após o boot
sleep 15

# 2. Persistência do LIMITER (Fundamental para segurança comercial)
if ! pgrep -f "limit.sh" > /dev/null; then
    nohup bash "$BASE/limit.sh" > /dev/null 2>&1 &
fi

# 3. Persistência do XRAY
if [ -f "$XRAY_CONF" ]; then
    systemctl start xray
fi

# 4. Persistência do WEBSOCKET (Verifica se havia uma porta salva ou usa a 80)
# DICA: Vamos salvar a última porta usada em um arquivo temporário
LAST_WS_PORT=$(cat "$BASE/.last_ws_port" 2>/dev/null || echo "80")
if ! pgrep -f "proxy.py" > /dev/null; then
    nohup python3 "$BASE/proxy.py" "$LAST_WS_PORT" > /dev/null 2>&1 &
fi

# 5. Persistência do SLOWDNS
if [ -f "/etc/slowdns/server.key" ]; then
    # Recupera o NS salvo anteriormente
    NS=$(cat "/etc/slowdns/ns_name" 2>/dev/null)
    if [ -n "$NS" ] && ! pgrep -f "dnstt-server" > /dev/null; then
        # Garante que a porta 53 esteja livre
        systemctl stop systemd-resolved
        nohup /etc/slowdns/dnstt-server -udp :5300 -privkey /etc/slowdns/server.key "$NS" 127.0.0.1:22 > /dev/null 2>&1 &
    fi
fi

# 6. Correção de IPtables (Garante que as regras de redirecionamento voltem)
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null
