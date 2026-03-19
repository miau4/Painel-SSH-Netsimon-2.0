#!/bin/bash

USERS="/etc/xray-manager/users.xray"
LOG="/var/log/xray/access.log"
BLOCKED="/etc/xray-manager/blocked.db"
CONFIG="/etc/xray/config.json"

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

mkdir -p /etc/xray-manager
[ ! -f "$USERS" ] && touch "$USERS"
[ ! -f "$BLOCKED" ] && touch "$BLOCKED"

echo -e "${CYAN}=== LIMITER XRAY (PRO) ===${NC}"

# -------------------------------
# VERIFICA XRAY
# -------------------------------
if ! command -v xray >/dev/null 2>&1; then
    echo -e "${RED}Xray não encontrado!${NC}"
    exit
fi

while true; do

    NOW=$(date +%s)

    while IFS="|" read -r user uuid exp pass limit; do

        [[ -z "$user" ]] && continue
        [[ ! "$limit" =~ ^[0-9]+$ ]] && limit=1

        # -------------------------------
        # JÁ BLOQUEADO?
        # -------------------------------
        if grep -q "^$user|" "$BLOCKED"; then
            continue
        fi

        # -------------------------------
        # CONEXÕES (API)
        # -------------------------------
        connections=0

        if xray api statsquery --pattern "user>>>$user>>>online" >/dev/null 2>&1; then
            connections=$(xray api statsquery --pattern "user>>>$user>>>online" 2>/dev/null | grep -o '[0-9]*$')
            [[ ! "$connections" =~ ^[0-9]+$ ]] && connections=0
        fi

        # -------------------------------
        # IPs (LOG REAL)
        # -------------------------------
        total_ips=0

        if [ -f "$LOG" ]; then
            ips=$(grep "$user" "$LOG" 2>/dev/null | tail -n 100 | awk '{print $3}' | cut -d: -f1 | sort | uniq)
            total_ips=$(echo "$ips" | grep -c .)
        fi

        # -------------------------------
        # DEBUG (opcional)
        # -------------------------------
        echo "[$(date)] $user -> conexões=$connections | ips=$total_ips | limite=$limit"

        # -------------------------------
        # VERIFICA LIMITE
        # -------------------------------
        if [ "$connections" -gt "$limit" ] || [ "$total_ips" -gt "$limit" ]; then

            echo -e "${RED}🚫 $user excedeu limite!${NC}"

            # -------------------------------
            # REMOVER DO XRAY
            # -------------------------------
            if [ -f "$CONFIG" ] && command -v jq >/dev/null; then

                tmp=$(mktemp)

                jq --arg email "$user" '
                .inbounds[0].settings.clients |= map(select(.email != $email))
                ' "$CONFIG" > "$tmp"

                if [ $? -eq 0 ] && [ -s "$tmp" ]; then
                    mv "$tmp" "$CONFIG"
                    systemctl restart xray 2>/dev/null
                else
                    echo -e "${RED}Erro ao atualizar config.json${NC}"
                    rm -f "$tmp"
                fi

            fi

            # -------------------------------
            # REGISTRAR BLOQUEIO
            # -------------------------------
            echo "$user|$NOW" >> "$BLOCKED"

            echo -e "${YELLOW}🔒 $user bloqueado${NC}"

        fi

    done < "$USERS"

    sleep 20

done
