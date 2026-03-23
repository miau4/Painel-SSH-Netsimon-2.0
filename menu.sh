#!/bin/bash
# ==========================================
#         🚀 PAINEL NETSIMON 2.0 🚀
# ==========================================

BASE="/etc/painel"
USERDB="/etc/painel/usuarios.db"
BLOCKED="/etc/xray-manager/blocked.db"
# CAMINHO CORRIGIDO:
XRAY_CONF="/usr/local/etc/xray/config.json"

# Paleta de Cores Customizada
P='\033[1;35m'; G='\033[1;32m'; GD='\033[0;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; B='\033[1;34m'; NC='\033[0m'

# Funções de Status do Sistema
get_cpu() { top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}'; }
get_ram() { free | awk '/Mem:/ {printf("%d"), $3/$2 * 100}'; }
get_disk() { df / | awk 'NR==2 {print $5}' | sed 's/%//'; }
get_total() { [ -f "$USERDB" ] && wc -l < "$USERDB" || echo 0; }
get_online() { 
    local ssh=$(ps aux | grep -i sshd | grep -v root | grep -v grep | wc -l)
    local xray=$(tail -n 100 /var/log/xray/access.log 2>/dev/null | grep "accepted" | awk '{print $6}' | cut -d: -f1 | sort -u | wc -l)
    echo $((ssh + xray))
}
get_blocked() { [ -f "$BLOCKED" ] && wc -l < "$BLOCKED" || echo 0; }

get_expired() {
    local hoje=$(date +%s)
    local cont=0
    [[ ! -f "$USERDB" ]] && echo 0 && return
    while IFS='|' read -r user uuid exp pass lim; do
        exp_s=$(date -d "$exp" +%s 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            [[ $exp_s -lt $hoje ]] && ((cont++))
        fi
    done < "$USERDB"
    echo "$cont"
}

check_proto() {
    local serv=$1
    if pgrep -f "$serv" > /dev/null || systemctl is-active --quiet "$serv" 2>/dev/null; then
        echo -e "${G}ON${NC}"
    else
        echo -e "${R}OFF${NC}"
    fi
}

bar() {
    local p=$1; local size=20; local filled=$((p * size / 100)); local empty=$((size - filled))
    local color=$G
    [ $p -gt 70 ] && color=$Y
    [ $p -gt 85 ] && color=$R
    local b="${color}["
    for ((i=0;i<filled;i++)); do b+="#"; done
    for ((i=0;i<empty;i++)); do b+="-"; done
    b+="] $p%${NC}"
    echo -e "$b"
}

while true; do
clear
CPU=$(get_cpu); RAM=$(get_ram); DISK=$(get_disk)
IP=$(wget -qO- ipv4.icanhazip.com || echo "0.0.0.0")

if [ -f "$XRAY_CONF" ]; then
    XP=$(jq -r '.inbounds[].port' "$XRAY_CONF" 2>/dev/null | xargs | sed 's/ /,/g')
    [ -z "$XP" ] && XP="N/A"
else
    XP="--"
fi

LMT_STAT=$(pgrep -f limit.sh >/dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}")

echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${P}║${C}                🚀 PAINEL NETSIMON 2.0 🚀                     ${P}║${NC}"
echo -e "${P}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${P}║${NC} ${C}Users:${Y} %-4s ${P}│${C} Online:${G} %-4s ${P}│${C} Expired:${R} %-4s ${P}│${C} Block:${R} %-4s ${P}║\n" "$(get_total)" "$(get_online)" "$(get_expired)" "$(get_blocked)"
printf "${P}║${NC} ${B}IP:${W} %-15s ${P}│${B} Port:${W} %-8s ${P}│${B} Limiter:${NC} %-8s ${P}║\n" "$IP" "$XP" "$LMT_STAT"
echo -e "${P}╟──────────────────────────────────────────────────────────────╢${NC}"
# Protocolos Centralizados com WS/SOCKS no lugar de PYTHON
printf "${P}║${NC}      ${Y}XRAY:${NC} $(check_proto xray)  ${P}│${Y}  SLOWDNS:${NC} $(check_proto dnstt)  ${P}│${Y}  WS/SOCKS:${NC} $(check_proto proxy.py)      ${P}║\n"
echo -e "${P}╟──────────────────────────────────────────────────────────────╢${NC}"
printf "${P}║${NC} CPU  %-65s ${P}║\n" "$(bar $CPU)"
printf "${P}║${NC} RAM  %-65s ${P}║\n" "$(bar $RAM)"
printf "${P}║${NC} DISK %-65s ${P}║\n" "$(bar $DISK)"
echo -e "${P}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${P}║${GD} 01) Criar Usuário           ${P}│${C} 11)${G} Ativar Limiter           ${P}║\n"
printf "${P}║${GD} 02) Criar Teste             ${P}│${C} 12)${R} Parar Limiter            ${P}║\n"
printf "${P}║${C} 03)${Y} Remover Usuário         ${P}│${P} 13) Teste Velocidade         ${P}║\n"
printf "${P}║${C} 04)${Y} Listar Usuários         ${P}│${C} 14)${B} WebSocket Manager        ${P}║\n"
printf "${P}║${C} 05)${Y} Usuários Online         ${P}│${C} 15)${B} SlowDNS Manager          ${P}║\n"
printf "${P}║${C} 06)${Y} Ver Bloqueados          ${P}│${C} 16)${B} Xray Manager             ${P}║\n"
printf "${P}║${C} 07)${Y} Desbloquear Usuário     ${P}│${C} 17)${C} Monitor Tempo Real       ${P}║\n"
printf "${P}║${C} 08)${Y} Limpar Bloqueios        ${P}│${C} 18)${C} Ver Logs                 ${P}║\n"
printf "${P}║${C} 09)${G} Reiniciar Xray          ${P}│${C} 19)${C} Backup Config            ${P}║\n"
printf "${P}║${W} 10) Reparar Sistema         ${P}│${R} 00) Sair                     ${P}║\n"
echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -ne "${Y}✨ Escolha uma opção: ${NC}"; read op

case $op in
    1|01) bash "$BASE/adduser.sh" ;;
    2|02) bash "$BASE/addtest.sh" ;;
    3|03) bash "$BASE/deluser.sh" ;;
    4|04) clear; echo -e "${P}LISTA DE USUÁRIOS${NC}"; [ -s "$USERDB" ] && column -t -s "|" "$USERDB" || echo -e "${R}Banco vazio!${NC}"; echo ""; read -p "Pressione ENTER..." ;;
    5|05) bash "$BASE/online.sh" ;;
    6|06) clear; [ -s "$BLOCKED" ] && cat "$BLOCKED" || echo -e "${R}Nenhum bloqueio.${NC}"; echo ""; read -p "Pressione ENTER..." ;;
    7|07) bash "$BASE/unblock.sh" ;;
    8|08) > "$BLOCKED"; echo -e "${G}Bloqueios limpos!${NC}"; sleep 1 ;;
    9|09) systemctl restart xray; echo -e "${G}Xray reiniciado!${NC}"; sleep 1 ;;
    10) bash "$BASE/repair.sh" ;;
    11) screen -dmS limitador bash "$BASE/limit.sh"; echo -e "${G}Limiter ativado!${NC}"; sleep 1 ;;
    12) pkill -f limit.sh; screen -wipe >/dev/null 2>&1; echo -e "${R}Limiter parado!${NC}"; sleep 1 ;;
    13) clear; speedtest-cli --simple || { apt install speedtest-cli -y; speedtest-cli --simple; }; read -p "ENTER para voltar..." ;;
    14) bash "$BASE/websocket.sh" ;;
    15) bash "$BASE/slowdns-server.sh" ;;
    16) bash "$BASE/xray.sh" ;;
    17) bash "$BASE/monitor.sh" ;;
    18) 
        clear
        echo -e "${P}══════════════ LOGS DO SISTEMA ══════════════${NC}"
        [ -s /var/log/xray/access.log ] && tail -n 20 /var/log/xray/access.log | sed "s/accepted/${G}accepted${NC}/g"
        echo -e "${P}──────────────────────────────────────────────${NC}"
        read -p "Pressione ENTER para voltar..." ;;
    19)
        clear
        echo -e "${Y}Gerando backup em /root/...${NC}"
        BKP_NAME="/root/backup_netsimon_$(date +%d%m%y).tar.gz"
        tar -czf "$BKP_NAME" "$BASE" "/etc/xray" "/usr/local/etc/xray" 2>/dev/null
        echo -e "${G}✅ Backup criado: $BKP_NAME${NC}"; sleep 3 ;;
    0|00) exit 0 ;;
    *) echo -e "${R}Opção inválida!${NC}"; sleep 1 ;;
esac
done
