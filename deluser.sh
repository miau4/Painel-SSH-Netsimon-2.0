#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - EXTERMINADOR 2.0
# ==========================================

BASE="/etc/painel"
USERDB="/etc/painel/usuarios.db" # Banco Unificado
XRAY_CONF="/usr/local/etc/xray/config.json"
LOG_LIMIT="/var/log/netsimon_limit.log"

# Cores Estilo WebSocket
P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; B='\033[1;34m'; NC='\033[0m'

# ---------------------------------------------------------
# FUNÇÃO DE LIMPEZA REAL (O Pulo do Gato)
# ---------------------------------------------------------
fun_limpar_user() {
    local user_to_del="$1"
    # 1. Encerramento de Processos
    pkill -u "$user_to_del" -f sshd &>/dev/null
    userdel -f "$user_to_del" &>/dev/null
    rm -rf /home/"$user_to_del" &>/dev/null

    # 2. Limpeza do Xray Core (Procurando em todos os inbounds)
    if [ -f "$XRAY_CONF" ]; then
        tmp=$(mktemp)
        jq --arg u "$user_to_del" '(.inbounds[] | select(.port == 443)).settings.clients |= map(select(.email != $u))' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
    fi
    
    # 3. Banco de Dados
    sed -i "/^$user_to_del|/d" "$USERDB"
}

# ---------------------------------------------------------
# LÓGICA DE EXCLUSÃO AUTOMÁTICA (Para o addtest.sh)
# ---------------------------------------------------------
if [[ "$2" == "--auto" ]]; then
    user="$1"
    fun_limpar_user "$user"
    systemctl restart xray &>/dev/null
    echo "$(date '+%d/%m/%Y %H:%M:%S') - SISTEMA: Teste $user EXPIRADO e REMOVIDO." >> "$LOG_LIMIT"
    exit 0
fi

# ---------------------------------------------------------
# INTERFACE MANUAL (Menu Administrativo)
# ---------------------------------------------------------
clear
echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${P}║${W}                💀 REMOÇÃO DE CONTA ENTERPRISE               ${P}║${NC}"
echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"

if [ ! -s "$USERDB" ]; then
    echo -e "${R}Erro: Banco de dados de usuários está vazio.${NC}"
    read -p "Pressione ENTER para voltar..."
    exit 1
fi

echo -e "${W}Selecione o usuário para exterminar:${NC}"
echo -e "${P}--------------------------------------------------------------${NC}"
printf "${W}%-4s | %-15s | %-15s | %-10s${NC}\n" "ID" "USUÁRIO" "EXPIRAÇÃO" "SENHA"
echo -e "${P}--------------------------------------------------------------${NC}"

# Criar lista numerada para seleção
declare -A lista_users
i=1
while IFS='|' read -r u id exp p lim; do
    printf "${C}%-4s${NC} | ${W}%-15s | %-15s | %-10s${NC}\n" "$i" "$u" "$exp" "$p"
    lista_users[$i]=$u
    ((i++))
done < "$USERDB"

echo -e "${P}--------------------------------------------------------------${NC}"
echo -e " ${G}[ 0 ]${W} EXTERMINAR TODOS OS USUÁRIOS${NC}"
echo -e " ${R}[ x ]${W} VOLTAR AO MENU${NC}"
echo -e "${P}--------------------------------------------------------------${NC}"
read -p " Escolha o ID ou Nome: " escolha

# Opção de sair
[[ "$escolha" == "x" ]] && exit

# Opção 0: Excluir Tudo
if [[ "$escolha" == "0" ]]; then
    echo -ne "\n${R}⚠️  TEM CERTEZA? Isso deletará TODOS os usuários! (s/n): ${NC}"
    read confirmar
    [[ "$confirmar" != "s" ]] && exit
    echo -e "\n${Y}[+] Iniciando limpeza total...${NC}"
    for u in "${lista_users[@]}"; do
        echo -ne "${W} -> Exterminando: ${C}$u... ${NC}"
        fun_limpar_user "$u"
        echo -e "${G}OK${NC}"
    done
    systemctl restart xray &>/dev/null
    echo "$(date '+%d/%m/%Y %H:%M:%S') - ADMIN: LIMPEZA TOTAL REALIZADA." >> "$LOG_LIMIT"
    echo -e "\n${G}✅ TODOS OS USUÁRIOS FORAM REMOVIDOS!${NC}"
    sleep 2; exit
fi

# Opção Unitária (por número ou nome)
if [[ ${lista_users[$escolha]} ]]; then
    user=${lista_users[$escolha]}
else
    user=$escolha
fi

if ! grep -q "^$user|" "$USERDB"; then
    echo -e "${R}Erro: Opção ou Usuário '$user' não encontrado!${NC}"
    sleep 2; exit 1
fi

echo -e "\n${Y}[+] Iniciando protocolo de limpeza profunda em: ${C}$user${NC}"

# Execução das 4 etapas
echo -ne "${W}[1/4] Encerrando processos e sistema... ${NC}"
fun_limpar_user "$user"
echo -e "${G}OK${NC}"

echo -ne "${W}[2/4] Sincronizando Xray Core... ${NC}"
systemctl restart xray &>/dev/null
echo -e "${G}OK${NC}"

echo -ne "${W}[3/4] Atualizando Banco de Dados... ${NC}"
# Já feito pela fun_limpar_user
echo -e "${G}OK${NC}"

echo -ne "${W}[4/4] Registrando auditoria... ${NC}"
echo "$(date '+%d/%m/%Y %H:%M:%S') - ADMIN: Usuário $user REMOVIDO MANUALMENTE." >> "$LOG_LIMIT"
echo -e "${G}OK${NC}"

echo -e "\n${G}✅ USUÁRIO REMOVIDO COMPLETAMENTE!${NC}"
echo -e "${P}══════════════════════════════════════════════════════════════${NC}"
read -p "Pressione ENTER para voltar ao menu..."
