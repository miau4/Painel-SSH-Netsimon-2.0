#!/bin/bash

USERS="/etc/xray-manager/users.xray"
BLOCKED="/etc/xray-manager/blocked.db"
CONFIG="/etc/xray/config.json"

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${CYAN}=== UNBLOCK XRAY (AUTO) ===${NC}"

[ ! -f "$BLOCKED" ] && touch "$BLOCKED"
[ ! -f "$USERS" ] && touch "$USERS"

# tempo de bloqueio (segundos)
TIME_BLOCK=300

while true; do

    NOW=$(date +%s)
    tmp_block=$(mktemp)

    RESTART_NEEDED=0

    while IFS="|" read -r user block_time; do

        [[ -z "$user" ]] && continue

        diff=$((NOW - block_time))

        if [ "$diff" -ge "$TIME_BLOCK" ]; then

            linha=$(grep "^$user|" "$USERS")

            if [ -n "$linha" ]; then

                uuid=$(echo "$linha" | cut -d'|' -f2)

                if [ -f "$CONFIG" ] && command -v jq >/dev/null; then

                    # verifica se já existe no Xray
                    exists=$(jq --arg email "$user" '
                    .inbounds[0].settings.clients[]? | select(.email == $email)
                    ' "$CONFIG")

                    if [ -z "$exists" ]; then

                        tmp_config=$(mktemp)

                        jq --arg uuid "$uuid" --arg email "$user" '
                        .inbounds[0].settings.clients =
                        (.inbounds[0].settings.clients // []) + [
                            {
                                "id": $uuid,
                                "email": $email
                            }
                        ]
                        ' "$CONFIG" > "$tmp_config"

                        if [ $? -eq 0 ] && [ -s "$tmp_config" ]; then
                            mv "$tmp_config" "$CONFIG"
                            RESTART_NEEDED=1
                            echo -e "${GREEN}🔓 $user desbloqueado${NC}"
                        else
                            echo -e "${RED}Erro ao restaurar $user${NC}"
                            rm -f "$tmp_config"
                            echo "$user|$block_time" >> "$tmp_block"
                        fi

                    else
                        echo -e "${CYAN}$user já ativo (ignorado)${NC}"
                    fi

                fi

            fi

        else
            # ainda bloqueado
            echo "$user|$block_time" >> "$tmp_block"
        fi

    done < "$BLOCKED"

    mv "$tmp_block" "$BLOCKED"

    # reinicia só se necessário
    if [ "$RESTART_NEEDED" -eq 1 ]; then
        systemctl restart xray 2>/dev/null
    fi

    sleep 20

done
