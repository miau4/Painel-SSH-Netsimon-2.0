#!/bin/bash

USERDB="/etc/xray-manager/users.db"
XRAY_CONF="/etc/xray/config.json"

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}              🚀 CRIAR TESTE TEMPORÁRIO                      ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

# Dependência para agendamento
if ! command -v at &> /dev/null; then
    apt install at -y &>/dev/null
    systemctl enable --now atd &>/dev/null
fi

# 1. Gerar Dados Aleatórios ou Manual
read -p "Nome do usuário teste (Deixe vazio para aleatório): " user
if [[ -z "$user" ]]; then
    user="teste$(shuf -i 1000-9999 -n 1)"
fi

read -p "Senha do teste (Padrão 123): " pass
[[ -z "$pass" ]] && pass="123"

read -p "Duração do teste em MINUTOS (Padrão 60): " duration
[[ -z "$duration" ]] && duration=60

limit=1 # Teste geralmente é apenas 1 conexão

# 2. Criar no Sistema (SSH)
if id "$user" &>/dev/null; then
    echo -e "${RED}Erro: Usuário $user já existe!${NC}"
    exit 1
fi

useradd -M -s /bin/false -p $(openssl passwd -1 "$pass") "$user"

# 3. Adicionar ao Xray (se estiver instalado)
if [ -f "$XRAY_CONF" ]; then
    uuid=$(cat /proc/sys/kernel/random/uuid)
    tmp=$(mktemp)
    jq --arg u "$user" --arg id "$uuid" '.inbounds[0].settings.clients += [{"id": $id, "alterId": 0, "email": $u}]' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
    systemctl restart xray
fi

# 4. Salvar no Banco de Dados com marcação de expiração
exp_date=$(date -d "+$duration minutes" +"%Y-%m-%d %H:%M")
echo "$user|$uuid|$exp_date|$pass|$limit" >> "$USERDB"

# 5. AGENDAR REMOÇÃO AUTOMÁTICA (O Pulo do Gato)
# Cria um comando para deletar o usuário após o tempo X
echo "pkill -u $user; userdel -f $user; sed -i '/^$user|/d' $USERDB; if [ -f $XRAY_CONF ]; then tmp=\$(mktemp); jq --arg u '$user' '.inbounds[0].settings.clients |= map(select(.email != \$u))' $XRAY_CONF > \$tmp && mv \$tmp $XRAY_CONF; systemctl restart xray; fi" | at now + $duration minutes &>/dev/null

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ TESTE CRIADO COM SUCESSO!${NC}"
echo -e "${WHITE}Usuário: ${YELLOW}$user${NC}"
echo -e "${WHITE}Senha:   ${YELLOW}$pass${NC}"
echo -e "${WHITE}Duração: ${YELLOW}$duration minutos${NC}"
echo -e "${WHITE}Expira em: ${YELLOW}$exp_date${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
read -p "Pressione ENTER para voltar..."
