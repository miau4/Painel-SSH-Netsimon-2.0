#!/bin/bash

# Caminhos Sincronizados
USERS_DB="/etc/xray-manager/users.db"
XRAY_LOG="/var/log/xray/access.log"

# Cores
GREEN='\033[1;32m'
CYAN='\033[1;36m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}        👥 MONITOR DE USUÁRIOS ONLINE     ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

# Verifica se o banco existe
if [ ! -f "$USERS_DB" ]; then
    echo -e "${RED}Erro: Banco de usuários não encontrado!${NC}"
    exit 1
fi

TOTAL_CON=0

echo -e "${YELLOW}USUÁRIO        |  PROTOCOLO  |  CONEXÕES${NC}"
echo -e "${CYAN}------------------------------------------${NC}"

# Loop para verificar cada usuário do banco
while IFS="|" read -r user uuid exp pass limit; do
    [[ -z "$user" ]] && continue

    # 1. VERIFICA SSH / SLOWDNS (Processos ativos)
    # Filtra conexões SSH que não são root e pertencem ao usuário
    con_ssh=$(ps aux | grep -i sshd | grep -v root | grep -v grep | grep "$user" | wc -l)

    # 2. VERIFICA XRAY (Via Log de IPs únicos nos últimos 5 minutos)
    con_xray=0
    if [ -f "$XRAY_LOG" ]; then
        # Conta IPs únicos que acessaram com o email do usuário nos logs recentes
        con_xray=$(grep "$user" "$XRAY_LOG" | tail -n 50 | awk '{print $3}' | cut -d: -f1 | sort -u | grep -v "^$" | wc -l)
    fi

    # Exibição se estiver online
    if [ "$con_ssh" -gt 0 ] || [ "$con_xray" -gt 0 ]; then
        status_line=""
        [ "$con_ssh" -gt 0 ] && status_line+="SSH/DNS($con_ssh) "
        [ "$con_xray" -gt 0 ] && status_line+="VLESS($con_xray) "
        
        printf "${GREEN}%-14s${NC} | %-11s | %-5s\n" "$user" "ATIVO" "$((con_ssh + con_xray))"
        TOTAL_CON=$((TOTAL_CON + con_ssh + con_xray))
    fi

done < "$USERS_DB"

if [ "$TOTAL_CON" -eq 0 ]; then
    echo -e "${RED}Nenhum usuário conectado no momento.${NC}"
fi

echo -e "${CYAN}------------------------------------------${NC}"
echo -e "${GREEN}Total de Conexões Ativas:${NC} $TOTAL_CON"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

read -n1 -r -p "Pressione qualquer tecla para voltar..."
