#!/bin/bash

# Caminhos
USERS_DB="/etc/xray-manager/users.db"
CONFIG_XRAY="/etc/xray/config.json"

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}        ➕ CRIAR USUÁRIO HÍBRIDO (SSH/XRAY) ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

# Preparação
mkdir -p /etc/xray-manager
[ ! -f "$USERS_DB" ] && touch "$USERS_DB"

# --- INPUTS ---
read -p "Nome do usuário: " user
if [[ -z "$user" || "$user" =~ [^a-zA-Z0-9] ]]; then
    echo -e "${RED}Nome inválido! Use apenas letras e números.${NC}"
    exit 1
fi

if id "$user" &>/dev/null || grep -q "^$user|" "$USERS_DB"; then
    echo -e "${RED}Erro: Usuário já existe no sistema ou no banco!${NC}"
    exit 1
fi

read -p "Senha para SSH/Acesso: " pass
[[ -z "$pass" ]] && pass="1234"

read -p "Dias de validade: " dias
[[ ! "$dias" =~ ^[0-9]+$ ]] && dias=30

read -p "Limite de conexões (IPs): " limit
[[ ! "$limit" =~ ^[0-9]+$ ]] && limit=1

# --- PROCESSAMENTO ---
uuid=$(cat /proc/sys/kernel/random/uuid)
exp_date=$(date -d "+$dias days" +"%Y-%m-%d")
exp_linux=$(date -d "+$dias days" +"%Y-%m-%d")

# 1. Criar usuário no Sistema (SSH/SlowDNS)
useradd -M -s /bin/false -e "$exp_linux" "$user"
echo "$user:$pass" | chpasswd

# 2. Adicionar ao Xray (se o config existir)
if [ -f "$CONFIG_XRAY" ] && command -v jq >/dev/null; then
    tmp=$(mktemp)
    jq --arg uuid "$uuid" --arg user "$user" \
    '.inbounds[0].settings.clients += [{"id": $uuid, "email": $user}]' \
    "$CONFIG_XRAY" > "$tmp" && mv "$tmp" "$CONFIG_XRAY"
    systemctl restart xray 2>/dev/null
    XRAY_STATUS="${GREEN}ATIVO${NC}"
else
    XRAY_STATUS="${RED}NÃO CONFIGURADO${NC}"
fi

# 3. Salvar no Banco Interno
echo "$user|$uuid|$exp_date|$pass|$limit" >> "$USERS_DB"

# --- RESULTADO E LINKS ---
IP=$(curl -s ifconfig.me)
# Tenta pegar porta e path do Xray, senão usa padrão
PORT_XRAY=$(jq -r '.inbounds[0].port' $CONFIG_XRAY 2>/dev/null || echo "443")
PATH_XRAY=$(jq -r '.inbounds[0].streamSettings.wsSettings.path' $CONFIG_XRAY 2>/dev/null || echo "/ws")

clear
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}       ✅ USUÁRIO CRIADO COM SUCESSO!     ${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}USUÁRIO:${NC}  $user"
echo -e "${CYAN}SENHA:${NC}    $pass"
echo -e "${CYAN}VALIDADE:${NC} $exp_date ($dias dias)"
echo -e "${CYAN}LIMITE:${NC}   $limit IP(s)"
echo -e "${CYAN}XRAY VLESS:${NC} $XRAY_STATUS"
echo -e "${GREEN}══════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}--- CONFIGURAÇÕES VPN ---${NC}"
echo -e "${CYAN}SSH/
