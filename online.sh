#!/bin/bash

# Caminhos
USERDB="/etc/xray-manager/users.db"
XRAY_LOG="/var/log/xray/access.log"

# Cores
G='\033[1;32m' # Verde
R='\033[1;31m' # Vermelho
Y='\033[1;33m' # Amarelo
C='\033[1;36m' # Ciano
W='\033[1;37m' # Branco
NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                👥 MONITOR DE CONEXÕES REAIS                  ${C}║${NC}"
echo -e "${C}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${C}║${Y} %-14s ${C}│${Y} %-12s ${C}│${Y} %-10s ${C}│${Y} %-8s ${C}║${NC}\n" "USUÁRIO" "PROTOCOLO" "CONEXÃO" "STATUS"
echo -e "${C}╠══════════════════════════════════════════════════════════════╣${NC}"

TOTAL_GLOBAL=0

if [ ! -f "$USERDB" ]; then
    printf "${C}║${R} %-58s ${C}║${NC}\n" "ERRO: Banco de dados não encontrado!"
    echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi

while IFS="|" read -r user uuid exp pass limit; do
    [[ -z "$user" ]] && continue
    [[ ! "$limit" =~ ^[0-9]+$ ]] && limit=1

    # --- DETECÇÃO SSH / SLOWDNS ---
    # Filtra processos sshd que pertencem ao usuário
    con_ssh=$(ps aux | grep -i sshd | grep -v root | grep -v grep | grep "$user" | wc -l)
    
    # --- DETECÇÃO XRAY (VLESS/WS) ---
    con_xray=0
    if [ -f "$XRAY_LOG" ]; then
        # Conta IPs únicos nos últimos 2 minutos de log para o usuário específico
        con_xray=$(grep "$user" "$XRAY_LOG" | tail -n 100 | awk '{print $3}' | cut -d: -f1 | sort -u | grep -v "^$" | wc -l)
    fi

    TOTAL_USER=$((con_ssh + con_xray))

    if [ "$TOTAL_USER" -gt 0 ]; then
        # Definir Protocolo e Cor do Status
        PROTO=""
        [ "$con_ssh" -gt 0 ] && PROTO="SSH/DNS"
        [ "$con_xray" -gt 0 ] && [ -n "$PROTO" ] && PROTO="HÍBRIDO" || [ "$con_xray" -gt 0 ] && PROTO="VLESS/WS"
        
        # Lógica de Cor do Limite (Verde se OK, Vermelho se Excedido)
        S_COLOR=$G
        STATUS_TXT="NORMAL"
        if [ "$TOTAL_USER" -gt "$limit" ]; then
            S_COLOR=$R
            STATUS_TXT="EXCEDIDO"
        fi

        # Linha do Usuário Formatada
        printf "${C}║${NC} %-14s ${C}│${NC} %-12s ${C}│${S_COLOR} %-10s ${C}│${S_COLOR} %-8s ${C}║${NC}\n" "$user" "$PROTO" "$TOTAL_USER/$limit" "$STATUS_TXT"
        TOTAL_GLOBAL=$((TOTAL_GLOBAL + TOTAL_USER))
    fi
done < "$USERDB"

# Caso ninguém esteja online
if [ "$TOTAL_GLOBAL" -eq 0 ]; then
    printf "${C}║${R} %-58s ${C}║${NC}\n" "NENHUM USUÁRIO CONECTADO NO MOMENTO"
fi

echo -e "${C}╠══════════════════════════════════════════════════════════════╣${NC}"
printf "${C}║${W} TOTAL DE CONEXÕES ATIVAS NO SERVIDOR: %-21s ${C}║${NC}\n" "$TOTAL_GLOBAL"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# Se não estiver em modo 'watch' (monitor), pede enter
if [ -z "$1" ]; then
    echo ""
    read -n1 -r -p "Pressione qualquer tecla para voltar ao menu..."
fi
