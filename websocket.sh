#!/bin/bash
BASE="/etc/painel"
PY_SCRIPT="/etc/painel/proxy.py"

# Status Superior
echo -e "${CYAN}Status WebSocket:${NC} $(pgrep -f proxy.py >/dev/null && echo -e "${GREEN}ATIVO${NC}" || echo -e "${RED}OFF${NC}")"
echo -e "${CYAN}Portas em uso:${NC} $(netstat -tlpn | grep python | awk '{print $4}' | cut -d: -f2 | xargs)"
echo -e "------------------------------------------"

echo -e "1) Iniciar WebSocket (Portas)"
echo -e "2) Parar WebSocket"
read -p "Escolha: " op

if [[ "$op" == "1" ]]; then
    read -p "Digite as portas (ex: 80 8080 8880): " ports
    
    # Baixa o script proxy se não existir
    if [ ! -f "$PY_SCRIPT" ]; then
        wget -q -O "$PY_SCRIPT" "https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon/main/proxy.py"
    fi

    for port in $ports; do
        nohup python3 "$PY_SCRIPT" "$port" >/dev/null 2>&1 &
        echo -e "${GREEN}Porta $port iniciada!${NC}"
    done
    sleep 2
elif [[ "$op" == "2" ]]; then
    pkill -f proxy.py
    echo -e "${RED}Serviços parados.${NC}"
    sleep 2
fi
