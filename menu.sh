#!/bin/bash

# Diretórios e Arquivos
BASE="/etc/painel"
USERDB="/etc/xray-manager/users.db"
BLOCKED="/etc/xray-manager/blocked.db"
XRAY_CONF="/etc/xray/config.json"

# Cores
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ===============================
# FUNÇÕES DE SISTEMA (CORRIGIDAS)
# ===============================
get_cpu() {
    # Coleta uso real de CPU somando User + System
    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')
    echo "${cpu:-0}"
}

get_ram() {
    # Porcentagem de RAM usada
    local ram=$(free | awk '/Mem:/ {printf("%d"), $3/$2 * 100}')
    echo "${ram:-0}"
}

get_disk() {
    # Uso de disco da partição principal
    local disk=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "${disk:-0}"
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

get_total() { [ -f "$USERDB" ] && wc -l < "$USERDB" || echo 0; }
get_blocked() { [ -f "$BLOCKED" ] && wc -l < "$BLOCKED" || echo 0; }

get_online() { 
    # Soma conexões SSH/SlowDNS e processos Proxy
    local ssh_online=$(ps aux | grep -i sshd | grep -v root | grep -v grep | wc -l)
    echo "$ssh_online"
}

# ===============================
# LOOP DO MENU
# ===============================
while true; do
clear
CPU=$(get_cpu)
RAM=$(get_ram)
DISK=$(get_disk)
TOTAL=$(get_total)
ONLINE=$(get_online)
BLOCKED_COUNT=$(get_blocked)
IP=$(curl -s --connect-timeout 2 ifconfig.me || hostname -I | awk '{print $1}')

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}            🚀 NETSIMON ENTERPRISE PANEL 2.0 🚀               ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${CYAN}║${NC} ${GREEN}Usuários:${NC} %-5s ${GREEN}Online:${NC} %-5s ${RED}Bloqueados:${NC} %-5s ${CYAN}║\n" "$TOTAL" "$ONLINE" "$BLOCKED_COUNT"
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
echo -ne "${YELLOW}Escolha uma opção: ${NC}"
read op

case $op in
    1|01) bash "$BASE/adduser.sh" ;;
    2|02) bash "$BASE/deluser.sh" ;;
    3|03) 
        echo -e "\n${YELLOW}--- LISTA DE USUÁRIOS ---${NC}"
        [ -s "$USERDB" ] && column -t -s "|" "$USERDB" || echo "Vazio"
        read -p "Pressione ENTER..." 
        ;;
    4|04) bash "$BASE/online.sh" ;;
    5|05) [ -s "$BLOCKED" ] && cat "$BLOCKED" || echo "Nenhum bloqueio."; read -p "ENTER..." ;;
    6|06) bash "$BASE/unblock.sh" ;;
    7|07) systemctl restart xray; echo "Xray Reiniciado"; sleep 1 ;;
    8|08) > "$BLOCKED"; echo "Bloqueios limpos"; sleep 1 ;;
    9|09) bash "$BASE/install.sh" ;;
    11) nohup bash "$BASE/limit.sh" >/dev/null 2>&1 & ; echo "Limiter Ativo"; sleep 1 ;;
    12) pkill -f "limit.sh"; echo "Limiter Parado"; sleep 1 ;;
    13) bash "$BASE/websocket.sh" ;;
    14) bash "$BASE/slowdns-server.sh" ;;
    15) bash "$BASE/xray.sh" ;;
    16) watch -n 2 "ps aux | grep sshd | grep -v root | grep -v grep" ;;
    17) tail -f /var/log/xray/access.log ;;
    18) cp "$XRAY_CONF" "$XRAY_CONF.bak"; echo "Backup ok"; sleep 1 ;;
    20) 
        clear
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${GREEN}          📊 INFORMAÇÕES DA VPS           ${NC}"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        echo -e "${YELLOW}SERVIÇO      |  PORTA   |  STATUS${NC}"
        echo -e "------------------------------------------"
        # Status SSH
        echo -ne "SSH Core     |  22      |  " && systemctl is-active --quiet ssh && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"
        # Status Xray
        XP=$(grep '"port"' "$XRAY_CONF" 2>/dev/null | awk '{print $2}' | sed 's/,//g')
        echo -ne "Xray Vless   |  ${XP:-N/A}     |  " && systemctl is-active --quiet xray && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"
        # Status WebSockets (Python)
        WSP=$(netstat -tlpn 2>/dev/null | grep python | awk '{print $4}' | cut -d: -f2 | xargs)
        echo -e "WebSockets   |  ${WSP:-None} |  $(pgrep -f proxy.py >/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
        # Status SlowDNS
        SDNS=$(pgrep -f dnstt-server >/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
        echo -e "SlowDNS      |  53      |  $SDNS"
        echo -e "${CYAN}══════════════════════════════════════════${NC}"
        read -p "Pressione Enter para voltar..."
        ;;
    0|00) exit 0 ;;
    *) echo -e "${RED}Opção inválida!${NC}"; sleep 1 ;;
esac
done
