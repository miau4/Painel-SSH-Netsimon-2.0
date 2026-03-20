cat << 'EOF' > /etc/painel/websocket.sh
#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - WEBSOCKET MANAGER
# ==========================================

C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'
PID_FILE="/tmp/proxy.pid"

check_status() {
    pgrep -f "proxy.py" > /dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}"
}

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                🌐 WEBSOCKET SSH MANAGER                      ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e " Status Atual: $(check_status)"
echo -e " Porta Padrão: 80 (HTTP)"
echo -e "--------------------------------------------"
echo -e " 1) Iniciar WebSocket (Porta 80)"
echo -e " 2) Parar WebSocket"
echo -e " 3) Ver Logs de Conexão"
echo -e " 0) Voltar"
echo -ne "\n${Y}Escolha: ${NC}"; read opt

case $opt in
    1)
        if pgrep -f "proxy.py" > /dev/null; then
            echo -e "${Y}WebSocket já está rodando!${NC}"
        else
            echo -ne "${W}Iniciando Proxy... ${NC}"
            nohup python /etc/painel/proxy.py > /dev/null 2>&1 &
            sleep 2
            echo -e "${G}[OK]${NC}"
        fi
        ;;
    2)
        pkill -f "proxy.py"
        echo -e "${R}WebSocket Parado!${NC}"
        ;;
    3)
        echo -e "${Y}Monitorando tráfego na porta 80... (Ctrl+C para sair)${NC}"
        netstat -anp | grep :80
        read -p "Pressione ENTER..."
        ;;
    *) exit 0 ;;
esac
sleep 1
EOF
chmod +x /etc/painel/websocket.sh
