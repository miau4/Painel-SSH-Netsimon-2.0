#!/bin/bash

# ==================================================
# CAMINHOS E CONFIGURAÇÕES (Sincronizados)
# ==================================================
USERS_DB="/etc/xray-manager/users.db"
BLOCKED_DB="/etc/xray-manager/blocked.db"
XRAY_LOG="/var/log/xray/access.log"
XRAY_CONF="/etc/xray/config.json"
SCRIPT_PATH="/etc/painel/limit.sh"

# Cores para Logs (Execução Manual)
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ==================================================
# AUTOMAÇÃO: AUTO-START NO BOOT (CRONTAB)
# ==================================================
if ! crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH"; then
    (crontab -l 2>/dev/null; echo "@reboot bash $SCRIPT_PATH >/dev/null 2>&1 &") | crontab -
fi

# Evita múltiplas instâncias rodando ao mesmo tempo
PID_FILE="/tmp/limit_xray.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null; then
        exit 1
    fi
fi
echo $$ > "$PID_FILE"

# ==================================================
# LOOP DE MONITORAMENTO
# ==================================================
echo -e "${YELLOW}Monitor de Limite Ativo e Automatizado (Boot ON)${NC}"

while true; do
    # Verifica se o banco de usuários existe
    if [ ! -f "$USERS_DB" ]; then
        sleep 30
        continue
    fi

    # Loop pelos usuários (user|uuid|exp|pass|limit)
    while IFS="|" read -r user uuid exp pass limit; do
        [[ -z "$user" ]] && continue
        [[ ! "$limit" =~ ^[0-9]+$ ]] && limit=1

        # Pula se já estiver bloqueado
        if grep -q "^$user|" "$BLOCKED_DB"; then
            continue
        fi

        # 1. CONTAGEM SSH/SLOWDNS (Conexões Reais)
        # Filtra processos sshd que pertencem ao usuário e não são o processo principal
        con_ssh=$(ps aux | grep -i sshd | grep -v root | grep -v grep | grep "$user" | wc -l)

        # 2. CONTAGEM XRAY (IPs Únicos nos últimos logs)
        con_xray=0
        if [ -f "$XRAY_LOG" ]; then
            # Pega os últimos 100 acessos do usuário e conta IPs distintos
            con_xray=$(grep "$user" "$XRAY_LOG" | tail -n 100 | awk '{print $3}' | cut -d: -f1 | sort -u | grep -v "^$" | wc -l)
        fi

        total_cons=$((con_ssh + con_xray))

        # 3. VERIFICAÇÃO E AÇÃO
        if [ "$total_cons" -gt "$limit" ]; then
            DATA_HORA=$(date +"%d/%m/%Y %H:%M:%S")
            echo -e "${RED}[$DATA_HORA] LIMITE EXCEDIDO: $user ($total_cons/$limit)${NC}"

            # Ação SSH: Mata conexões e tranca a senha
            pkill -u "$user" &>/dev/null
            passwd -l "$user" &>/dev/null

            # Ação Xray: Remove do JSON via JQ
            if [ -f "$XRAY_CONF" ] && command -v jq >/dev/null; then
                tmp=$(mktemp)
                jq --arg email "$user" '.inbounds[0].settings.clients |= map(select(.email != $email))' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
                systemctl restart xray 2>/dev/null
            fi

            # Registro no Banco de Bloqueados
            echo "$user|$(date +%s)|$total_cons" >> "$BLOCKED_DB"
        fi

    done < "$USERS_DB"

    # Intervalo de 20 segundos para não sobrecarregar a CPU
    sleep 20
done
