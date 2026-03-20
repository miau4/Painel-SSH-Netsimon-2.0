#!/bin/bash

# ==========================================
#   NETSIMON ENTERPRISE - INSTALADOR BASE
# ==========================================

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

# URL Base do seu GitHub (Onde estão todos os scripts)
GITHUB_URL="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon/main"

# Lista de arquivos modulares do painel
SCRIPTS=(
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
)

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}            🚀 INSTALAÇÃO NETSIMON ENTERPRISE 🚀              ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC} Preparando o sistema e baixando módulos...                   ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
sleep 2

# 1. Atualização e Dependências
echo -e "\n${YELLOW}[1/4] Atualizando pacotes e instalando dependências...${NC}"
apt update -y &>/dev/null
apt install -y wget curl jq cron net-tools bc dos2unix python3 &>/dev/null

# 2. Estrutura de Diretórios e Banco de Dados
echo -e "${YELLOW}[2/4] Criando diretórios e bancos de dados...${NC}"
mkdir -p /etc/painel
mkdir -p /etc/xray-manager

# Cria os arquivos de banco de dados se não existirem
touch /etc/xray-manager/users.db
touch /etc/xray-manager/blocked.db

# 3. Download dos Scripts Modulares
echo -e "${YELLOW}[3/4] Baixando módulos do GitHub...${NC}"
cd /etc/painel || exit

for script in "${SCRIPTS[@]}"; do
    echo -ne "  -> Baixando ${script}... "
    wget -q -O "$script" "$GITHUB_URL/$script"
    
    if [ -s "$script" ]; then
        echo -e "${GREEN}OK${NC}"
        # Se for script bash, converte possíveis quebras de linha do Windows e dá permissão
        if [[ "$script" == *.sh ]]; then
            dos2unix "$script" &>/dev/null
            chmod +x "$script"
        fi
    else
        echo -e "${RED}FALHOU (Verifique se o arquivo está no GitHub)${NC}"
    fi
done

# Permissão especial para o script python
chmod +x /etc/painel/proxy.py &>/dev/null

# 4. Criando Atalho do Menu
echo -e "${YELLOW}[4/4] Configurando atalho do sistema...${NC}"
echo '#!/bin/bash' > /usr/local/bin/menu
echo 'bash /etc/painel/menu.sh' >> /usr/local/bin/menu
chmod +x /usr/local/bin/menu

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}             ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!             ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC} Para acessar o painel, digite em qualquer lugar:             ${CYAN}║${NC}"
echo -e "${CYAN}║${GREEN} menu                                                         ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${YELLOW} PRÓXIMOS PASSOS:${NC}                                             ${CYAN}║${NC}"
echo -e "${CYAN}║${NC} 1. Digite 'menu'                                             ${CYAN}║${NC}"
echo -e "${CYAN}║${NC} 2. Vá na opção 16 para instalar o Xray (VLESS)               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC} 3. Vá na opção 14 para ligar o WebSocket (se precisar)       ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
