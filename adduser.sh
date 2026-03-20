#!/bin/bash
# NETSIMON ENTERPRISE - CRIAR USUÁRIO PRO
BASE="/etc/painel"
USERDB="/etc/xray-manager/users.db"
XRAY_CONF="/etc/xray/config.json"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}               🚀 CRIAR USUÁRIO                      ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

read -p " Nome do Usuário: " user
[[ -z "$user" ]] && exit 1
if id "$user" &>/dev/null; then echo -e "${R}Usuário já existe!${NC}"; sleep 2; exit 1; fi

read -p " Senha (SSH/Proxy): " pass
[[ -z "$pass" ]] && pass="1234"

read -p " Dias de Validade: " dias
[[ -z "$dias" ]] && dias=30

read -p " Limite de Conexões: " limite
[[ -z "$limite" ]] && limite=1

# Configuração no Sistema (Linux)
useradd -M -s /bin/false "$user"
echo "$user:$pass" | chpasswd

# Configuração no Xray (UUID)
uuid=$(cat /proc/sys/kernel/random/uuid)
if [ -f "$XRAY_CONF" ]; then
    tmp=$(mktemp)
    jq --arg u "$user" --arg id "$uuid" '.inbounds[0].settings.clients += [{"id": $id, "alterId": 0, "email": $u}]' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
    systemctl restart xray
fi

# Salvar no Banco
exp=$(date -d "+$dias days" +"%Y-%m-%d")
echo "$user|$uuid|$exp|$pass|$limite" >> "$USERDB"

clear
echo -e "${G}✅ USUÁRIO CRIADO COM SUCESSO!${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
echo -e "${W} Usuário : ${Y}$user${NC}"
echo -e "${W} Senha   : ${Y}$pass${NC}"
echo -e "${W} UUID    : ${Y}$uuid${NC}"
echo -e "${W} Expira  : ${Y}$exp${NC}"
echo -e "${W} Limite  : ${Y}$limite IP(s)${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
read -p "Pressione ENTER para voltar..."
