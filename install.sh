#!/bin/bash
# NETSIMON ENTERPRISE - INSTALADOR BASE
# Autor: Gemini para NetSimon

GITHUB_URL="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon/main"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}            🚀 INSTALADOR NETSIMON ENTERPRISE 🚀              ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# 1. Preparação
echo -ne "[+] Atualizando repositórios e dependências... "
apt update -y &>/dev/null
apt install -y wget curl jq net-tools dos2unix python3 cron bc build-essential &>/dev/null
echo -e "${G}OK${NC}"

# 2. Arquitetura de Pastas
echo -ne "[+] Criando diretórios de sistema... "
mkdir -p /etc/painel
mkdir -p /etc/xray-manager
mkdir -p /etc/xray
mkdir -p /etc/slowdns
touch /etc/xray-manager/users.db
touch /etc/xray-manager/blocked.db
echo -e "${G}OK${NC}"

# 3. Download Modular
SCRIPTS=("menu.sh" "adduser.sh" "addtest.sh" "deluser.sh" "online.sh" "limit.sh" "unblock.sh" "websocket.sh" "xray.sh" "slowdns-server.sh" "monitor.sh" "proxy.py" "boot_check.sh")

echo -e "[+] Baixando módulos independentes do GitHub:"
for script in "${SCRIPTS[@]}"; do
    wget -q -O "/etc/painel/$script" "$GITHUB_URL/$script"
    if [ -s "/etc/painel/$script" ]; then
        chmod +x "/etc/painel/$script"
        dos2unix "/etc/painel/$script" &>/dev/null
        echo -e "  - ${script} [${G}BAIXADO${NC}]"
    else
        echo -e "  - ${script} [${R}FALHOU${NC}]"
    fi
done

# 4. Configuração de Persistência (Boot)
echo -ne "[+] Configurando persistência de reinício... "
(crontab -l 2>/dev/null; echo "@reboot bash /etc/painel/boot_check.sh") | crontab -
echo -e "${G}OK${NC}"

# 5. Atalho Global
echo "bash /etc/painel/menu.sh" > /usr/local/bin/menu
chmod +x /usr/local/bin/menu

echo -e "\n${G}INSTALAÇÃO CONCLUÍDA!${NC}"
echo -e "Digite ${W}menu${NC} para iniciar o gerenciamento."
