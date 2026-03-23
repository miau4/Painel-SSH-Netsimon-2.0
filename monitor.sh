#!/bin/bash
# ==========================================
#    PAINEL NETSIMON - MONITOR REAL-TIME
# ==========================================

P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; NC='\033[0m'

cpu_usage() {
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f", usage}'
}

ram_usage() {
    free -h | awk '/Mem:/ {print $3 "/" $2}'
}

ssh_conn() {
    ps aux | grep -i sshd | grep -v root | grep -v grep | wc -l
}

xray_conn() {
    # Conta apenas conexões ESTABELECIDAS na porta 443, filtrando IPs únicos 
    # Isso remove os "fantasmas" de conexões semi-abertas ou bots
    netstat -anp | grep :443 | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort -u | grep -v "127.0.0.1" | wc -l
}

while true; do
    clear
    echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${P}║${W}             📊 MONITOR DE RECURSOS (REAL-TIME)               ${P}║${NC}"
    echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    IP_SERV=$(curl -s --connect-timeout 2 ifconfig.me || echo "137.131.162.13")
    UP_TIME=$(uptime -p | sed 's/up //')

    echo -e " ${W}SERVIDOR IP:${NC}  ${C}$IP_SERV${NC}"
    echo -e " ${W}UPTIME:     ${NC}  ${C}$UP_TIME${NC}"
    echo -e ""
    echo -e " ${P}RECURSOS DO SISTEMA:${NC}"
    echo -e " ${W}CPU Uso:    ${G}$(cpu_usage)%${NC}"
    echo -e " ${W}RAM Uso:    ${G}$(ram_usage)${NC}"
    echo -e ""
    echo -e " ${P}CONEXÕES ATIVAS:${NC}"
    echo -e " ${W}SSH / WS:   ${Y}$(ssh_conn) usuários online${NC}"
    echo -e " ${W}Xray Core:  ${Y}$(xray_conn) conexões reais${NC}"
    echo -e ""
    echo -e " ${P}STATUS DOS SERVIÇOS:${NC}"
    
    pgrep xray >/dev/null && echo -e " ${W}Xray Core:  ${G}ATIVO${NC}" || echo -e " ${W}Xray Core:  ${R}INATIVO${NC}"
    pgrep -f limit.sh >/dev/null && echo -e " ${W}Limiter:    ${G}ATIVO${NC}" || echo -e " ${W}Limiter:    ${R}INATIVO${NC}"

    echo -e ""
    echo -e "${P}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${Y}   Dica: Atualizando a cada 5s. Use CTRL+C para sair.${NC}"
    echo -e "${P}══════════════════════════════════════════════════════════════${NC}"
    
    sleep 5
done
