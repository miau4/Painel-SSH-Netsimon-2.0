#!/bin/bash

BASE="/etc/painel"

CONFIG="/etc/xray/config.json"
USERDB="/etc/xray-manager/users.xray"
BLOCKED="/etc/xray-manager/blocked.db"

# ===============================
# INIT
# ===============================
clear

mkdir -p "$BASE" /etc/xray-manager

touch "$USERDB" "$BLOCKED"

if [ ! -f "$CONFIG" ]; then
    echo "[ERRO] config.json não encontrado!"
    exit 1
fi

# ===============================
# CORES
# ===============================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ===============================
# FUNÇÕES BASE
# ===============================
pause() {
    echo ""
    read -p "Pressione ENTER para voltar..."
}

run() {
    local file="$1"

    if [ ! -f "$file" ]; then
        echo -e "${RED}[ERRO] Arquivo não encontrado:${NC} $file"
        pause
        return
    fi

    chmod +x "$file"
    bash "$file"
    pause
}

bar() {
    local percent=$1
    [[ -z "$percent" ]] && percent=0
    ((percent > 100)) && percent=100
    ((percent < 0)) && percent=0

    local size=20
    local filled=$((percent * size / 100))
    local empty=$((size - filled))

    printf "["
    for ((i=0;i<filled;i++)); do printf "#"; done
    for ((i=0;i<empty;i++)); do printf "-"; done
    printf "] %d%%" "$percent"
}

# ===============================
# STATUS
# ===============================
get_total() { wc -l < "$USERDB" 2>/dev/null || echo 0; }
get_blocked() { wc -l < "$BLOCKED" 2>/dev/null || echo 0; }

get_online() {
    command -v xray >/dev/null || { echo 0; return; }
    xray api statsquery --pattern "user>>>" 2>/dev/null | grep -o '[0-9]*$' | awk '{s+=$1} END {print s+0}'
}

get_cpu() { top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2)}' || echo 0; }
get_ram() { free 2>/dev/null | awk '/Mem:/ {printf("%d"), $3/$2 * 100}' || echo 0; }
get_disk() { df / 2>/dev/null | awk 'NR==2 {gsub("%",""); print $5}' || echo 0; }
get_ip() { hostname -I 2>/dev/null | awk '{print $1}'; }

status_xray() { systemctl is-active xray 2>/dev/null || echo "offline"; }
status_limiter() { pgrep -f limit.sh >/dev/null && echo "ON" || echo "OFF"; }
status_unblock() { pgrep -f unblock.sh >/dev/null && echo "ON" || echo "OFF"; }

# ===============================
# LOOP
# ===============================
while true; do
clear

TOTAL=$(get_total)
ONLINE=$(get_online)
BLOCKED_COUNT=$(get_blocked)

CPU=$(get_cpu)
RAM=$(get_ram)
DISK=$(get_disk)
IP=$(get_ip)

XRAY=$(status_xray)
LIMITER=$(status_limiter)
UNBLOCK=$(status_unblock)

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}              🚀 NETSIMON ENTERPRISE PANEL 🚀                ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"

printf "${CYAN}║${NC} ${GREEN}Users:${NC} %-5s ${GREEN}Online:${NC} %-5s ${RED}Blocked:${NC} %-5s ${CYAN}║\n" "$TOTAL" "$ONLINE" "$BLOCKED_COUNT"
printf "${CYAN}║${NC} ${GREEN}IP:${NC} %-15s ${GREEN}Xray:${NC} %-8s ${YELLOW}Limiter:${NC} %-3s ${YELLOW}Unblock:${NC} %-3s ${CYAN}║\n" "$IP" "$XRAY" "$LIMITER" "$UNBLOCK"

printf "${CYAN}║${NC} CPU  "; bar "$CPU"; printf "   ${CYAN}║\n"
printf "${CYAN}║${NC} RAM  "; bar "$RAM"; printf "   ${CYAN}║\n"
printf "${CYAN}║${NC} DISK "; bar "$DISK"; printf "   ${CYAN}║\n"

echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"

printf "${CYAN}║${WHITE} 01) Criar Usuário        ${CYAN}│${WHITE} 11) Ativar Limiter        ${CYAN}║\n"
printf "${CYAN}║${WHITE} 02) Criar Teste          ${CYAN}│${WHITE} 12) Parar Limiter         ${CYAN}║\n"
printf "${CYAN}║${WHITE} 03) Remover Usuário      ${CYAN}│${WHITE} 13) Status Limiter        ${CYAN}║\n"
printf "${CYAN}║${WHITE} 04) Listar Usuários      ${CYAN}│${WHITE} 14) WebSocket Manager     ${CYAN}║\n"
printf "${CYAN}║${WHITE} 05) Usuários Online      ${CYAN}│${WHITE} 15) SlowDNS Manager       ${CYAN}║\n"
printf "${CYAN}║${WHITE} 06) Ver Bloqueados       ${CYAN}│${WHITE} 16) Xray Manager          ${CYAN}║\n"
printf "${CYAN}║${WHITE} 07) Desbloquear Usuário  ${CYAN}│${WHITE} 17) Monitor Tempo Real    ${CYAN}║\n"
printf "${CYAN}║${WHITE} 08) Limpar Bloqueios     ${CYAN}│${WHITE} 18) Ver Logs              ${CYAN}║\n"
printf "${CYAN}║${WHITE} 09) Reiniciar Xray       ${CYAN}│${WHITE} 19) Backup Config         ${CYAN}║\n"
printf "${CYAN}║${WHITE} 10) Reparar Sistema      ${CYAN}│${WHITE} 00) Sair                  ${CYAN}║\n"

echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

read -p "Escolha: " op

case $op in

1) run "$BASE/adduser.sh" ;;
2) run "$BASE/adduser.sh" ;;
3) run "$BASE/deluser.sh" ;;
4) cat "$USERDB"; pause ;;
5) run "$BASE/online.sh" ;;
6) cat "$BLOCKED"; pause ;;

7)
read -p "Usuário: " user
sed -i "/^$user|/d" "$BLOCKED"
;;

8) > "$BLOCKED" ;;
9) systemctl restart xray ;;

10) run "/etc/xray-manager/repair.sh" ;;

11)
nohup bash "$BASE/limit.sh" >/dev/null 2>&1 &
nohup bash "$BASE/unblock.sh" >/dev/null 2>&1 &
;;

12)
pkill -f limit.sh
pkill -f unblock.sh
;;

13)
ps aux | grep -E "limit.sh|unblock.sh"
pause
;;

14) run "$BASE/websocket.sh" ;;
15) run "$BASE/slowdns-server.sh" ;;
16) run "$BASE/xray.sh" ;;

17) watch -n 2 "bash $BASE/online.sh" ;;
18) tail -f /var/log/xray/access.log ;;
19) cp "$CONFIG" /etc/xray/config.backup.json ;;

0|00) exit ;;

*) echo "Opção inválida"; sleep 1 ;;

esac

done
