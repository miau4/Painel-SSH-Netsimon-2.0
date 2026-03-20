#!/bin/bash
# NETSIMON ENTERPRISE - PROVISÃO HÍBRIDA (SSH + XRAY)

USERDB="/etc/xray-manager/users.db"
XRAY_CONF="/etc/xray/config.json"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}               👤 CRIAR NOVO USUÁRIO (HÍBRIDO)                ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# 1. Coleta de Dados
read -p " Nome do Usuário: " user
[[ -z "$user" ]] && { echo -e "${R}Erro: Nome obrigatório!${NC}"; sleep 2; exit 1; }

# Verifica se já existe
if id "$user" &>/dev/null || grep -q "^$user|" "$USERDB"; then
    echo -e "${R}Erro: O usuário '$user' já existe no sistema!${NC}"
    read -p "Pressione ENTER..."
    exit 1
fi

read -p " Senha (SSH): " pass
[[ -z "$pass" ]] && pass="1234"

read -p " Dias de Validade (Ex: 30): " dias
[[ -z "$dias" ]] && dias=30

read -p " Limite de Conexões (Ex: 1): " limite
[[ -z "$limite" ]] && limite=1

# 2. Cálculos e IDs
exp_date=$(date -d "+$dias days" +"%Y-%m-%d")
uuid=$(cat /proc/sys/kernel/random/uuid)

echo -e "\n${Y}[+] Criando conta no sistema...${NC}"

# 3. Criar no Linux (SSH)
useradd -M -s /bin/false -p $(openssl passwd -1 "$pass") "$user"

# 4. Injetar no Xray (Se o config.json existir)
if [ -f "$XRAY_CONF" ]; then
    echo -e "${Y}[+] Sincronizando com Xray Core...${NC}"
    # Usa jq para adicionar o cliente ao array de clients do primeiro inbound
    tmp=$(mktemp)
    jq --arg u "$user" --arg id "$uuid" '.inbounds[0].settings.clients += [{"id": $id, "alterId": 0, "email": $u}]' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
    systemctl restart xray
fi

# 5. Salvar no Banco de Dados Central
echo "$user|$uuid|$exp_date|$pass|$limite" >> "$USERDB"

# 6. Relatório de Entrega (O que você manda pro cliente)
clear
echo -e "${G}✅ USUÁRIO CRIADO COM SUCESSO!${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
echo -e "${W}  DADOS SSH / WEBSOCKET${NC}"
echo -e "  Usuário: ${Y}$user${NC}"
echo -e "  Senha:   ${Y}$pass${NC}"
echo -e "  Limite:  ${Y}$limite dispositivo(s)${NC}"
echo -e "${C}--------------------------------------------------------------${NC}"
echo -e "${W}  DADOS VLESS / XRAY${NC}"
echo -e "  UUID:    ${Y}$uuid${NC}"
echo -e "  Path:    ${Y}/${NC}"
echo -e "  Network: ${Y}xhttp / TLS${NC}"
echo -e "${C}--------------------------------------------------------------${NC}"
echo -e "  Validade: ${G}$exp_date ($dias dias)${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"

# Dica de monitoramento
echo -e "${Y}Dica:${NC} O limitador já está rastreando este usuário."
read -p "Pressione ENTER para voltar ao menu..."
