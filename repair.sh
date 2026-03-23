#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - REPAIR SYSTEM 2.0
# ==========================================

BASE="/etc/painel"; REPO="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon-2.0/main"
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}            🛠️  REPARANDO SISTEMA NETSIMON 2.0                ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

arquivos=("menu.sh" "adduser.sh" "addtest.sh" "deluser.sh" "online.sh" "limit.sh" "unblock.sh" "websocket.sh" "xray.sh" "slowdns-server.sh" "monitor.sh" "proxy.py" "boot_check.sh" "repair.sh")

for file in "${arquivos[@]}"; do
    printf "${W}[+] Restaurando: ${Y}%-20s${NC}" "$file"
    wget -q -O "$BASE/$file" "$REPO/$file"
    chmod +x "$BASE/$file" && dos2unix "$BASE/$file" &>/dev/null
    echo -e "${G}[ OK ]${NC}"
done

# RESET DE PERMISSÕES CRÍTICAS
chmod -R 777 /var/log/xray
setcap 'cap_net_bind_service=+ep' /usr/local/bin/xray
systemctl daemon-reload
systemctl restart xray

echo -e "\n${G}✅ SISTEMA REPARADO E PERMISSÕES RESETADAS!${NC}"
sleep 2
