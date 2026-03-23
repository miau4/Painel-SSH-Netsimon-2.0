#!/bin/bash
# ==========================================
#    PAINEL NETSIMON - MONITOR REAL-TIME
# ==========================================

# Cores Padronizadas
P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; NC='\033[0m'

cpu_usage() {
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f", usage}'
}

ram_usage() {
    free -h | awk '/Mem:/ {print $3 "/" $2}'
}

ssh_conn() {
    ps aux | grep -i sshd | grep -v root | grep -v grep | wc -l
}

xray_conn() {
    # Filtro avançado: Apenas conexões ESTABLISHED, ignora Localhost e IPs vazios
    # O 'sort -u' garante que conte IPs únicos, evitando as conexões fantasmas de bots
    netstat -anp 2>/dev/null | grep :443 | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort -u | grep -vE "127.0.0.1|0.0.0.0|^$" | wc -l
}

while true; do
    clear
    echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${P}║${W}             📊 MONITOR DE RECURSOS (REAL-TIME)               ${P}║${NC}"
    echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    IP_SERV=$(curl -s --connect-timeout 2 ifconfig.me || echo "Offline")
    UP_TIME=$(uptime -p | sed 's/up //')
    HORA=$(date +'%d/%m/%Y %H:%M:%S')

    echo -e " ${W}SERVIDOR IP:${NC}  ${C}$IP_SERV${NC}"
    echo -e " ${W}UPTIME:     ${NC}  ${C}$UP_TIME${NC}"
    echo -e " ${W}HORA LOCAL: ${NC}  ${C}$HORA${NC}"
    echo -e ""
    echo -e " ${P}RECURSOS DO SISTEMA:${NC}"
    echo -e " ${W}CPU Uso:    ${G}$(cpu_usage)%${NC}"
    echo -e " ${W}RAM Uso:    ${G}$(ram_usage)${NC}"
    echo -e ""
    echo -e " ${P}CONEXÕES ATIVAS:${NC}"
    echo -e " ${W}SSH / WS:   ${Y}$(ssh_conn) usuários online${NC}"
    echo -e " ${W}Xray Core:  ${Y}$(xray_conn) conexões reais${NC}"
    echo -e ""
    echo -e " ${P}STATUS DOS SERVIÇOS:${NC}"
    
    # Verificação de Xray
    if pgrep xray >/dev/null; then
        echo -e " ${W}Xray Core:  ${G}ATIVO${NC}"
    else
        echo -e " ${W}Xray Core:  ${R}INATIVO${NC}"
    fi

    # Verificação de Limiter
    if pgrep -f limit.sh >/dev/null; then
        echo -e " ${W}Limiter:    ${G}ATIVO${NC}"
    else
        echo -e " ${W}Limiter:    ${R}INATIVO${NC}"
    fi

    echo -e ""
    echo -e "${P}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${Y}  Pressione [M] para Voltar | Atualizando em 10s...${NC}"
    echo -e "${P}══════════════════════════════════════════════════════════════${NC}"
    
    # Aguarda 10 segundos ou sai se pressionar 'm'
    read -t 10 -n 1 tecla
    if [[ $tecla == "m" || $tecla == "M" ]]; then
        break
    fi
done
