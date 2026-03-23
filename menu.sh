#!/bin/bash
# ==========================================
#           PAINEL NETSIMON
# ==========================================

BASE="/etc/painel"
USERDB="/etc/painel/usuarios.db"
BLOCKED="/etc/xray-manager/blocked.db"
XRAY_CONF="/etc/xray/config.json"

# Cores Estilo WebSocket
P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; B='\033[1;34m'; NC='\033[0m'

# Funções de Status do Sistema
get_cpu() { top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}'; }
get_ram() { free | awk '/Mem:/ {printf("%d"), $3/$2 * 100}'; }
get_disk() { df / | awk 'NR==2 {print $5}' | sed 's/%//'; }
get_total() { [ -f "$USERDB" ] && wc -l < "$USERDB" || echo 0; }
get_online() { ps aux | grep -i sshd | grep -v root | grep -v grep | wc -l; }
get_blocked() { [ -f "$BLOCKED" ] && wc -l < "$BLOCKED" || echo 0; }

get_expired() {
    local hoje=$(date +%s)
    local cont=0
    [[ ! -f "$USERDB" ]] && echo 0 && return
    while IFS='|' read -r user uuid exp pass lim; do
        # Pula se for marcador de teste ou se a data for inválida
        [[ "$exp" == Teste-* ]] && continue
        exp_s=$(date -d "$exp" +%s 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            [[ $exp_s -lt $hoje ]] && ((cont++))
        fi
    done < "$USERDB"
    echo "$cont"
}

# Detecção de Protocolos ON/OFF
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
    local b="["
    for ((i=0;i<filled;i++)); do b+="#"; done
    for ((i=0;i<empty;i++)); do b+="-"; done
    b+="] $p%"
    echo "$b"
}

while true; do
clear
CPU=$(get_cpu); RAM=$(get_ram); DISK=$(get_disk)
IP=$(wget -qO- ipv4.icanhazip.com || echo "0.0.0.0")

# Detecção de portas Xray
if [ -f "$XRAY_CONF" ]; then
    XP=$(jq -r '.inbounds[].port' "$XRAY_CONF" 2>/dev/null | xargs | sed 's/ /,/g')
    [ -z "$XP" ] && XP="N/A"
else
    XP="--"
fi

LMT_STAT=$(pgrep -f limit.sh >/dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}")

echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${P}║${W}                🚀 PAINEL NETSIMON                            ${P}║${NC}"
echo -e "${P}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${P}║${NC} Users: %-4s | Online: %-4s | Expired: %-4s | Block: %-4s ${P}║\n" "$(get_total)" "$(get_online)" "$(get_expired)" "$(get_blocked)"
printf "${P}║${NC} IP: %-15s | Port: %-8s | Limiter: %-8s ${P}║\n" "$IP" "$XP" "$LMT_STAT"
echo -e "${P}╟──────────────────────────────────────────────────────────────╢${NC}"
printf "${P}║${NC} XRAY: $(check_proto xray) | SLOWDNS: $(check_proto dnstt) | WS: $(check_proto proxy.py) ${P}║\n"
echo -e "${P}╟──────────────────────────────────────────────────────────────╢${NC}"
printf "${P}║${NC} CPU  %-55s ${P}║\n" "$(bar $CPU)"
printf "${P}║${NC} RAM  %-55s ${P}║\n" "$(bar $RAM)"
printf "${P}║${NC} DISK %-55s ${P}║\n" "$(bar $DISK)"
echo -e "${P}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${P}║${W} 01) Criar Usuário           ${P}│${W} 11) Ativar Limiter           ${P}║\n"
printf "${P}║${W} 02) Criar Teste             ${P}│${W} 12) Parar Limiter            ${P}║\n"
printf "${P}║${W} 03) Remover Usuário         ${P}│${W} 13) Teste Velocidade         ${P}║\n"
printf "${P}║${W} 04) Listar Usuários         ${P}│${W} 14) WebSocket Manager        ${P}║\n"
printf "${P}║${W} 05) Usuários Online         ${P}│${W} 15) SlowDNS Manager          ${P}║\n"
printf "${P}║${W} 06) Ver Bloqueados          ${P}│${W} 16) Xray Manager             ${P}║\n"
printf "${P}║${W} 07) Desbloquear Usuário     ${P}│${W} 17) Monitor Tempo Real       ${P}║\n"
printf "${P}║${W} 08) Limpar Bloqueios        ${P}│${W} 18) Ver Logs                 ${P}║\n"
printf "${P}║${W} 09) Reiniciar Xray          ${P}│${W} 19) Backup Config            ${P}║\n"
printf "${P}║${W} 10) Reparar Sistema         ${P}│${R} 00) Sair                     ${P}║\n"
echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -ne "${Y}Escolha uma opção: ${NC}"; read op

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
    11) nohup bash "$BASE/limit.sh" >/dev/null 2>&1 & echo -e "${G}Limiter ativado!${NC}"; sleep 1 ;;
    12) pkill -f limit.sh; echo -e "${R}Limiter parado!${NC}"; sleep 1 ;;
    13) clear; speedtest-cli --simple || { apt install speedtest-cli -y; speedtest-cli --simple; }; read -p "ENTER para voltar..." ;;
    14) bash "$BASE/websocket.sh" ;;
    15) bash "$BASE/slowdns-server.sh" ;;
    16) bash "$BASE/xray.sh" ;;
    17) bash "$BASE/monitor.sh" ;;
    18) 
        clear
        echo -e "${P}══════════════ LOGS DO SISTEMA ══════════════${NC}"
        
        # Tenta o log do Xray primeiro
        if [ -s /var/log/xray/access.log ]; then
            echo -e "${G}Exibindo últimos 20 acessos Xray:${NC}"
            tail -n 20 /var/log/xray/access.log
            
        # Tenta o log do SSH (Debian/Ubuntu)
        elif [ -s /var/log/auth.log ]; then
            echo -e "${G}Exibindo últimas 20 tentativas SSH/WS:${NC}"
            tail -n 20 /var/log/auth.log | grep -iE "sshd|accepted|password"
            
        # Tenta o Syslog (Caso os outros falhem)
        elif [ -s /var/log/syslog ]; then
            echo -e "${Y}Exibindo logs gerais do sistema (Syslog):${NC}"
            tail -n 20 /var/log/syslog | grep -iE "xray|dnstt|sshd"
            
        else
            echo -e "${R}Nenhum registro de log encontrado ou arquivos vazios.${NC}"
            echo -e "${W}Dica: Certifique-se que os serviços estão rodando.${NC}"
        fi
        
        echo -e "${P}──────────────────────────────────────────────${NC}"
        read -p "Pressione ENTER para voltar..." ;;
    19)
        clear
        echo -e "${Y}Gerando backup em /root/...${NC}"
        BKP_NAME="/root/backup_netsimon_$(date +%d%m%y).tar.gz"
        tar -czf "$BKP_NAME" "$BASE" "/etc/xray" 2>/dev/null
        if [ -f "$BKP_NAME" ]; then
            echo -e "${G}✅ Backup criado: $BKP_NAME${NC}"
        else
            echo -e "${R}❌ Falha ao criar backup.${NC}"
        fi
        sleep 3 ;;
    0|00) exit 0 ;;
    *) echo -e "${R}Opção inválida!${NC}"; sleep 1 ;;
esac
done
