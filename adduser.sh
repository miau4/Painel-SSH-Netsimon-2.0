#!/bin/bash

USERS="/etc/xray-manager/users.xray"
CONFIG="/etc/xray/config.json"

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

clear
echo -e "${CYAN}══════════════════════════════${NC}"
echo -e "${GREEN}     ➕ CRIAR USUÁRIO PRO${NC}"
echo -e "${CYAN}══════════════════════════════${NC}"

# ----------------- BASE -----------------
mkdir -p /etc/xray-manager
[ ! -f "$USERS" ] && touch "$USERS"

# ----------------- INPUT -----------------
read -p "Nome do usuário: " user

if [[ -z "$user" || "$user" =~ [^a-zA-Z0-9_] ]]; then
    echo -e "${RED}Nome inválido!${NC}"
    sleep 2
    exit
fi

if grep -q "^$user|" "$USERS"; then
    echo -e "${RED}Usuário já existe!${NC}"
    sleep 2
    exit
fi

read -p "Senha (apenas informativo): " pass
[ -z "$pass" ] && pass="none"

read -p "Dias de validade: " dias
[[ ! "$dias" =~ ^[0-9]+$ ]] && echo "Valor inválido!" && sleep 2 && exit

read -p "Limite de IPs: " limit
[[ ! "$limit" =~ ^[0-9]+$ ]] && limit=1

# ----------------- GERAR -----------------
uuid=$(cat /proc/sys/kernel/random/uuid)
exp_date=$(date -d "+$dias days" +"%Y-%m-%d")

# ----------------- CONFIRMAÇÃO -----------------
clear
echo "════════ CONFIRMAÇÃO ════════"
echo "Usuário : $user"
echo "UUID    : $uuid"
echo "Validade: $exp_date"
echo "Limite  : $limit IP(s)"
echo "═════════════════════════════"
read -p "Confirmar? (s/n): " confirm

[[ "$confirm" != "s" && "$confirm" != "S" ]] && exit

# ----------------- SALVAR DB -----------------
echo "$user|$uuid|$exp_date|$pass|$limit" >> "$USERS"

# ----------------- XRAY -----------------
if [ ! -f "$CONFIG" ]; then
    echo -e "${RED}config.json não encontrado!${NC}"
    exit
fi

if ! command -v jq >/dev/null; then
    echo -e "${RED}jq não instalado!${NC}"
    exit
fi

tmp=$(mktemp)

jq --arg uuid "$uuid" --arg user "$user" '

.inbounds[0].settings.clients =
(
    .inbounds[0].settings.clients // []
) + [
    {
        "id": $uuid,
        "email": $user
    }
]

' "$CONFIG" > "$tmp"

if [ $? -ne 0 ] || [ ! -s "$tmp" ]; then
    echo -e "${RED}Erro ao atualizar config.json${NC}"
    rm -f "$tmp"
    exit
fi

mv "$tmp" "$CONFIG"

systemctl restart xray 2>/dev/null

# ----------------- RESULTADO -----------------
clear
echo -e "${GREEN}══════════════════════════════${NC}"
echo -e "${GREEN}     ✅ USUÁRIO CRIADO${NC}"
echo -e "${GREEN}══════════════════════════════${NC}"

echo "Usuário : $user"
echo "UUID    : $uuid"
echo "Expira  : $exp_date"
echo "Limite  : $limit IP(s)"

echo ""
echo -e "${CYAN}LINK (exemplo):${NC}"
echo "vless://$uuid@SEU_IP:443?type=ws&path=/ws#${user}"

echo ""

read -n1 -r -p "Pressione qualquer tecla..."
