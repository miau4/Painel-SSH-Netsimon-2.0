#!/bin/bash
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
echo -e " Porta Nginx: 80 <-> Interna: 8080"
echo -e "--------------------------------------------"
echo -e " 1) Iniciar WebSocket"
echo -e " 2) Parar WebSocket"
echo -e " 3) Ver Logs (Porta 8080)"
echo -e " 0) Voltar"
echo -ne "\n${Y}Escolha: ${NC}"; read opt

case $opt in
    1)
        if [ ! -f "$PROXY_PY" ]; then
            echo -e "${R}Erro: proxy.py não encontrado!${NC}"
        elif pgrep -f "proxy.py" > /dev/null; then
            echo -e "${Y}WebSocket já está rodando!${NC}"
        else
            echo -ne "${W}Iniciando Proxy na 8080... ${NC}"
            nohup python3 "$PROXY_PY" 8080 > /dev/null 2>&1 &
            sleep 2
            echo -e "${G}[OK]${NC}"
        fi
        ;;
    2)
        pkill -f "proxy.py"
        echo -e "${R}WebSocket Parado!${NC}"
        ;;
    3)
        netstat -anp | grep :8080
        read -p "Pressione ENTER..."
        ;;
    0) exit 0 ;;
esac
sleep 1
/etc/painel/websocket.sh
