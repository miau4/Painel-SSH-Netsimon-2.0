#!/bin/bash
# NETSIMON ENTERPRISE - EXTERMINADOR DE CONTAS (PROVISÃO REVERSA)

BASE="/etc/painel"
USERDB="/etc/xray-manager/users.db"
XRAY_CONF="/etc/xray/config.json"
LOG_LIMIT="/var/log/netsimon_limit.log"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

# ---------------------------------------------------------
# LÓGICA DE EXCLUSÃO AUTOMÁTICA (Para o addtest.sh)
# ---------------------------------------------------------
if [[ "$2" == "--auto" ]]; then
    user="$1"
    # 1. Derrubar sessões
    pkill -u "$user" -f sshd &>/dev/null
    userdel -f "$user" &>/dev/null
    rm -rf /home/"$user" &>/dev/null
    
    # 2. Remover do Xray
    if [ -f "$XRAY_CONF" ]; then
        tmp=$(mktemp)
        jq --arg u "$user" '.inbounds[0].settings.clients |= map(select(.email != $u))' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
        systemctl restart xray &>/dev/null
    fi
    
    # 3. Limpar Banco de Dados
    sed -i "/^$user|/d" "$USERDB"
    echo "$(date '+%d/%m/%Y %H:%M:%S') - SISTEMA: Teste $user EXPIRADO e REMOVIDO." >> "$LOG_LIMIT"
    exit 0
fi

# ---------------------------------------------------------
# INTERFACE MANUAL (Menu Administrativo)
# ---------------------------------------------------------
clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}               💀 REMOÇÃO DE CONTA ENTERPRISE                 ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

if [ ! -s "$USERDB" ]; then
    echo -e "${R}Erro: Banco de dados de usuários está vazio.${NC}"
    read -p "Pressione ENTER para voltar..."
    exit 1
fi

echo -e "${W}Selecione o usuário para exterminar:${NC}"
echo -e "${C}--------------------------------------------------------------${NC}"
printf "${W}%-15s | %-20s | %-10s${NC}\n" "USUÁRIO" "EXPIRAÇÃO" "LIMITE"
echo -e "${C}--------------------------------------------------------------${NC}"
awk -F'|' '{printf "%-15s | %-20s | %-10s\n", $1, $3, $5}' "$USERDB"
echo -e "${C}--------------------------------------------------------------${NC}"
read -p " Nome exato do usuário: " user

if ! grep -q "^$user|" "$USERDB"; then
    echo -e "${R}Erro: Usuário '$user' não encontrado!${NC}"
    sleep 2; exit 1
fi

echo -e "\n${Y}[+] Iniciando protocolo de limpeza profunda...${NC}"

# 1. Encerramento de Processos
echo -ne "${W}[1/4] Encerrando sessões ativas... ${NC}"
pkill -u "$user" -f sshd &>/dev/null
userdel -f "$user" &>/dev/null
rm -rf /home/"$user" &>/dev/null
echo -e "${G}OK${NC}"

# 2. Limpeza do Xray Core
if [ -f "$XRAY_CONF" ]; then
    echo -ne "${W}[2/4] Removendo do Xray Core... ${NC}"
    if jq empty "$XRAY_CONF" 2>/dev/null; then
        tmp=$(mktemp)
        jq --arg u "$user" '.inbounds[0].settings.clients |= map(select(.email != $u))' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
        systemctl restart xray &>/dev/null
        echo -e "${G}OK${NC}"
    else
        echo -e "${R}ERRO NO JSON${NC}"
    fi
fi

# 3. Banco de Dados
echo -ne "${W}[3/4] Atualizando Banco de Dados... ${NC}"
sed -i "/^$user|/d" "$USERDB"
echo -e "${G}OK${NC}"

# 4. Auditoria
echo -ne "${W}[4/4] Registrando log de auditoria... ${NC}"
echo "$(date '+%d/%m/%Y %H:%M:%S') - ADMIN: Usuário $user REMOVIDO MANUALMENTE." >> "$LOG_LIMIT"
echo -e "${G}OK${NC}"

echo -e "\n${G}✅ USUÁRIO REMOVIDO COMPLETAMENTE!${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
read -p "Pressione ENTER para voltar ao menu..."
