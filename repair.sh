#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - REPAIR SYSTEM
# ==========================================

BASE="/etc/painel"
REPO="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon/main"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}            🛠️  REPARANDO SISTEMA NETSIMON...                 ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# 1. Garantir que o diretório base existe
mkdir -p "$BASE"
mkdir -p /etc/xray-manager

# 2. Lista de arquivos essenciais do ecossistema
arquivos=(
    "menu.sh" 
    "adduser.sh" 
    "addtest.sh" 
    "deluser.sh" 
    "online.sh" 
    "limit.sh" 
    "unblock.sh" 
    "websocket.sh" 
    "xray.sh" 
    "slowdns-server.sh" 
    "monitor.sh" 
    "proxy.py" 
    "boot_check.sh"
    "repair.sh"
)

echo -e "${Y}[!] Iniciando recuperação de módulos do GitHub...${NC}\n"

for file in "${arquivos[@]}"; do
    echo -ne "${W}[+] Verificando: ${Y}%-18s${NC}" "$file"
    
    # Download silencioso
    wget -q -O "$BASE/$file" "$REPO/$file"
    
    if [ $? -eq 0 ]; then
        chmod +x "$BASE/$file"
        echo -e "${G}[ ATUALIZADO ]${NC}"
        
        # Se for o repair.sh, faz uma cópia para o local que o menu procura
        if [ "$file" == "repair.sh" ]; then
            cp "$BASE/$file" "/etc/xray-manager/repair.sh"
            chmod +x "/etc/xray-manager/repair.sh"
        fi
    else
        echo -e "${R}[ ERRO/404 ]${NC}"
    fi
done

# 3. Restaurar Atalhos de Sistema
echo -ne "\n${W}[+] Restaurando atalho 'menu'... ${NC}"
echo "bash $BASE/menu.sh" > /usr/local/bin/menu
chmod +x /usr/local/bin/menu
echo -e "${G}OK${NC}"

# 4. Verificar dependências de Python (para o proxy.py)
if ! command -v python3 &>/dev/null; then
    echo -ne "${W}[+] Instalando Python3... ${NC}"
    apt install python3 -y &>/dev/null
    echo -e "${G}OK${NC}"
fi

echo -e "\n${C}══════════════════════════════════════════════════════════════${NC}"
echo -e "${G}✅ SISTEMA REPARADO COM SUCESSO!${NC}"
echo -e "${W}Digite 'menu' para retornar ao painel.${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
sleep 3
