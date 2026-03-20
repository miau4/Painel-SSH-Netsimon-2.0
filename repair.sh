#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - REPAIR SYSTEM 2.0
# ==========================================

BASE="/etc/painel"
# Atualizado para o repositório 2.0 para bater com seu menu e instalador
REPO="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon-2.0/main"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}            🛠️  REPARANDO SISTEMA NETSIMON 2.0                ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# 1. Garantir que o diretório base existe
mkdir -p "$BASE"
mkdir -p /etc/xray-manager

# 2. Lista de arquivos essenciais
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
    # Ajustado o printf para alinhar corretamente as colunas
    printf "${W}[+] Verificando: ${Y}%-18s${NC}" "$file"
    
    # Download silencioso com timeout
    wget -q --timeout=10 -O "$BASE/$file" "$REPO/$file"
    
    # Verifica se o arquivo existe e não está vazio após o download
    if [ -s "$BASE/$file" ]; then
        chmod +x "$BASE/$file"
        # Converte para o formato Unix caso tenha sido editado no Windows
        dos2unix "$BASE/$file" &>/dev/null
        echo -e "${G}[ ATUALIZADO ]${NC}"
        
        # Sincroniza o reparador com o diretório que o menu acessa
        if [ "$file" == "repair.sh" ]; then
            cp "$BASE/$file" "/etc/xray-manager/repair.sh"
            chmod +x "/etc/xray-manager/repair.sh"
        fi
    else
        echo -e "${R}[ ERRO/404 ]${NC}"
    fi
done

# 3. Restaurar Atalhos de Sistema (Correção de Shell Level)
echo -ne "\n${W}[+] Restaurando atalho 'menu'... ${NC}"
# Criando atalho robusto para evitar loops de shell
echo '#!/bin/bash
bash /etc/painel/menu.sh' > /usr/local/bin/menu
chmod +x /usr/local/bin/menu
echo -e "${G}OK${NC}"

# 4. Verificar dependências essenciais
if ! command -v python3 &>/dev/null; then
    echo -ne "${W}[+] Instalando Python3... ${NC}"
    apt install python3 -y &>/dev/null
    echo -e "${G}OK${NC}"
fi

if ! command -v dos2unix &>/dev/null; then
    apt install dos2unix -y &>/dev/null
fi

echo -e "\n${C}══════════════════════════════════════════════════════════════${NC}"
echo -e "${G}✅ SISTEMA REPARADO COM SUCESSO!${NC}"
echo -e "${W}Digite 'menu' para retornar ao painel.${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
sleep 2
