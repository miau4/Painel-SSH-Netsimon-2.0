#!/bin/bash
BASE="/etc/painel"
PY_SCRIPT="$BASE/proxy.py"

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

clear
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}          🌐 WEBSOCKET MANAGER            ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

# Status Superior Independente
WSP=$(netstat -tlpn 2>/dev/null | grep python | awk '{print $4}' | cut -d: -f2 | xargs)
echo -e "Status: $(pgrep -f proxy.py >/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
echo -e "Portas Ativas: ${CYAN}${WSP:-Nenhuma}${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

echo -e "1) Iniciar Novas Portas"
echo -e "2) Parar Tudo"
echo -e "0) Voltar"
read -p "Escolha: " op

case $op in
    1)
        if [ ! -f "$PY_SCRIPT" ]; then
            wget -q -O "$PY_SCRIPT" "https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon/main/proxy.py"
        fi
        read -p "Portas (ex: 80 8080): " ports
        for port in $ports; do
            nohup python3 "$PY_SCRIPT" "$port" >/dev/null 2>&1 &
            echo -e "${GREEN}Porta $port iniciada!${NC}"
        done
        sleep 2 ;;
    2) pkill -f proxy.py; echo -e "${RED}Parado!${NC}"; sleep 2 ;;
    *) exit ;;
esac
