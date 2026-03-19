#!/bin/bash

# Caminhos (Mantendo o padrão do adduser.sh)
USERS_DB="/etc/xray-manager/users.db"
CONFIG_XRAY="/etc/xray/config.json"

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ----------------- VALIDAÇÃO INICIAL -----------------
if [ ! -f "$USERS_DB" ] || [ ! -s "$USERS_DB" ]; then
    clear
    echo -e "${RED}Nenhum usuário cadastrado no banco de dados.${NC}"
    read -p "Pressione ENTER para voltar..."
    exit 1
fi

clear
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${RED}         ❌ REMOVER USUÁRIO (SSH/XRAY)     ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

# ----------------- LISTAGEM -----------------
# Carrega os nomes dos usuários em um array
mapfile -t lista < <(cut -d'|' -f1 "$USERS_DB")

echo -e "${YELLOW}Selecione o usuário para remover:${NC}\n"
for i in "${!lista[@]}"; do
    printf "${CYAN}%02d)${NC} %s\n" "$((i+1))" "${lista[$i]}"
done
echo -e "${CYAN}00)${NC} Sair"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
read -p "Escolha o número: " num

# Validação da escolha
[[ "$num" == "0" || "$num" == "00" ]] && exit
if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#lista[@]}" ]; then
    echo -e "${RED}Opção inválida!${NC}"
    sleep 2
    exit 1
fi

# Pega os dados do usuário selecionado
user="${lista[$((num-1))]}"
linha_db=$(grep "^$user|" "$USERS_DB")
uuid=$(echo "$linha_db" | cut -d'|' -f2)

# ----------------- CONFIRMAÇÃO -----------------
echo -e "\n${YELLOW}Tem certeza que deseja remover o usuário: ${RED}$user${NC}?"
read -p "Confirmar? (s/n): " confirm
[[ "$confirm" != "s" && "$confirm" != "S" ]] && exit

# ----------------- EXECUÇÃO DA REMOÇÃO -----------------

echo -e "\n${YELLOW}Limpando sistema...${NC}"

# 1. Matar processos e remover do Linux (SSH/SlowDNS)
if id "$user" &>/dev/null; then
    pkill -u "$user" &>/dev/null
    userdel -f "$user" &>/dev/null
    echo -e "- Usuário SSH/Linux removido."
fi

# 2. Remover do Xray (JSON)
if [ -f "$CONFIG_XRAY" ] && command -v jq >/dev/null; then
    tmp=$(mktemp)
    jq --arg uuid "$uuid" '
        if .inbounds[0].settings.clients then
            .inbounds[0].settings.clients |= map(select(.id != $uuid))
        else
            .
        end
    ' "$CONFIG_XRAY" > "$tmp" && mv "$tmp" "$CONFIG_XRAY"
    
    systemctl restart xray 2>/dev/null
    echo -e "- Usuário removido do Xray."
else
    echo -e "- Xray não encontrado, pulando etapa de JSON."
fi

# 3. Remover do Banco de Dados Interno
tmp_db=$(mktemp)
grep -v "^$user|" "$USERS_DB" > "$tmp_db" && mv "$tmp_db" "$USERS_DB"
echo -e "- Registro removido do banco de dados."

# ----------------- FINALIZAÇÃO -----------------
clear
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}       ✅ REMOÇÃO CONCLUÍDA COM SUCESSO!  ${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "Usuário: $user"
echo -e "Status: Totalmente limpo do servidor."
echo -e "${GREEN}══════════════════════════════════════════${NC}"

read -n1 -r -p "Pressione qualquer tecla para voltar..."
