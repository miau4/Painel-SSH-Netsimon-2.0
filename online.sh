#!/bin/bash

USERS="/etc/xray-manager/users.xray"

GREEN='\033[1;32m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${CYAN}══════════════════════════════${NC}"
echo -e "${GREEN}   👥 USUÁRIOS ONLINE (REAL)${NC}"
echo -e "${CYAN}══════════════════════════════${NC}"
echo ""

# -------------------------------
# VERIFICA XRAY
# -------------------------------
if ! command -v xray >/dev/null 2>&1; then
    echo -e "${RED}Xray não instalado!${NC}"
    exit
fi

# -------------------------------
# VERIFICA API
# -------------------------------
if ! xray api statsquery --pattern "user>>>" >/dev/null 2>&1; then
    echo -e "${RED}API do Xray não está ativa!${NC}"
    echo "Ative no config.json para monitoramento real."
    exit
fi

TOTAL=0

# -------------------------------
# LISTAR ONLINE
# -------------------------------
xray api statsquery --pattern "user>>>" 2>/dev/null | while read -r line; do

    user=$(echo "$line" | sed -n 's/.*>>>\\(.*\\)>>>.*/\\1/p')
    value=$(echo "$line" | grep -o '[0-9]*$')

    [[ -z "$value" || "$value" -le 0 ]] && continue

    # valida se usuário existe no banco
    if grep -q "^$user|" "$USERS" 2>/dev/null; then
        echo -e "${GREEN}$user${NC} - ONLINE (${value} conexões)"
    else
        echo -e "${RED}$user${NC} - (não registrado)"
    fi

    TOTAL=$((TOTAL + value))

done

echo ""
echo -e "${CYAN}Total de conexões:${NC} $TOTAL"
echo ""
