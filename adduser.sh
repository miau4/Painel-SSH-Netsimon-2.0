#!/bin/bash

# Caminhos Sincronizados
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
echo -e "${GREEN}          ➕ CRIAR USUÁRIO SSH/VLESS       ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

# ----------------- INPUTS -----------------
read -p "Nome do usuário: " user
[[ -z "$user" ]] && echo -e "${RED}Nome vazio!${NC}" && sleep 2 && exit

# Verifica se já existe
if grep -q "^$user|" "$USERS_DB" || id "$user" &>/dev/null; then
    echo -e "${RED}Usuário já existe!${NC}"
    sleep 2 && exit
fi

read -p "Senha para SSH/SlowDNS: " pass
[[ -z "$pass" ]] && pass="1234"

read -p "Dias de validade: " dias
[[ ! "$dias" =~ ^[0-9]+$ ]] && dias=30

read -p "Limite de IPs: " limit
[[ ! "$limit" =~ ^[0-9]+$ ]] && limit=1

# ----------------- GERAR DADOS -----------------
uuid=$(cat /proc/sys/kernel/random/uuid)
exp_date=$(date -d "+$dias days" +"%Y-%m-%d")

# ----------------- CRIAÇÃO NO SISTEMA (SSH/SLOWDNS) -----------------
# Cria o usuário no Linux sem diretório home e com shell falso por segurança
useradd -M -s /bin/false -e "$exp_date" "$user"
echo "$user:$pass" | chpasswd

# ----------------- SALVAR NO BANCO -----------------
echo "$user|$uuid|$exp_date|$pass|$limit" >> "$USERS_DB"

# ----------------- INSERIR NO XRAY (JQ) -----------------
if [ -f "$CONFIG_XRAY" ]; then
    tmp=$(mktemp)
    # Esta lógica garante que se o array de clients não existir, ele cria um
    jq --arg uuid "$uuid" --arg user "$user" '
        ( .inbounds[0].settings.clients // [] ) as $clients 
        | .inbounds[0].settings.clients = ($clients + [{"id": $uuid, "email": $user}])
    ' "$CONFIG_XRAY" > "$tmp" && mv "$tmp" "$CONFIG_XRAY"
    systemctl restart xray 2>/dev/null
fi

# ----------------- RESULTADO FINAL -----------------
IP=$(curl -s ifconfig.me)
clear
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}           ✅ USUÁRIO CRIADO               ${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}Usuário :${NC} $user"
echo -e "${CYAN}Senha   :${NC} $pass"
echo -e "${CYAN}UUID    :${NC} $uuid"
echo -e "${CYAN}Expira  :${NC} $exp_date"
echo -e "${CYAN}Limite  :${NC} $limit IP(s)"
echo -e "${GREEN}══════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}LINK VLESS-WS:${NC}"
echo "vless://$uuid@$IP:443?path=/ws&security=none&encryption=none&type=ws#$user"

echo -e "\n${YELLOW}DADOS SSH/SLOWDNS:${NC}"
echo "IP: $IP | Porta: 22, 80 | User: $user | Senha: $pass"
echo -e "${GREEN}══════════════════════════════════════════${NC}"

read -n1 -r -p "Pressione qualquer tecla para voltar..."
