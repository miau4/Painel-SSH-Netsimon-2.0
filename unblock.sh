#!/bin/bash

# Caminhos Sincronizados
USERS_DB="/etc/xray-manager/users.db"
BLOCKED_DB="/etc/xray-manager/blocked.db"
XRAY_CONF="/etc/xray/config.json"

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}          🔓 DESBLOQUEAR USUÁRIO           ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

# Verifica se há bloqueados
if [ ! -f "$BLOCKED_DB" ] || [ ! -s "$BLOCKED_DB" ]; then
    echo -e "${YELLOW}Não há usuários bloqueados no momento.${NC}"
    exit 0
fi

# Listagem de bloqueados
mapfile -t bloqueados < <(cut -d'|' -f1 "$BLOCKED_DB")

echo -e "Selecione o usuário para desbloquear:\n"
for i in "${!bloqueados[@]}"; do
    printf "${CYAN}%02d)${NC} %s\n" "$((i+1))" "${bloqueados[$i]}"
done
echo -e "${CYAN}00)${NC} Voltar"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
read -p "Escolha: " op

[[ "$op" == "0" || "$op" == "00" ]] && exit

user="${bloqueados[$((op-1))]}"

if [[ -z "$user" ]]; then
    echo -e "${RED}Opção inválida!${NC}"
    sleep 2 ; exit
fi

# --- PROCESSO DE DESBLOQUEIO ---

echo -e "\n${YELLOW}Restaurando acessos para: $user...${NC}"

# 1. Desbloquear no Linux (SSH/SlowDNS)
if id "$user" &>/dev/null; then
    passwd -u "$user" &>/dev/null
    echo -e "${GREEN}[OK]${NC} Acesso SSH/Linux restaurado."
fi

# 2. Restaurar no Xray (JSON)
# Precisamos pegar o UUID original no users.db
uuid_orig=$(grep "^$user|" "$USERS_DB" | cut -d'|' -f2)

if [ -n "$uuid_orig" ] && [ -f "$XRAY_CONF" ]; then
    tmp=$(mktemp)
    # Adiciona novamente ao JSON
    jq --arg uuid "$uuid_orig" --arg email "$user" \
    '.inbounds[0].settings.clients += [{"id": $uuid, "email": $email}]' \
    "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
    
    systemctl restart xray 2>/dev/null
    echo -e "${GREEN}[OK]${NC} Acesso Xray restaurado."
fi

# 3. Remover da lista de bloqueados
sed -i "/^$user|/d" "$BLOCKED_DB"

echo -e "\n${GREEN}Usuário $user está livre para conectar novamente!${NC}"
read -p "Pressione ENTER..."
