#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - WS & SOCKS
# ==========================================

# Cores
P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; B='\033[1;34m'; NC='\033[0m'

DIR="/etc/painel"
PROXY_PY="$DIR/proxy.py"

# Função para detectar o tipo de serviço real por porta
check_proto() {
    local porta=$1
    if ps aux | grep -v grep | grep "proxy.py $porta ws" > /dev/null; then
        echo -e "${G}WEBSOCKET${NC}"
    elif ps aux | grep -v grep | grep "proxy.py $porta sk" > /dev/null; then
        echo -e "${B}SOCKS${NC}"
    else
        echo -e "${R}OFF${NC}"
    fi
}

clear
echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${P}║${W}           🌐  NETSIMON WEBSOCKET & SOCKS MANAGER           ${P}║${NC}"
echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "  ${W}PORTA 80: $(check_proto 80)             ${W}PORTA 8080: $(check_proto 8080)${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
echo -e " ${G}1)${W} Iniciar WebSocket ${C}(Porta 80)${NC}"
echo -e " ${G}2)${W} Iniciar WebSocket ${C}(Porta 8080)${NC}"
echo -e " ${R}3)${W} Parar WebSockets${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
echo -e " ${B}4)${W} Iniciar Socks ${P}(Porta 80)${NC}"
echo -e " ${B}5)${W} Iniciar Socks ${P}(Porta 8080)${NC}"
echo -e " ${R}6)${W} Parar Socks${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
echo -e " ${Y}7)${W} Detalhes das Portas Ativas${NC}"
echo -e " ${W}0)${W} Voltar ao Menu Principal${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
echo -ne "${Y} Selecione uma opção: ${NC}"; read opt

case $opt in
    1)
        pkill -f "proxy.py 80" 2>/dev/null
        nohup python3 "$PROXY_PY" 80 ws > /dev/null 2>&1 &
        echo -e "\n${G}[OK] WebSocket iniciado na porta 80!${NC}"; sleep 2 ;;
    2)
        pkill -f "proxy.py 8080" 2>/dev/null
        nohup python3 "$PROXY_PY" 8080 ws > /dev/null 2>&1 &
        echo -e "\n${G}[OK] WebSocket iniciado na porta 8080!${NC}"; sleep 2 ;;
    3)
        pkill -f "ws" 2>/dev/null
        echo -e "\n${R}[!] Todos os WebSockets foram parados.${NC}"; sleep 2 ;;
    4)
        pkill -f "proxy.py 80" 2>/dev/null
        nohup python3 "$PROXY_PY" 80 sk > /dev/null 2>&1 &
        echo -e "\n${B}[OK] Socks iniciado na porta 80!${NC}"; sleep 2 ;;
    5)
        pkill -f "proxy.py 8080" 2>/dev/null
        nohup python3 "$PROXY_PY" 8080 sk > /dev/null 2>&1 &
        echo -e "\n${B}[OK] Socks iniciado na porta 8080!${NC}"; sleep 2 ;;
    6)
        pkill -f "sk" 2>/dev/null
        echo -e "\n${R}[!] Todos os serviços Socks foram parados.${NC}"; sleep 2 ;;
    7)
        echo -e "\n${P}══════════════ DETALHES DE PROTOCOLOS ══════════════${NC}"
        # Lista os processos Python e identifica o rótulo final (ws ou sk)
        ps aux | grep "proxy.py" | grep -v grep | awk '{print "Porta: " $12 " | Protocolo: " ($13=="ws"?"WEBSOCKET":($13=="sk"?"SOCKS":"DESCONHECIDO")) " | PID: " $2}'
        echo -e "${P}════════════════════════════════════════════════════${NC}"
        read -p "Pressione ENTER para retornar..." ;;
    0) exit 0 ;;
    *) echo -e "\n${R}Opção Inválida!${NC}"; sleep 1 ;;
esac
$DIR/websocket.sh
