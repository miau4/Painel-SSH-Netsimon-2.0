#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - MENU PRINCIPAL 2.0
# ==========================================

BASE="/etc/painel"
USERDB="/etc/xray-manager/users.db"
BLOCKED="/etc/xray-manager/blocked.db"
XRAY_CONF="/usr/local/etc/xray/config.json"
REPO_URL="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon-2.0/main"

# Cores
G='\033[1;32m'; R='\033[1;31m'; C='\033[1;36m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

# Funções de Status
get_cpu() { top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}'; }
get_ram() { free | awk '/Mem:/ {printf("%d"), $3/$2 * 100}'; }
get_disk() { df / | awk 'NR==2 {print $5}' | sed 's/%//'; }
get_total() { [ -f "$USERDB" ] && wc -l < "$USERDB" || echo 0; }
get_online() { ps aux | grep -i sshd | grep -v root | grep -v grep | wc -l; }
get_blocked() { [ -f "$BLOCKED" ] && wc -l < "$BLOCKED" || echo 0; }

bar() {
    local p=$1; local size=20; local filled=$((p * size / 100)); local empty=$((size - filled))
    local b="["
    for ((i=0;i<filled;i++)); do b+="#"; done
    for ((i=0;i<empty;i++)); do b+="-"; done
    b+="] $p%"
    echo "$b"
}

while true; do
clear
CPU=$(get_cpu); RAM=$(get_ram); DISK=$(get_disk)

# Correção na captura de IP para evitar espaços ou lixo
IP=$(wget -qO- ipv4.icanhazip.com || wget -qO- ifconfig.me/ip || echo "0.0.0.0")
IP=$(echo $IP | tr -d '[:space:]')

# Correção na detecção de portas para o padrão XHTTP/TLS (Porta 443)
if [ -f "$XRAY_CONF" ]; then
    XP=$(jq -r '.inbounds[].port' "$XRAY_CONF" 2>/dev/null | xargs | sed 's/ /,/g')
    [ -z "$XP" ] && XP="N/A"
else
    XP="--"
fi

LMT_STAT=$(pgrep -f limit.sh >/dev/null && echo "ON" || echo "OFF")

echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                🚀 NETSIMON ENTERPRISE PANEL 🚀               ${C}║${NC}"
echo -e "${C}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${C}║${NC}  Users: %-9s | Online: %-9s | Blocked: %-10s  ${C}║\n" "$(get_total)" "$(get_online)" "$(get_blocked)"
printf "${C}║${NC}  IP: %-15s | Port: %-10s | Limiter: %-10s  ${C}║\n" "$IP" "$XP" "$LMT_STAT"
echo -e "${C}╟──────────────────────────────────────────────────────────────╢${NC}"
printf "${C}║${NC}  CPU  %-55s ${C}║\n" "$(bar $CPU)"
printf "${C}║${NC}  RAM  %-55s ${C}║\n" "$(bar $RAM)"
printf "${C}║${NC}  DISK %-55s ${C}║\n" "$(bar $DISK)"
echo -e "${C}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${C}║${W} 01) Criar Usuário           ${C}│${W} 11) Ativar Limiter           ${C}║\n"
printf "${C}║${W} 02) Criar Teste             ${C}│${W} 12) Parar Limiter            ${C}║\n"
printf "${C}║${W} 03) Remover Usuário         ${C}│${W} 13) Teste Velocidade         ${C}║\n"
printf "${C}║${W} 04) Listar Usuários         ${C}│${W} 14) WebSocket Manager        ${C}║\n"
printf "${C}║${W} 05) Usuários Online         ${C}│${W} 15) SlowDNS Manager          ${C}║\n"
printf "${C}║${W} 06) Ver Bloqueados          ${C}│${W} 16) Xray Manager             ${C}║\n"
printf "${C}║${W} 07) Desbloquear Usuário     ${C}│${W} 17) Monitor Tempo Real       ${C}║\n"
printf "${C}║${W} 08) Limpar Bloqueios        ${C}│${W} 18) Ver Logs                 ${C}║\n"
printf "${C}║${W} 09) Reiniciar Xray          ${C}│${W} 19) Backup Config            ${C}║\n"
printf "${C}║${W} 10) Reparar Sistema         ${C}│${W} 00) Sair                     ${C}║\n"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -ne "${Y}Escolha uma opção: ${NC}"; read op

case $op in
    1|01) bash "$BASE/adduser.sh" ;;
    2|02) bash "$BASE/addtest.sh" ;;
    3|03) bash "$BASE/deluser.sh" ;;
    4|04) clear; [ -s "$USERDB" ] && column -t -s "|" "$USERDB" || echo -e "${R}Banco vazio!${NC}"; echo ""; read -p "Pressione ENTER..." ;;
    5|05) bash "$BASE/online.sh" ;;
    6|06) clear; [ -s "$BLOCKED" ] && cat "$BLOCKED" || echo -e "${R}Nenhum bloqueio.${NC}"; echo ""; read -p "Pressione ENTER..." ;;
    7|07) bash "$BASE/unblock.sh" ;;
    8|08) > "$BLOCKED"; echo -e "${G}Bloqueios limpos!${NC}"; sleep 1 ;;
    9|09) systemctl restart xray; echo -e "${G}Xray reiniciado!${NC}"; sleep 1 ;;
    10) bash "$BASE/repair.sh" ;;
    11) nohup bash "$BASE/limit.sh" >/dev/null 2>&1 &; echo -e "${G}Limiter ON!${NC}"; sleep 1 ;;
    12) pkill -f limit.sh; echo -e "${R}Limiter OFF!${NC}"; sleep 1 ;;
    13) speedtest-cli --simple || { echo "Instalando speedtest..."; apt install speedtest-cli -y; speedtest-cli --simple; }; read -p ".." ;;
    14) bash "$BASE/websocket.sh" ;;
    15) bash "$BASE/slowdns-server.sh" ;;
    16) bash "$BASE/xray.sh" ;;
    17) bash "$BASE/monitor.sh" ;;
    18) clear; [ -f /var/log/xray/access.log ] && tail -n 50 /var/log/xray/access.log || echo "Sem logs."; read -p "ENTER..." ;;
    19) echo -e "${Y}Funcionalidade em desenvolvimento...${NC}"; sleep 1 ;;
    0|00) exit 0 ;;
    *) echo -e "${R}Opção inválida!${NC}"; sleep 1 ;;
esac
done
