#!/bin/bash
BASE="/etc/painel"
PY_SCRIPT="$BASE/proxy.py"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}               🌐 WEBSOCKET MANAGER (PYTHON)                  ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# Verifica se o Python está rodando e em qual porta
PID=$(pgrep -f "python3 $PY_SCRIPT")
if [ -n "$PID" ]; then
    PORTA=$(netstat -tlpn | grep "$PID" | awk '{print $4}' | cut -d: -f2 | head -n1)
    echo -e "Status: ${G}ON${NC} | Porta Ativa: ${Y}${PORTA:-N/A}${NC}"
else
    echo -e "Status: ${R}OFF${NC}"
fi

echo -e "\n1) Iniciar WebSocket"
echo -e "2) Parar WebSocket"
echo -e "0) Voltar"
echo -ne "\nEscolha: "
read op

case $op in
    1)
        read -p "Digite a porta (Ex: 80 ou 8080): " port
        [[ -z "$port" ]] && port=80
        nohup python3 "$PY_SCRIPT" "$port" > /dev/null 2>&1 &
        echo -e "${G}WebSocket iniciado na porta $port!${NC}"
        sleep 2
        ;;
    2)
        pkill -f "python3 $PY_SCRIPT"
        echo -e "${R}WebSocket parado.${NC}"
        sleep 2
        ;;
    0) exit 0 ;;
esac
