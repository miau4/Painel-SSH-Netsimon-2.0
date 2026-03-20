#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - INSTALADOR BASE 2.0
# ==========================================

GITHUB_URL="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon-2.0/main"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}            🚀 INSTALADOR NETSIMON ENTERPRISE 2.0           ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# 1. Preparação e Dependências
echo -ne "[+] Atualizando sistema e dependências... "
apt update -y &>/dev/null
apt install -y wget curl jq net-tools dos2unix python3 python3-pip cron bc build-essential speedtest-cli &>/dev/null
echo -e "${G}OK${NC}"

# 2. Arquitetura de Pastas
echo -ne "[+] Criando diretórios de sistema... "
mkdir -p /etc/painel
mkdir -p /etc/xray-manager
mkdir -p /etc/xray
mkdir -p /etc/slowdns
[ ! -f /etc/xray-manager/users.db ] && touch /etc/xray-manager/users.db
[ ! -f /etc/xray-manager/blocked.db ] && touch /etc/xray-manager/blocked.db
echo -e "${G}OK${NC}"

# 3. Download Modular
# Adicionei o repair.sh na lista para garantir a Opção 10 do Menu
SCRIPTS=("menu.sh" "adduser.sh" "addtest.sh" "deluser.sh" "online.sh" "limit.sh" "unblock.sh" "websocket.sh" "xray.sh" "slowdns-server.sh" "monitor.sh" "proxy.py" "boot_check.sh" "repair.sh")

echo -e "[+] Baixando módulos do GitHub (${Y}Branch: Main${NC}):"

for script in "${SCRIPTS[@]}"; do
    # Remove o arquivo se ele existir mas estiver vazio (corrompido)
    [ -f "/etc/painel/$script" ] && rm -f "/etc/painel/$script"
    
    # Download com timeout para não travar o instalador
    wget -q --timeout=10 --tries=3 -O "/etc/painel/$script" "$GITHUB_URL/$script"
    
    if [ -s "/etc/painel/$script" ]; then
        chmod +x "/etc/painel/$script"
        dos2unix "/etc/painel/$script" &>/dev/null
        echo -e "  - ${script} [${G}BAIXADO${NC}]"
    else
        echo -e "  - ${script} [${R}FALHOU${NC}]"
    fi
done

# 4. Configuração Especial para o Reparo e Atalho
# O Menu busca o reparo em /etc/xray-manager/
cp /etc/painel/repair.sh /etc/xray-manager/repair.sh &>/dev/null
chmod +x /etc/xray-manager/repair.sh &>/dev/null

# 5. Configuração de Persistência (Boot)
echo -ne "[+] Configurando persistência (Crontab)... "
crontab -l 2>/dev/null | grep -v "boot_check.sh" > mycron
echo "@reboot bash /etc/painel/boot_check.sh" >> mycron
crontab mycron && rm mycron
echo -e "${G}OK${NC}"

# 6. Atalho Global
echo "bash /etc/painel/menu.sh" > /usr/local/bin/menu
chmod +x /usr/local/bin/menu

echo -e "\n${G}✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
echo -e "${W} Use o comando: ${Y}menu${W} para gerenciar seu servidor.${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
