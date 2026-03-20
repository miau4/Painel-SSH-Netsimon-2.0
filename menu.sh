#!/bin/bash
BASE="/etc/painel"
USERDB="/etc/xray-manager/users.db"
BLOCKED="/etc/xray-manager/blocked.db"
XRAY_CONF="/etc/xray/config.json"

# Cores
G='\033[1;32m'; R='\033[1;31m'; C='\033[1;36m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

# Funções de Status Blindadas
get_cpu() { top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}'; }
get_ram() { free | awk '/Mem:/ {printf("%d"), $3/$2 * 100}'; }
get_disk() { df / | awk 'NR==2 {print $5}' | sed 's/%//'; }
get_total() { [ -f "$USERDB" ] && wc -l < "$USERDB" || echo 0; }
get_online() { ps aux | grep -i sshd | grep -v root | grep -v grep | wc -l; }

status_serv() { 
    if systemctl list-unit-files | grep -q "$1.service"; then
        systemctl is-active --quiet "$1" && echo -e "${G}ON ${NC}" || echo -e "${R}OFF${NC}"
    else
        echo -e "${Y}-- ${NC}" # Serviço não instalado ainda
    fi
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

# Detecção segura de Porta Xray
if [ -f "$XRAY_CONF" ]; then
    XP=$(grep '"port"' "$XRAY_CONF" | head -n1 | awk '{print $2}' | sed 's/,//g')
    [ -z "$XP" ] && XP="N/A"
else
    XP="--"
fi

echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}               🚀 NETSIMON ENTERPRISE PANEL 🚀                ${C}║${NC}"
echo -e "${C}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${C}║${NC} Users: %-10s Online: %-10s Blocked: %-9s ${C}║\n" "$(get_total)" "$(get_online)" "$(get_total)"
printf "${C}║${NC} IP: %-15s Xray Port: %-8s Limiter: %-10s ${C}║\n" "$IP" "$XP" "$(pgrep -f limit.sh >/dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}")"
printf "${C}║${NC} CPU  %-51s ${C}║\n" "$(bar $CPU)"
printf "${C}║${NC} RAM  %-51s ${C}║\n" "$(bar $RAM)"
printf "${C}║${NC} DISK %-51s ${C}║\n" "$(bar $DISK)"
echo -e "${C}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${C}║${W} 01) Criar Usuário        ${C}│${W} 11) Ativar Limiter         ${C}║\n"
printf "${C}║${W} 02) Criar Teste          ${C}│${W} 12) Parar Limiter          ${C}║\n"
printf "${C}║${W} 03) Remover Usuário      ${C}│${W} 13) Teste Velocidade       ${C}║\n"
printf "${C}║${W} 04) Listar Usuários      ${C}│${W} 14) WebSocket Manager      ${C}║\n"
printf "${C}║${W} 05) Usuários Online      ${C}│${W} 15) SlowDNS Manager        ${C}║\n"
printf "${C}║${W} 06) Ver Bloqueados       ${C}│${W} 16) Xray Manager           ${C}║\n"
printf "${C}║${W} 07) Desbloquear Usuário  ${C}│${W} 17) Monitor Tempo Real     ${C}║\n"
printf "${C}║${W} 08) Limpar Bloqueios     ${C}│${W} 18) Ver Logs               ${C}║\n"
printf "${C}║${W} 09) Reiniciar Xray       ${C}│${W} 19) Backup Config          ${C}║\n"
printf "${C}║${W} 10) Reparar Sistema      ${C}│${W} 00) Sair                   ${C}║\n"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -ne "${Y}Escolha: ${NC}"; read op

case $op in
    1|01) bash "$BASE/adduser.sh" ;;
    2|02) bash "$BASE/addtest.sh" ;;
    3|03) bash "$BASE/deluser.sh" ;;
    4|04) [ -s "$USERDB" ] && column -t -s "|" "$USERDB" || echo "Vazio"; read -p ".." ;;
    5|05) bash "$BASE/online.sh" ;;
    6|06) [ -s "$BLOCKED" ] && cat "$BLOCKED" || echo "Vazio"; read -p ".." ;;
    7|07) bash "$BASE/unblock.sh" ;;
    10) wget -q -O /tmp/i.sh "$GITHUB_URL/install.sh" && bash /tmp/i.sh ;;
    11) nohup bash "$BASE/limit.sh" >/dev/null 2>&1 & ; echo "ON"; sleep 1 ;;
    12) pkill -f limit.sh; echo "OFF"; sleep 1 ;;
    13) speedtest-cli --simple || apt install speedtest-cli -y; read -p ".." ;;
    14) bash "$BASE/websocket.sh" ;;
    15) bash "$BASE/slowdns-server.sh" ;;
    16) bash "$BASE/xray.sh" ;;
    17) watch -n 2 -c "bash $BASE/monitor.sh" ;;
    18) [ -f /var/log/xray/access.log ] && tail -n 50 /var/log/xray/access.log || echo "Sem logs."; read -p ".." ;;
    0|00) exit 0 ;;
    *) sleep 1 ;;
esac
done
