#!/bin/bash
# NETSIMON ENTERPRISE - QUEM ESTÁ ONLINE?

USERDB="/etc/xray-manager/users.db"
XRAY_LOG="/var/log/xray/access.log"

C='\033[1;36m'; G='\033[1;32m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}             👥 USUÁRIOS CONECTADOS AGORA                     ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
printf "${W}%-15s | %-15s | %-10s | %-10s${NC}\n" "USUÁRIO" "IP ORIGEM" "PROTOCOLO" "LIMITE"
echo -e "${C}----------------------------------------------------------------${NC}"

# 1. Listar SSH Online
while read -r line; do
    user=$(echo "$line" | awk '{print $1}')
    ip=$(echo "$line" | awk '{print $3}')
    limite=$(grep "^$user|" "$USERDB" | cut -d'|' -f5 || echo "1")
    if [[ "$user" != "root" && "$user" != "USER" ]]; then
        printf "%-15s | %-15s | %-10s | %-10s\n" "$user" "$ip" "${G}SSH${NC}" "$limite"
    fi
done < <(who | grep -v "root")

# 2. Listar Xray Online (IPs ativos nos últimos 5 minutos)
if [ -f "$XRAY_LOG" ]; then
    # Extrai usuários e IPs do log
    tail -n 200 "$XRAY_LOG" | grep "accepted" | awk '{print $11, $6}' | sort -u | while read -r user_email ip_full; do
        user=$(echo "$user_email" | cut -d: -f2)
        ip=$(echo "$ip_full" | cut -d: -f1)
        limite=$(grep "^$user|" "$USERDB" | cut -d'|' -f5 || echo "1")
        
        if [ -n "$user" ]; then
            printf "%-15s | %-15s | %-10s | %-10s\n" "$user" "$ip" "${C}XRAY${NC}" "$limite"
        fi
    done
fi

echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
read -p "Pressione ENTER para voltar..."
