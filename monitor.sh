#!/bin/bash
# NETSIMON ENTERPRISE - MONITOR DE RECURSOS

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

# Função para pegar carga da CPU
cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}'
}

# Função para pegar RAM
ram_usage() {
    free -h | awk '/Mem:/ {print $3 "/" $2}'
}

# Função para conexões SSH
ssh_conn() {
    ss -tnp | grep ":22" | grep "ESTAB" | wc -l
}

# Função para conexões Xray
xray_conn() {
    ss -tnp | grep -E ":443|:80" | grep "xray" | wc -l 2>/dev/null || echo "0"
}

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}            📊 MONITOR DE RECURSOS (REAL-TIME)               ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e ""
echo -e " ${W}SERVIDOR IP:${NC}  $(curl -s --connect-timeout 2 ifconfig.me || echo "Offline")"
echo -e " ${W}UPTIME:     ${NC}  $(uptime -p)"
echo -e ""
echo -e " ${C}RECURSOS DO SISTEMA:${NC}"
echo -e " ${W}CPU Uso:    ${G}$(cpu_usage)%${NC}"
echo -e " ${W}RAM Uso:    ${G}$(ram_usage)${NC}"
echo -e ""
echo -e " ${C}CONEXÕES ATIVAS:${NC}"
echo -e " ${W}SSH / WS:   ${Y}$(ssh_conn) usuários online${NC}"
echo -e " ${W}Xray Core:  ${Y}$(xray_conn) conexões${NC}"
echo -e ""
echo -e " ${C}SERVIÇOS:${NC}"
echo -ne " ${W}Xray Core:  ${NC}"; pgrep xray >/dev/null && echo -e "${G}ATIVO${NC}" || echo -e "${R}INATIVO${NC}"
echo -ne " ${W}Limiter:    ${NC}"; pgrep -f limit.sh >/dev/null && echo -e "${G}ATIVO${NC}" || echo -e "${R}INATIVO${NC}"
echo -e ""
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
echo -e "${Y}  Dica: Use CTRL+C para sair deste monitor.${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
