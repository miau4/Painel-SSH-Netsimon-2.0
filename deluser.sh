#!/bin/bash
# NETSIMON ENTERPRISE - EXTERMINADOR DE CONTAS (PROVISÃO REVERSA)

USERDB="/etc/xray-manager/users.db"
XRAY_CONF="/etc/xray/config.json"
LOG_LIMIT="/var/log/netsimon_limit.log"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}               💀 REMOÇÃO DE CONTA ENTERPRISE                 ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# 1. Verificação de Banco de Dados
if [ ! -s "$USERDB" ]; then
    echo -e "${R}Erro: Banco de dados de usuários está vazio ou não existe.${NC}"
    read -p "Pressione ENTER para voltar..."
    exit 1
fi

# 2. Listagem formatada para o Administrador
echo -e "${W}Selecione o usuário para exterminar:${NC}"
echo -e "${C}--------------------------------------------------------------${NC}"
printf "${W}%-15s | %-20s | %-10s${NC}\n" "USUÁRIO" "EXPIRAÇÃO" "LIMITE"
echo -e "${C}--------------------------------------------------------------${NC}"
awk -F'|' '{printf "%-15s | %-20s | %-10s\n", $1, $3, $5}' "$USERDB"
echo -e "${C}--------------------------------------------------------------${NC}"
read -p " Nome exato do usuário: " user

# 3. Validação de existência
if ! grep -q "^$user|" "$USERDB"; then
    echo -e "${R}Erro: Usuário '$user' não encontrado!${NC}"
    sleep 2; exit 1
fi

echo -e "\n${Y}[+] Iniciando protocolo de limpeza profunda...${NC}"

# 4. KILL DE PROCESSOS (SSH, WS, DNS)
echo -ne "${W}[1/5] Encerrando sessões ativas (SSH/Tunel)... ${NC}"
pkill -u "$user" -f sshd &>/dev/null
pkill -u "$user" &>/dev/null
timeout 2s skill -u "$user" &>/dev/null
echo -e "${G}OK${NC}"

# 5. REMOÇÃO DO SISTEMA OPERACIONAL
echo -ne "${W}[2/5] Removendo conta do Linux e diretórios... ${NC}"
userdel -f "$user" &>/dev/null
rm -rf /home/"$user" &>/dev/null
rm -rf /var/mail/"$user" &>/dev/null
echo -e "${G}OK${NC}"

# 6. REMOÇÃO DO XRAY CORE (JSON SEGURO)
if [ -f "$XRAY_CONF" ]; then
    echo -ne "${W}[3/5] Removendo credenciais do Xray Core... ${NC}"
    # Verificação de integridade do JSON antes de editar
    if jq empty "$XRAY_CONF" 2>/dev/null; then
        tmp=$(mktemp)
        # Remove o objeto do cliente baseado no email (user)
        jq --arg u "$user" '.inbounds[0].settings.clients |= map(select(.email != $u))' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
        systemctl restart xray &>/dev/null
        echo -e "${G}OK${NC}"
    else
        echo -e "${R}ERRO NO JSON${NC}"
    fi
else
    echo -e "${Y}[3/5] Xray não instalado. Pulando...${NC}"
fi

# 7. LIMPEZA DE BANCOS DE DADOS (DB e BLOCKED)
echo -ne "${W}[4/5] Atualizando Banco de Dados Central... ${NC}"
sed -i "/^$user|/d" "$USERDB"
[ -f "/etc/xray-manager/blocked.db" ] && sed -i "/^$user|/d" "/etc/xray-manager/blocked.db"
echo -e "${G}OK${NC}"

# 8. REGISTRO DE LOG (AUDITORIA)
echo -ne "${W}[5/5] Registrando exclusão na auditoria... ${NC}"
echo "$(date '+%d/%m/%Y %H:%M:%S') - ADMIN: Usuário $user REMOVIDO COMPLETAMENTE." >> "$LOG_LIMIT"
echo -e "${G}OK${NC}"

echo -e "\n${G}✅ SINCROINIZAÇÃO DE REMOÇÃO CONCLUÍDA!${NC}"
echo -e "${W}O usuário não possui mais acesso a nenhum protocolo.${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
read -p "Pressione ENTER para voltar ao menu..."
