#!/bin/bash

# Caminhos
BASE="/etc/painel"
USERDB="/etc/xray-manager/users.db"
BLOCKED="/etc/xray-manager/blocked.db"
XRAY_CONF="/etc/xray/config.json"

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# Funções de Status (Garantindo alinhamento)
get_cpu() { top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}'; }
get_ram() { free | awk '/Mem:/ {printf("%d"), $3/$2 * 100}'; }
get_disk() { df / | awk 'NR==2 {print $5}' | sed 's/%//'; }
get_total() { [ -f "$USERDB" ] && wc -l < "$USERDB" || echo 0; }
get_online() { 
    # Soma SSH e processos do Proxy Python
    local ssh=$(ps aux | grep -i sshd | grep -v root | grep -v grep | wc -l)
    echo "$ssh"
}
get_blocked() { [ -f "$BLOCKED" ] && wc -l < "$BLOCKED" || echo 0; }

status_serv() { 
    systemctl is-active --quiet "$1" && echo -e "${GREEN}ON ${NC}" || echo -e "${RED}OFF${NC}" 
}

bar() {
    local p=$1; local size=20; local filled=$((p * size / 100)); local empty=$((size - filled))
    printf "["
    for ((i=0;i<filled;i++)); do printf "#"; done
    for ((i=0;i<empty;i++)); do printf "-"; done
    printf "] %d%%" "$p"
}

while true; do
clear
CPU=$(get_cpu); RAM=$(get_ram); DISK=$(get_disk)
IP=$(curl -s --connect-timeout 2 ifconfig.me || echo "0.0.0.0")

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}               🚀 NETSIMON ENTERPRISE PANEL 🚀                ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${CYAN}║${NC} Users: %-10s Online: %-10s Blocked: %-9s ${CYAN}║\n" "$(get_total)" "$(get_online)" "$(get_blocked)"
printf "${CYAN}║${NC} IP: %-15s Xray: %-12s Limiter: %-10s ${CYAN}║\n" "$IP" "$(status_serv xray)" "$(pgrep -f limit.sh >/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
printf "${CYAN}║${NC} CPU  %-51s ${CYAN}║\n" "$(bar $CPU)"
printf "${CYAN}║${NC} RAM  %-51s ${CYAN}║\n" "$(bar $RAM)"
printf "${CYAN}║${NC} DISK %-51s ${CYAN}║\n" "$(bar $DISK)"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${CYAN}║${WHITE} 01) Criar Usuário        ${CYAN}│${WHITE} 11) Ativar Limiter         ${CYAN}║\n"
printf "${CYAN}║${WHITE} 02) Criar Teste          ${CYAN}│${WHITE} 12) Parar Limiter          ${CYAN}║\n"
printf "${CYAN}║${WHITE} 03) Remover Usuário      ${CYAN}│${WHITE} 13) Teste Velocidade       ${CYAN}║\n"
printf "${CYAN}║${WHITE} 04) Listar Usuários      ${CYAN}│${WHITE} 14) WebSocket Manager      ${CYAN}║\n"
printf "${CYAN}║${WHITE} 05) Usuários Online      ${CYAN}│${WHITE} 15) SlowDNS Manager        ${CYAN}║\n"
printf "${CYAN}║${WHITE} 06) Ver Bloqueados       ${CYAN}│${WHITE} 16) Xray Manager           ${CYAN}║\n"
printf "${CYAN}║${WHITE} 07) Desbloquear Usuário  ${CYAN}│${WHITE} 17) Monitor Tempo Real     ${CYAN}║\n"
printf "${CYAN}║${WHITE} 08) Limpar Bloqueios     ${CYAN}│${WHITE} 18) Ver Logs               ${CYAN}║\n"
printf "${CYAN}║${WHITE} 09) Reiniciar Xray       ${CYAN}│${WHITE} 19) Backup Config          ${CYAN}║\n"
printf "${CYAN}║${WHITE} 10) Reparar Sistema      ${CYAN}│${WHITE} 00) Sair                   ${CYAN}║\n"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -ne "${YELLOW}Escolha: ${NC}"
read op

case $op in
    1|01) bash "$BASE/adduser.sh" ;;
    2|02) bash "$BASE/addtest.sh" ;; # Certifique-se de ter este script
    3|03) bash "$BASE/deluser.sh" ;;
    4|04) 
        echo -e "\n${YELLOW}--- LISTA DE USUÁRIOS ---${NC}"
        [ -s "$USERDB" ] && column -t -s "|" "$USERDB" || echo "Vazio"
        read -p "ENTER..." ;;
    5|05) bash "$BASE/online.sh" ;;
    6|06) [ -s "$BLOCKED" ] && cat "$BLOCKED" || echo "Nenhum bloqueio."; read -p "ENTER..." ;;
    7|07) bash "$BASE/unblock.sh" ;;
    8|08) > "$BLOCKED"; echo "Bloqueios limpos!"; sleep 1 ;;
    9|09) systemctl restart xray; echo "Xray Reiniciado!"; sleep 1 ;;
    10) 
        clear
        echo -e "${YELLOW}Reparando sistema via GitHub...${NC}"
        wget -q -O /tmp/install.sh "https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon/main/install.sh"
        chmod +x /tmp/install.sh
        bash /tmp/install.sh
        ;;
    11) nohup bash "$BASE/limit.sh" >/dev/null 2>&1 & ; echo "Limiter ON"; sleep 1 ;;
    12) pkill -f limit.sh; echo "Limiter OFF"; sleep 1 ;;
    13) 
        clear
        echo -e "${GREEN}Iniciando Teste de Velocidade...${NC}"
        speedtest-cli --simple || (apt install speedtest-cli -y && speedtest-cli --simple)
        read -p "ENTER..." ;;
    14) bash "$BASE/websocket.sh" ;;
    15) bash "$BASE/slowdns-server.sh" ;;
    16) bash "$BASE/xray.sh" ;;
    17) watch -n 2 -c "bash $BASE/monitor.sh" ;;
    18) tail -n 50 /var/log/xray/access.log; read -p "ENTER..." ;;
    19) cp "$XRAY_CONF" "$XRAY_CONF.bak"; echo "Backup realizado!"; sleep 1 ;;
    0|00) clear; exit 0 ;;
    *) echo -e "${RED}Opção inválida!${NC}"; sleep 1 ;;
esac
done
