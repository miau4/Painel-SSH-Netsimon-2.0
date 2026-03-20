#!/bin/bash

BASE="/etc/painel"
USERDB="/etc/xray-manager/users.db"
BLOCKED="/etc/xray-manager/blocked.db"

# Cores
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Funções de Status Corrigidas
get_cpu() { 
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    echo "${cpu%.*}"
}
get_ram() { 
    local ram=$(free | awk '/Mem:/ {printf("%d"), $3/$2 * 100}')
    echo "$ram"
}
get_disk() { 
    local disk=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "$disk"
}

bar() {
    local percent=$1
    local size=10
    local filled=$((percent * size / 100))
    local empty=$((size - filled))
    printf "["
    for ((i=0;i<filled;i++)); do printf "#"; done
    for ((i=0;i<empty;i++)); do printf "-"; done
    printf "] %d%%" "$percent"
}

status_service() {
    systemctl is-active --quiet "$1" && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"
}

while true; do
clear
CPU=$(get_cpu); RAM=$(get_ram); DISK=$(get_disk)
IP=$(curl -s --connect-timeout 2 ifconfig.me || hostname -I | awk '{print $1}')

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}            🚀 NETSIMON ENTERPRISE PANEL 2.0 🚀               ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC} CPU $(bar $CPU)  RAM $(bar $RAM)  DISK $(bar $DISK) ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${CYAN}║${WHITE} 01) Criar Usuário         ${CYAN}│${WHITE} 11) Ativar Limiter        ${CYAN}║\n"
printf "${CYAN}║${WHITE} 02) Remover Usuário       ${CYAN}│${WHITE} 12) Parar Limiter         ${CYAN}║\n"
printf "${CYAN}║${WHITE} 03) Listar Usuários       ${CYAN}│${WHITE} 13) WebSocket Manager     ${CYAN}║\n"
printf "${CYAN}║${WHITE} 04) Usuários Online       ${CYAN}│${WHITE} 14) SlowDNS Manager       ${CYAN}║\n"
printf "${CYAN}║${WHITE} 05) Ver Bloqueados        ${CYAN}│${WHITE} 15) Xray Manager          ${CYAN}║\n"
printf "${CYAN}║${WHITE} 06) Desbloquear Usuário   ${CYAN}│${WHITE} 16) Monitor Tempo Real    ${CYAN}║\n"
printf "${CYAN}║${WHITE} 07) Reiniciar Xray        ${CYAN}│${WHITE} 17) Ver Logs Xray         ${CYAN}║\n"
printf "${CYAN}║${WHITE} 08) Limpar Bloqueios      ${CYAN}│${WHITE} 18) Backup Config         ${CYAN}║\n"
printf "${CYAN}║${WHITE} 09) Reparar Sistema       ${CYAN}│${WHITE} 19) Config. Portas/IP     ${CYAN}║\n"
printf "${CYAN}║${WHITE} 10) Informações Sistema   ${CYAN}│${WHITE} 20) VPS INFO (Portas)     ${CYAN}║\n"
printf "${CYAN}║${WHITE} 00) Sair                  ${CYAN}│${WHITE}                           ${CYAN}║\n"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
read -p "Escolha: " op

case $op in
    1) bash "$BASE/adduser.sh" ;;
    2) bash "$BASE/deluser.sh" ;;
    3) column -t -s "|" "$USERDB"; read -p "Enter..." ;;
    13) bash "$BASE/websocket.sh" ;;
    14) bash "$BASE/slowdns-server.sh" ;;
    15) bash "$BASE/xray.sh" ;;
    20) 
        clear
        echo -e "${YELLOW}--- SERVIÇOS E PORTAS ATIVAS ---${NC}"
        netstat -tulnp | grep -E 'xray|python|sshd|dnstt' | awk '{print $4, $7}' | sed 's/0.0.0.0://g'
        read -p "Pressione Enter..." 
        ;;
    0|00) exit ;;
esac
done
