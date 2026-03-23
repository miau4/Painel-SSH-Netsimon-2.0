#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - CRIAR USUÁRIO 2.0
# ==========================================

BASE="/etc/painel"; USERDB="/etc/painel/usuarios.db"; XRAY_CONF="/usr/local/etc/xray/config.json"
P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; C='\033[1;36m'; NC='\033[0m'

[[ ! -f "$USERDB" ]] && touch "$USERDB"

clear
echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${P}║${W}                 🚀 CRIAR NOVO USUÁRIO PRO                     ${P}║${NC}"
echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"

read -p " Nome do Usuário: " user
[[ -z "$user" ]] && exit 1
if grep -qw "$user" "$USERDB" || id "$user" &>/dev/null; then 
    echo -e "\n${R}Erro: Usuário já existe!${NC}"; sleep 2; exit 1; 
fi

read -p " Senha (SSH/Proxy): " pass
[[ -z "$pass" ]] && pass="1234"
read -p " Dias de Validade: " dias
[[ -z "$dias" ]] && dias=30
read -p " Limite de Conexões: " limite
[[ -z "$limite" ]] && limite=1

# Sistema e Expiração Linux
useradd -M -s /bin/false "$user" &>/dev/null
echo "$user:$pass" | chpasswd &>/dev/null
exp=$(date -d "+$dias days" +"%Y-%m-%d")
chage -E "$exp" "$user"

# Gerar UUID e Injetar no Xray (PULO DO GATO: SELECT PORT 443)
uuid=$(cat /proc/sys/kernel/random/uuid)
if [ -f "$XRAY_CONF" ]; then
    tmp=$(mktemp)
    jq --arg u "$user" --arg id "$uuid" '(.inbounds[] | select(.port == 443)).settings.clients += [{"id": $id, "email": $u}]' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
    systemctl restart xray > /dev/null 2>&1
fi

# Salvar no Banco
echo "$user|$uuid|$exp|$pass|$limite" >> "$USERDB"

clear
echo -e "${G}✅ USUÁRIO CRIADO COM SUCESSO!${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
printf "${W} Usuário : ${Y}%-20s ${W} Senha  : ${Y}%-10s${NC}\n" "$user" "$pass"
printf "${W} Validade: ${Y}%-20s ${W} Limite : ${Y}%-10s${NC}\n" "$exp" "$limite"
echo -e "${W} UUID    : ${C}$uuid${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
read -p "Pressione ENTER para voltar..."
