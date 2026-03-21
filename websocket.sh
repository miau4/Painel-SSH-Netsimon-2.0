#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - WEBSOCKET MANAGER
# ==========================================

C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'
DIR="/etc/painel"
PROXY_PY="$DIR/proxy.py"

if [ ! -d "$DIR" ]; then mkdir -p "$DIR"; fi

check_status() {
    pgrep -f "proxy.py" > /dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}"
}

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                 🌐 WEBSOCKET SSH MANAGER                     ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e " Status Atual: $(check_status)"
echo -e " Portas Disponíveis: 80, 8080, 8880"
echo -e "--------------------------------------------"
echo -e " 1) Iniciar WebSocket (Porta 80)"
echo -e " 2) Iniciar WebSocket (Porta 8080)"
echo -e " 3) Parar WebSocket"
echo -e " 4) Ver Logs/Portas Ativas"
echo -e " 0) Voltar"
echo -ne "\n${Y}Escolha: ${NC}"; read opt

case $opt in
    1)
        pkill -f "proxy.py"
        nohup python3 "$PROXY_PY" 80 > /dev/null 2>&1 &
        echo -e "${G}Iniciado na porta 80!${NC}"
        sleep 2
        ;;
    2)
        pkill -f "proxy.py"
        nohup python3 "$PROXY_PY" 8080 > /dev/null 2>&1 &
        echo -e "${G}Iniciado na porta 8080!${NC}"
        sleep 2
        ;;
    3)
        pkill -f "proxy.py"
        echo -e "${R}WebSocket Parado!${NC}"
        sleep 2
        ;;
    4)
        netstat -tunlp | grep python
        read -p "Pressione ENTER..."
        ;;
    0) exit 0 ;;
esac
/etc/painel/websocket.sh
