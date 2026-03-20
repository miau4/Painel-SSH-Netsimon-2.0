#!/bin/bash
CONF="/etc/xray/config.json"

# Status Superior
echo -e "${CYAN}Status Xray:${NC} $(systemctl is-active xray 2>/dev/null | grep -q "active" && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")"
echo -e "${CYAN}Porta VLESS:${NC} $(grep '"port"' $CONF 2>/dev/null | awk '{print $2}' | sed 's/,//g')"
echo -e "------------------------------------------"

echo "1) Instalar/Atualizar Xray Core"
echo "2) Alterar Porta VLESS"
echo "3) Reiniciar Serviço"
read -p "Escolha: " op

case $op in
    1)
        bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
        systemctl enable xray
        ;;
    2)
        read -p "Nova Porta: " nport
        sed -i "s/\"port\": [0-9]*/\"port\": $nport/" "$CONF"
        systemctl restart xray
        echo -e "${GREEN}Porta alterada para $nport!${NC}"
        ;;
    3) systemctl restart xray ;;
esac
