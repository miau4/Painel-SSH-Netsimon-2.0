#!/bin/bash
# ==========================================
#    USUÁRIOS ONLINE - PAINEL NETSIMON
# ==========================================

P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; NC='\033[0m'
USERDB="/etc/painel/usuarios.db"

clear
echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${P}║${W}                👥 USUÁRIOS CONECTADOS AGORA                  ${P}║${NC}"
echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"
printf " ${W}%-15s | %-18s | %-15s${NC}\n" "USUÁRIO" "IP DE CONEXÃO" "PROTOCOLO"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"

TMP_ON="/tmp/onlines.txt"
> "$TMP_ON"

# 1. SSH / WebSocket
ps aux | grep -i sshd | grep -v root | grep -v grep | while read line; do
    PID=$(echo $line | awk '{print $2}')
    USER_SSH=$(echo $line | awk '{print $11}' | sed 's/sshd://')
    if [[ ! -z "$USER_SSH" ]] && grep -q "^$USER_SSH|" "$USERDB"; then
        IP_CONN=$(netstat -anp | grep "$PID/sshd" | grep "ESTABLISHED" | awk '{print $5}' | cut -d: -f1 | head -n1)
        [[ -z "$IP_CONN" ]] && IP_CONN="WebSocket/Local"
        printf " ${G}%-15s${NC} | ${C}%-18s${NC} | ${Y}SSH/WS${NC}\n" "$USER_SSH" "$IP_CONN" >> "$TMP_ON"
    fi
done

# 2. Xray (Vless) - Busca aprimorada no log
if [ -f /var/log/xray/access.log ]; then
    # Pega as últimas 50 linhas de conexões aceitas
    LOG_DATA=$(tail -n 50 /var/log/xray/access.log | grep "accepted")
    
    while IFS='|' read -r user uuid exp pass lim; do
        # Verifica se o Nick do usuário aparece no log vinculado a um "accepted"
        if echo "$LOG_DATA" | grep -q "email: $user"; then
            # Extrai o IP vinculado àquele usuário
            IP_X=$(echo "$LOG_DATA" | grep "email: $user" | tail -n1 | awk '{print $6}' | cut -d: -f1)
            printf " ${G}%-15s${NC} | ${C}%-18s${NC} | ${P}XRAY/VLESS${NC}\n" "$user" "$IP_X" >> "$TMP_ON"
        fi
    done < "$USERDB"
fi

# Exibição
if [ -s "$TMP_ON" ]; then
    cat "$TMP_ON" | sort -u
else
    echo -e "             ${R}Nenhum usuário logado no momento.${NC}"
fi

echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
TOTAL_ON=$(sort -u "$TMP_ON" | wc -l)
echo -e " ${W}TOTAL DE CONEXÕES REAIS: ${G}$TOTAL_ON${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
rm -f "$TMP_ON"
read -p " Pressione ENTER para voltar..."
