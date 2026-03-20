#!/bin/bash
BASE="/etc/painel"
USERDB="/etc/xray-manager/users.db"
BLOCKED="/etc/xray-manager/blocked.db"

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# Funções de Status
get_cpu() { top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}'; }
get_ram() { free | awk '/Mem:/ {printf("%d"), $3/$2 * 100}'; }
get_disk() { df / | awk 'NR==2 {print $5}' | sed 's/%//'; }
get_total() { [ -f "$USERDB" ] && wc -l < "$USERDB" || echo 0; }
get_online() { ps aux | grep -i sshd | grep -v root | grep -v grep | wc -l; }
status_serv() { systemctl is-active --quiet "$1" && echo -e "${GREEN}ON ${NC}" || echo -e "${RED}OFF${NC}"; }

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
printf "${CYAN}║${NC} Users: %-10s Online: %-10s Blocked: %-9s ${CYAN}║\n" "$(get_total)" "$(get_online)" "$(get_total)"
printf "${CYAN}║${NC} IP: %-15s Xray: %-12s Limiter: %-10s ${CYAN}║\n" "$IP" "$(status_serv xray)" "$(pgrep -f limit.sh >/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
printf "${CYAN}║${NC} CPU  %-35s ${CYAN}║\n" "$(bar $CPU)"
printf "${CYAN}║${NC} RAM  %-35s ${CYAN}║\n" "$(bar $RAM)"
printf "${CYAN}║${NC} DISK %-35s ${CYAN}║\n" "$(bar $DISK)"
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
read -p "Escolha: " op

case $op in
    1) bash "$BASE/adduser.sh" ;;
    5) bash "$BASE/online.sh" ;;
    13) speedtest-cli || apt install speedtest-cli -y ;;
    17) watch -n 2 -c "bash $BASE/monitor.sh" ;;
    0) exit ;;
esac
done
