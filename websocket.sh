#!/bin/bash
BASE="/etc/painel"
PY_SCRIPT="$BASE/proxy.py"
PORT_FILE="/tmp/ws_ports.txt"

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

clear
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}          🌐 WEBSOCKET MANAGER            ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

# Status Superior
STATUS=$(pgrep -f proxy.py >/dev/null && echo -e "${GREEN}ATIVO${NC}" || echo -e "${RED}OFF${NC}")
PORTAS=$(netstat -tlpn | grep python | awk '{print $4}' | cut -d: -f2 | xargs || echo "Nenhuma")

echo -e "Status: $STATUS"
echo -e "Portas Ativas: ${CYAN}$PORTAS${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

echo -e "1) Adicionar/Iniciar Portas"
echo -e "2) Parar Todos os WebSockets"
echo -e "0) Voltar"
echo -ne "\nEscolha: "
read op

case $op in
    1)
        # Verifica se o script python existe
        if [ ! -f "$PY_SCRIPT" ]; then
            echo -e "${YELLOW}Baixando dependência proxy.py...${NC}"
            wget -q -O "$PY_SCRIPT" "https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon/main/proxy.py"
        fi

        read -p "Digite as portas separadas por espaço (ex: 80 8080 8880): " ports
        for port in $ports; do
            if netstat -tlpn | grep -q ":$port "; then
                echo -e "${RED}Porta $port já está em uso!${NC}"
            else
                nohup python3 "$PY_SCRIPT" "$port" >/dev/null 2>&1 &
                echo -e "${GREEN}Porta $port iniciada com sucesso!${NC}"
            fi
        done
        sleep 2
        ;;
    2)
        pkill -f proxy.py
        echo -e "${RED}Todos os serviços WebSocket foram parados.${NC}"
        sleep 2
        ;;
    0) exit ;;
esac
