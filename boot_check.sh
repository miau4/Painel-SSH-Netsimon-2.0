#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - AUTO-RECOVERY 2.0
# ==========================================

BASE="/etc/painel"
XRAY_CONF="/usr/local/etc/xray/config.json"
SSL_DIR="/etc/xray-manager/ssl"

# Espera a rede e os serviços de sistema estabilizarem
sleep 15

# 1. Recupera o Limiter (Monitor de Conexões)
if ! pgrep -f "limit.sh" > /dev/null; then
    nohup bash "$BASE/limit.sh" > /dev/null 2>&1 &
fi

# 2. Recupera o Xray-Core
# Verifica se o binário e a config existem antes de tentar subir
if [ -f "/usr/local/bin/xray" ] && [ -f "$XRAY_CONF" ]; then
    systemctl restart xray
fi

# 3. Recupera WebSocket (Porta 80)
# Garante que o Proxy Python esteja rodando para conexões HTTP
if ! pgrep -f "proxy.py" > /dev/null; then
    # Se você usa python3 no sistema, mantemos a compatibilidade
    nohup python3 "$BASE/proxy.py" > /dev/null 2>&1 &
fi

# 4. Recupera a API CheckUser (Porta 5000)
# ESSENCIAL: Sem isso, os aplicativos VPN darão erro de "User Not Found"
if ! pgrep -f "checkuser.py" > /dev/null; then
    nohup python3 "$BASE/checkuser.py" > /dev/null 2>&1 &
fi

# 5. Recupera o SlowDNS (Porta 53 UDP)
if [ -f "/etc/slowdns/server.key" ]; then
    NS=$(cat "/etc/slowdns/ns_name" 2>/dev/null)
    if [ -z "$NS" ]; then
        # Caso o arquivo de NS tenha sumido, busca o hostname do servidor como fallback
        NS=$(hostname)
    fi
    
    if ! pgrep -f "dns-server" > /dev/null; then
        # Para o resolved para liberar a porta 53 real
        systemctl stop systemd-resolved &>/dev/null
        # Executa o binário do SlowDNS com as chaves Enterprise
        nohup /etc/slowdns/dns-server -udp :53 -privkey-file /etc/slowdns/server.key "$NS" 127.0.0.1:22 > /dev/null 2>&1 &
    fi
fi

# 6. Limpeza de Logs Antigos (Manutenção Automática)
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;

exit 0
