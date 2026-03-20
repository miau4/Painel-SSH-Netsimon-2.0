#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - REPAIR SYSTEM 2.0
# ==========================================

BASE="/etc/painel"
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
    # O uso do printf aqui garante o alinhamento das colunas sem imprimir o código da máscara
    printf "${W}[+] Verificando: ${Y}%-20s${NC}" "$file"
    
    # Remove arquivo antigo antes de baixar o novo para evitar conflitos
    rm -f "$BASE/$file"
    
    # Download silencioso com timeout e tentativas
    wget -q --timeout=10 --tries=3 -O "$BASE/$file" "$REPO/$file"
    
    # Verifica se o download foi bem sucedido e se o arquivo tem conteúdo
    if [[ -s "$BASE/$file" ]]; then
        chmod +x "$BASE/$file"
        # Converte para Unix para evitar quebras de linha do Windows
        if command -v dos2unix &>/dev/null; then
            dos2unix "$BASE/$file" &>/dev/null
        fi
        echo -e "${G}[ ATUALIZADO ]${NC}"
        
        # Sincroniza o reparador com o local de backup
        if [[ "$file" == "repair.sh" ]]; then
            cp "$BASE/$file" "/etc/xray-manager/repair.sh"
            chmod +x "/etc/xray-manager/repair.sh"
        fi
    else
        echo -e "${R}[ ERRO/404 ]${NC}"
    fi
done

# 3. Restaurar Atalhos de Sistema (Prevenção de Loop de Shell)
echo -ne "\n${W}[+] Restaurando atalho 'menu'... ${NC}"
rm -f /usr/local/bin/menu
echo '#!/bin/bash
bash /etc/painel/menu.sh' > /usr/local/bin/menu
chmod +x /usr/local/bin/menu
echo -e "${G}OK${NC}"

# 4. Verificação final de dependências
echo -ne "${W}[+] Verificando Python3 e ferramentas... ${NC}"
apt install python3 dos2unix -y &>/dev/null
echo -e "${G}OK${NC}"

echo -e "\n${C}══════════════════════════════════════════════════════════════${NC}"
echo -e "${G}✅ SISTEMA REPARADO COM SUCESSO!${NC}"
echo -e "${W}Digite 'menu' para retornar ao painel.${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
sleep 2
