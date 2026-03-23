#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - INSTALLER 2.0
# ==========================================

C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'
REPO="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon-2.0/main"
BASE="/etc/painel"

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}              🚀 INSTALADOR NETSIMON ENTERPRISE 2.0           ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# 1. Preparação do Sistema e Blindagem de Portas
echo -ne "${W}[+] Sincronizando relógio e limpando portas... ${NC}"
timedatectl set-timezone America/Sao_Paulo
# Remove sequestradores nativos da Oracle/Ubuntu
systemctl stop apache2 oracle-cloud-agent oracle-cloud-agent-updater nginx &>/dev/null
systemctl disable apache2 oracle-cloud-agent oracle-cloud-agent-updater &>/dev/null
apt purge apache2 -y &>/dev/null
echo -e "${G}OK${NC}"

echo -ne "${W}[+] Instalando dependências... ${NC}"
apt update -y &>/dev/null 
apt install wget curl jq python3 python3-pip dos2unix nginx stunnel4 net-tools lsof -y &>/dev/null
echo -e "${G}OK${NC}"

# 2. Configuração de Portas (Nginx e Python -> 81)
echo -ne "${W}[+] Configurando Webserver na porta 81... ${NC}"
rm -f /etc/nginx/sites-enabled/default
cat << 'EOF' > /etc/nginx/sites-available/netsimon_web
server {
    listen 81;
    server_name _;
    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF
ln -sf /etc/nginx/sites-available/netsimon_web /etc/nginx/sites-enabled/
systemctl restart nginx &>/dev/null
echo -e "${G}OK${NC}"

# 3. Configuração Stunnel4 (8443)
echo -ne "${W}[+] Configurando Stunnel (Porta 8443)... ${NC}"
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 -subj "/CN=Netsimon" -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem &>/dev/null
cat << 'EOF' > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel4.pid
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[ssh]
accept = 8443
connect = 127.0.0.1:22
EOF
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
systemctl restart stunnel4 &>/dev/null
echo -e "${G}OK${NC}"

# 4. Criação de Estrutura e Logs
mkdir -p "$BASE"
mkdir -p "/etc/xray-manager/ssl"
mkdir -p "/etc/slowdns"
mkdir -p "/var/log/xray"
touch /var/log/xray/access.log
chmod 666 /var/log/xray/access.log

# 5. Download dos Módulos Core
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

# 6. Baixar e Aplicar Configuração Pré-configurada do Xray
echo -ne "${W}[+] Aplicando config.json otimizada... ${NC}"
mkdir -p /etc/xray
# Tenta baixar do seu repositório, se falhar cria uma base
wget -q -O /etc/xray/config.json "$REPO/config.json"
if [ ! -s /etc/xray/config.json ]; then
    # Fallback caso o arquivo não esteja no GitHub ainda
    cat << 'EOF' > /etc/xray/config.json
{
  "log": {"access": "/var/log/xray/access.log","loglevel": "info"},
  "inbounds": [{"port": 443,"protocol": "vless","settings": {"clients": []}}]
}
EOF
fi
echo -e "${G}OK${NC}"

# 7. Configuração de Atalhos e Boot
echo -ne "${W}[+] Finalizando atalhos e boot... ${NC}"
echo "bash $BASE/menu.sh" > /usr/local/bin/menu
chmod +x /usr/local/bin/menu
cp "$BASE/repair.sh" "/etc/xray-manager/repair.sh" 2>/dev/null
echo -e "${G}OK${NC}"

echo -ne "${W}[+] Ativando Auto-Recovery no Boot... ${NC}"
(crontab -l 2>/dev/null | grep -v "boot_check.sh"; echo "@reboot bash $BASE/boot_check.sh") | crontab -
echo -e "${G}OK${NC}"

# 8. Inicialização (Python na 81 e WebSocket na 80)
echo -e "${Y}[!] Iniciando serviços Enterprise...${NC}"
pkill -f "proxy.py"
pkill -f "checkuser.py"
# Python na 81 (conforme solicitado para não brigar com a 80)
nohup python3 "$BASE/proxy.py" 81 > /dev/null 2>&1 &
nohup python3 "$BASE/checkuser.py" > /dev/null 2>&1 &
# Reinicia o Xray para assumir os novos logs
systemctl restart xray &>/dev/null
bash "$BASE/boot_check.sh" &>/dev/null

echo -e "\n${G}✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo -e "${W}Porta 80: ${C}Livre para Túnel/Xray${NC}"
echo -e "${W}Porta 81: ${C}Python / Nginx Web${NC}"
echo -e "${W}Fuso Horário: ${C}América/São Paulo${NC}"
echo -e "${W}Digite ${C}menu${W} para gerenciar seu servidor.${NC}"
sleep 3
