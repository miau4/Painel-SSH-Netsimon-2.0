#!/bin/bash

USERDB="/etc/xray-manager/users.db"
BLOCKED="/etc/xray-manager/blocked.db"
XRAY_CONF="/etc/xray/config.json"
XRAY_LOG="/var/log/xray/access.log"

while true; do
    if [ -f "$USERDB" ]; then
        while IFS="|" read -r user uuid exp pass limit; do
            [[ -z "$user" ]] && continue
            [[ ! "$limit" =~ ^[0-9]+$ ]] && limit=1

            # 1. CONTAGEM SSH/DNS
            cons_ssh=$(ps aux | grep -i sshd | grep -v root | grep -v grep | grep "$user" | wc -l)

            # 2. CONTAGEM XRAY (IPs Únicos)
            cons_xray=0
            if [ -f "$XRAY_LOG" ]; then
                cons_xray=$(grep "$user" "$XRAY_LOG" | tail -n 100 | awk '{print $3}' | cut -d: -f1 | sort -u | grep -v "^$" | wc -l)
            fi

            total=$((cons_ssh + cons_xray))

            # 3. AÇÃO SE EXCEDER
            if [ "$total" -gt "$limit" ]; then
                # Mata conexões SSH e SlowDNS
                pkill -u "$user" &>/dev/null
                # Tranca a senha do sistema (Impede novo login SSH)
                passwd -l "$user" &>/dev/null
                
                # Remove do Xray (Opcional: se quiser banir do VLESS na hora)
                if command -v jq &>/dev/null && [ -f "$XRAY_CONF" ]; then
                    tmp=$(mktemp)
                    jq --arg u "$user" '.inbounds[0].settings.clients |= map(select(.email != $u))' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
                    systemctl restart xray &>/dev/null
                fi

                # Registra no banco de bloqueados
                if ! grep -q "^$user|" "$BLOCKED"; then
                    echo "$user|$(date +%d/%m/%Y)|$total/$limit" >> "$BLOCKED"
                fi
            fi
        done < "$USERDB"
    fi
    sleep 10 # Verificação a cada 10 segundos para ser implacável
done
