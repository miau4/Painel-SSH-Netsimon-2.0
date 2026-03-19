#!/bin/bash

# Direitório onde estão seus scripts .sh
BASE="/etc/painel"

# Caminhos dos Bancos (Sincronizados com adduser/deluser)
CONFIG_XRAY="/etc/xray/config.json"
USERDB="/etc/xray-manager/users.db"
BLOCKED="/etc/xray-manager/blocked.db"

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
}

bar() {
    local percent=$1
    [[ -z "$percent" ]] && percent=0
    ((percent > 100)) && percent=100
    local size=15
    local filled=$((percent * size / 100))
    local empty=$((size - filled))
    printf "["
    for ((i=0;i<filled;i++)); do printf "#"; done
    for ((i=0;i<empty;i++)); do printf "-"; done
    printf "] %d%%" "$percent"
}

# ===============================
# COLETA DE STATUS
# ===============================
get_total() { wc -l < "$USERDB" 2>/dev/null || echo 0; }
get_blocked() { wc -l < "$BLOCKED" 2>/dev/null || echo 0; }
get_online() { 
    # Conta usuários SSH logados (util para SlowDNS/WS-SSH)
    local ssh_online=$(ps aux | grep -i sshd | grep -v root | grep -v grep | wc -l)
    echo "$ssh_online"
}

get_cpu() { top -bn1 | grep "Cpu(s)" | awk '{print int($2)}'; }
get_ram() { free | awk '/Mem:/ {printf("%d"), $3/$2 * 100}'; }
get_disk() { df / | awk 'NR==2 {gsub("%",""); print $5}'; }
get_ip() { curl -s ifconfig.me || hostname -I | awk '{print $1}'; }

status_xray() { systemctl is-active --quiet xray && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"; }
status_limiter() { pgrep -f "limit.sh" >/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"; }

# ===============================
# LOOP DO MENU
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

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}            🚀 NETSIMON ENTERPRISE PANEL 2.0 🚀               ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${CYAN}║${NC} ${GREEN}Usuários:${NC} %-5s ${GREEN}Online:${NC} %-5s ${RED}Bloqueados:${NC} %-5s ${CYAN}║\n" "$TOTAL" "$ONLINE" "$BLOCKED_COUNT"
printf "${CYAN}║${NC} ${GREEN}IP:${NC} %-15s ${GREEN}Xray:${NC} %-10s ${YELLOW}Limiter:${NC} %-10s ${CYAN}║\n" "$IP" "$XRAY" "$LIMITER"
echo -e "${CYAN}║${NC} CPU  $(bar $CPU)  RAM  $(bar $RAM)  DISK $(bar $DISK) ${CYAN}║${NC}"
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
printf "${CYAN}║${WHITE} 10) Informações Sistema   ${CYAN}│${WHITE} 00) Sair                  ${CYAN}║\n"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
read -p "Escolha uma opção: " op

case $op in
    1) run "$BASE/adduser.sh" ;;
    2) run "$BASE/deluser.sh" ;;
    3) 
        echo -e "\n${YELLOW}--- LISTA DE USUÁRIOS ---${NC}"
        column -t -s "|" "$USERDB" 2>/dev/null || echo "Vazio"
        pause 
        ;;
    4) run "$BASE/online.sh" ;;
    5) cat "$BLOCKED"; pause ;;
    6) 
        read -p "Nome do usuário para desbloquear: " u_desb
        sed -i "/^$u_desb|/d" "$BLOCKED"
        echo "Comando enviado." ; sleep 1
        ;;
    7) systemctl restart xray; echo "Xray Reiniciado"; sleep 1 ;;
    8) > "$BLOCKED"; echo "Bloqueios limpos"; sleep 1 ;;
    9) run "$BASE/install.sh" ;; # Usa o instalador para reparar
    11) 
        nohup bash "$BASE/limit.sh" >/dev/null 2>&1 &
        echo "Limiter iniciado em segundo plano."; sleep 1 
        ;;
    12) pkill -f "limit.sh"; echo "Limiter parado."; sleep 1 ;;
    13) run "$BASE/websocket.sh" ;;
    14) run "$BASE/slowdns-server.sh" ;;
    15) run "$BASE/xray.sh" ;;
    16) watch -n 2 "ps aux | grep sshd | grep -v root" ;;
    17) tail -f /var/log/xray/access.log ;;
    18) cp "$CONFIG_XRAY" "/etc/xray/config.backup.$(date +%F).json"; echo "Backup criado."; sleep 1 ;;
    0|00) exit 0 ;;
    *) echo -e "${RED}Opção inválida!${NC}"; sleep 1 ;;
esac
done
