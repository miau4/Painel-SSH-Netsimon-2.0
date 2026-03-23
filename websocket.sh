#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - WS & SOCKS 2.0
# ==========================================

# Cores
P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; B='\033[1;34m'; NC='\033[0m'

DIR="/etc/painel"
PROXY_PY="$DIR/proxy.py"

# Função Definitiva: Identifica o serviço real
check_proto() {
    local porta=$1
    # Pega o PID que está escutando a porta
    local pid=$(lsof -t -i :$porta -sTCP:LISTEN 2>/dev/null)
    
    if [[ -z "$pid" ]]; then
        echo -e "${R}OFF${NC}"
    else
        # Pega a linha de comando completa do processo
        local cmd=$(ps -fp $pid -o args= 2>/dev/null)
        
        # 1ª Tentativa: Procura por 'ws' ou 'ws' no comando
        if [[ "$cmd" == *" ws"* ]] || [[ "$cmd" == *"ws"* ]]; then
            echo -e "${G}WEBSOCKET${NC}"
        # 2ª Tentativa: Procura por 'sk' ou 'socks' no comando
        elif [[ "$cmd" == *" sk"* ]] || [[ "$cmd" == *"sk"* ]]; then
            echo -e "${B}SOCKS${NC}"
        # 3ª Tentativa: Se for o proxy.py na porta 80, por padrão é WEBSOCKET no seu sistema
        elif [[ "$cmd" == *"proxy.py"* ]] && [[ "$porta" == "80" ]]; then
            echo -e "${G}WEBSOCKET${NC}"
        # 4ª Tentativa: Se for o proxy.py na 8080, geralmente é SOCKS ou WS (Damos o benefício da dúvida)
        elif [[ "$cmd" == *"proxy.py"* ]]; then
            echo -e "${G}WEBSOCKET${NC}"
        else
            echo -e "${Y}DESCONHECIDO${NC}"
        fi
    fi
}

# Função para matar o processo da porta antes de iniciar outro
stop_port() {
    local porta=$1
    local pid=$(lsof -t -i :$porta -sTCP:LISTEN 2>/dev/null)
    if [[ ! -z "$pid" ]]; then
        kill -9 $pid > /dev/null 2>&1
        sleep 1
        return 0
    fi
    return 1
}

while true; do
clear
echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${P}║${W}            🌐  NETSIMON WEBSOCKET & SOCKS MANAGER            ${P}║${NC}"
echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"
# Exibição dos status formatada
printf "  ${W}PORTA 80: %-25b ${W}PORTA 8080: %-20b${NC}\n" "$(check_proto 80)" "$(check_proto 8080)"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
echo -e " ${G}1)${NC} Iniciar WebSocket ${C}(Porta 80)${NC}"
echo -e " ${G}2)${NC} Iniciar WebSocket ${C}(Porta 8080)${NC}"
echo -e " ${R}3)${NC} Parar Serviços Porta 80${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
echo -e " ${B}4)${NC} Iniciar Socks ${P}(Porta 80)${NC}"
echo -e " ${B}5)${NC} Iniciar Socks ${P}(Porta 8080)${NC}"
echo -e " ${R}6)${NC} Parar Serviços Porta 8080${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
echo -e " ${Y}7)${NC} Detalhes das Portas Ativas${NC}"
echo -e " ${W}0)${NC} Voltar ao Menu Principal${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
echo -ne "${Y} Selecione uma opção: ${NC}"; read opt

case $opt in
    1)
        stop_port 80
        screen -dmS ws80 python3 "$PROXY_PY" 80 ws
        echo -e "\n${G}[OK] WebSocket iniciado na porta 80!${NC}"; sleep 2 ;;
    2)
        stop_port 8080
        screen -dmS ws8080 python3 "$PROXY_PY" 8080 ws
        echo -e "\n${G}[OK] WebSocket iniciado na porta 8080!${NC}"; sleep 2 ;;
    3)
        if stop_port 80; then
            echo -e "\n${G}[!] Serviços na porta 80 encerrados.${NC}"
        else
            echo -e "\n${R}[!] Nenhuma atividade na porta 80.${NC}"
        fi
        sleep 2 ;;
    4)
        stop_port 80
        screen -dmS sk80 python3 "$PROXY_PY" 80 sk
        echo -e "\n${B}[OK] Socks iniciado na porta 80!${NC}"; sleep 2 ;;
    5)
        stop_port 8080
        screen -dmS sk8080 python3 "$PROXY_PY" 8080 sk
        echo -e "\n${B}[OK] Socks iniciado na porta 8080!${NC}"; sleep 2 ;;
    6)
        if stop_port 8080; then
            echo -e "\n${G}[!] Serviços na porta 8080 encerrados.${NC}"
        else
            echo -e "\n${R}[!] Nenhuma atividade na porta 8080.${NC}"
        fi
        sleep 2 ;;
    7)
        clear
        echo -e "${P}📋 RELATÓRIO DE PORTAS (LISTEN):${NC}"
        lsof -i :80,8080 -sTCP:LISTEN
        echo ""
        read -p "Pressione ENTER para retornar..." ;;
    0) break ;;
    *) echo -e "\n${R}Opção Inválida!${NC}"; sleep 1 ;;
esac
done
