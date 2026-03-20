#!/bin/bash
USERDB="/etc/xray-manager/users.db"
BLOCKED="/etc/xray-manager/blocked.db"
XRAY_LOG="/var/log/xray/access.log"

while true; do
    while IFS="|" read -r user uuid exp pass limit; do
        [[ -z "$user" ]] && continue
        
        # Conta conexões totais
        con_ssh=$(ps aux | grep -i sshd | grep -v root | grep -v grep | grep "$user" | wc -l)
        con_xray=$(grep "$user" "$XRAY_LOG" | tail -n 50 | awk '{print $3}' | cut -d: -f1 | sort -u | grep -v "^$" | wc -l)
        total=$((con_ssh + con_xray))

        if [ "$total" -gt "$limit" ]; then
            # AÇÃO DE BLOQUEIO
            pkill -u "$user" # Derruba conexões SSH
            passwd -l "$user" # Tranca a conta no sistema
            
            # Registra no log de bloqueados se não estiver lá
            if ! grep -q "^$user" "$BLOCKED"; then
                echo "$user|$(date +%Y-%m-%d)|$total/$limit" >> "$BLOCKED"
            fi
        fi
    done < "$USERDB"
    sleep 15
done
