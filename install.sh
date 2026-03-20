#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - INSTALLER 2.0
# ==========================================

C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'
REPO="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon-2.0/main"
BASE="/etc/painel"

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}            🚀 INSTALADOR NETSIMON ENTERPRISE 2.0             ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# 1. Preparação do Sistema
echo -ne "${W}[+] Atualizando repositórios... ${NC}"
apt update -y &>/dev/null && apt install wget curl jq python3 python3-pip dos2unix -y &>/dev/null
echo -e "${G}OK${NC}"

# 2. Criação de Estrutura
mkdir -p "$BASE"
mkdir -p "/etc/xray-manager/ssl"
mkdir -p "/etc/slowdns"

# 3. Download dos Módulos Core
arquivos=(
    "menu.sh" "adduser.sh" "addtest.sh" "deluser.sh" 
    "online.sh" "limit.sh" "unblock.sh" "websocket.sh" 
    "xray.sh" "slowdns-server.sh" "monitor.sh" "proxy.py" 
    "boot_check.sh" "repair.sh" "checkuser.py" "checkuser.sh"
)

echo -e "${Y}[!] Baixando componentes do ecossistema...${NC}"
for file in "${arquivos[@]}"; do
    printf "${W}  -> %-20s ${NC}" "$file"
    wget -q -O "$BASE/$file" "$REPO/$file"
    if [ -s "$BASE/$file" ]; then
        chmod +x "$BASE/$file"
        dos2unix "$BASE/$file" &>/dev/null
        echo -e "${G}[OK]${NC}"
    else
        echo -e "${R}[FALHA]${NC}"
    fi
done

# 4. Configuração de Atalhos e Boot
echo -ne "${W}[+] Configurando atalhos de sistema... ${NC}"
echo "bash $BASE/menu.sh" > /usr/local/bin/menu
chmod +x /usr/local/bin/menu
cp "$BASE/repair.sh" "/etc/xray-manager/repair.sh"
echo -e "${G}OK${NC}"

echo -ne "${W}[+] Ativando Auto-Recovery no Boot... ${NC}"
(crontab -l 2>/dev/null | grep -v "boot_check.sh"; echo "@reboot bash $BASE/boot_check.sh") | crontab -
echo -e "${G}OK${NC}"

# 5. Inicialização de Serviços Críticos
echo -e "${Y}[!] Iniciando serviços Enterprise...${NC}"
nohup python3 "$BASE/proxy.py" > /dev/null 2>&1 &
nohup python3 "$BASE/checkuser.py" > /dev/null 2>&1 &
bash "$BASE/boot_check.sh" &>/dev/null

echo -e "\n${G}✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo -e "${W}Digite ${C}menu${W} para gerenciar seu servidor.${NC}"
sleep 3
