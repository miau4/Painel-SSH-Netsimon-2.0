#!/bin/bash

# Caminhos Sincronizados
USERS_DB="/etc/xray-manager/users.db"
BLOCKED_DB="/etc/xray-manager/blocked.db"
XRAY_LOG="/var/log/xray/access.log"
XRAY_CONF="/etc/xray/config.json"

# Cores
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Criar arquivos se não existirem
mkdir -p /etc/xray-manager
[ ! -f "$BLOCKED_DB" ] && touch "$BLOCKED_DB"

echo -e "${YELLOW}Iniciando Monitor de Limite (NETSIMON 2.0)...${NC}"

while true; do
    # Loop pelos usuários no banco de dados
    while IFS="|" read -r user uuid exp pass limit; do
        [[ -z "$user" ]] && continue
        [[ ! "$limit" =~ ^[0-9]+$ ]] && limit=1

        # Pula se o usuário já estiver na lista de bloqueados
        if grep -q "^$user|" "$BLOCKED_DB"; then
            continue
        fi

        # --- 1. CONTAGEM SSH/SLOWDNS (Conexões Ativas) ---
        con_ssh=$(ps aux | grep -i sshd | grep -v root | grep -v grep | grep "$user" | wc -l)

        # --- 2. CONTAGEM XRAY (Via Log de IPs únicos nos últimos 2 minutos) ---
        con_xray=0
        if [ -f "$XRAY_LOG" ]; then
            # Extrai IPs únicos que acessaram com o email do usuário
            con_xray=$(grep "$user" "$XRAY_LOG" | tail -n 50 | awk '{print $3}' | cut -d: -f1 | sort -u | grep -v "^$" | wc -l)
        fi

        # Total de conexões detectadas
        total_cons=$((con_ssh + con_xray))

        # --- 3. VERIFICAÇÃO DE LIMITE ---
        if [ "$total_cons" -gt "$limit" ]; then
            NOW=$(date +"%d/%m/%Y %H:%M:%S")
            echo -e "${RED}[$NOW] BLOQUEANDO: $user ($total_cons/$limit)${NC}"

            # AÇÃO 1: Bloquear no Linux (SSH/SlowDNS)
            pkill -u "$user" &>/dev/null
            passwd -l "$user" &>/dev/null

            # AÇÃO 2: Remover do JSON do Xray
            if [ -f "$XRAY_CONF" ] && command -v jq >/dev/null; then
                tmp=$(mktemp)
                jq --arg email "$user" '.inbounds[0].settings.clients |= map(select(.email != $email))' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
                systemctl restart xray 2>/dev/null
            fi

            # AÇÃO 3: Registrar no Banco de Bloqueados
            echo "$user|$(date +%s)|$total_cons" >> "$BLOCKED_DB"
        fi

    done < "$USERS_DB"

    sleep 15 # Intervalo entre verificações
done
