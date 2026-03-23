#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - INSTALLER 2.0
# ==========================================

C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'
REPO="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon-2.0/main"
BASE="/etc/painel"

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                🚀 INSTALADOR NETSIMON ENTERPRISE 2.0           ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# 1. Preparação do Sistema e Blindagem de Portas (PULO DO GATO: FIREWALL)
echo -ne "${W}[+] Sincronizando relógio e abrindo firewall... ${NC}"
timedatectl set-timezone America/Sao_Paulo

# Limpeza total de regras que bloqueiam a Oracle
iptables -F && iptables -X
iptables -t nat -F && iptables -t nat -X
iptables -t mangle -F && iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Remove sequestradores nativos da Oracle/Ubuntu
systemctl stop apache2 oracle-cloud-agent oracle-cloud-agent-updater nginx &>/dev/null
systemctl disable apache2 oracle-cloud-agent oracle-cloud-agent-updater &>/dev/null
apt purge apache2 -y &>/dev/null
echo -e "${G}OK${NC}"

echo -ne "${W}[+] Instalando dependências essenciais... ${NC}"
apt update -y &>/dev/null 
apt install wget curl jq python3 python3-pip dos2unix nginx stunnel4 net-tools lsof iptables-persistent -y &>/dev/null
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

# 4. Estrutura e Logs (PULO DO GATO: PERMISSÕES TOTAIS)
mkdir -p "$BASE"
mkdir -p "/etc/xray-manager/ssl"
mkdir -p "/etc/slowdns"
mkdir -p "/var/log/xray"
mkdir -p "/usr/local/etc/xray"
touch /var/log/xray/access.log /var/log/xray/error.log
chmod -R 777 /var/log/xray
chown -R root:root /var/log/xray

# 5. Download dos Módulos Core
arquivos=(
    "menu.sh" "adduser.sh" "addtest.sh" "deluser.sh" 
    "online.sh" "limit.sh" "unblock.sh" "websocket.sh" 
    "xray.sh" "slowdns-server.sh" "monitor.sh" "proxy.py" 
    "boot_check.sh" "repair.sh" "checkuser.py" "checkuser.sh"
)

echo -e "${Y}[!] Baixando ecossistema Netsimon...${NC}"
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

# 6. Xray - Binário e Configuração (PULO DO GATO: SETCAP)
echo -ne "${W}[+] Instalando Binário Xray e aplicando Setcap... ${NC}"
# Baixa o instalador oficial do Xray para garantir o binário atualizado
bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) &>/dev/null
# O PULO DO GATO: Permite abrir porta 443 sem ser root total
setcap 'cap_net_bind_service=+ep' /usr/local/bin/xray

wget -q -O /usr/local/etc/xray/config.json "$REPO/config.json"
# Fallback caso o config.json não exista no repo
if [ ! -s /usr/local/etc/xray/config.json ]; then
    cat << 'EOF' > /usr/local/etc/xray/config.json
{
  "log": {"access": "/var/log/xray/access.log","error": "/var/log/xray/error.log","loglevel": "warning"},
  "inbounds": [{"port": 443,"protocol": "vless","settings": {"clients": [],"decryption": "none"},"streamSettings": {"network": "xhttp","security": "tls","tlsSettings": {"certificates": [{"certificateFile": "/etc/xray-manager/ssl/fullchain.pem","keyFile": "/etc/xray-manager/ssl/privkey.pem"}]},"xhttpSettings": {"mode": "packet-up","path": "/"}}}]
}
EOF
fi
echo -e "${G}OK${NC}"

# 7. Configuração do Serviço Systemd (PULO DO GATO: RECOVERY)
echo -ne "${W}[+] Configurando Xray Service... ${NC}"
cat << 'EOF' > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service - Netsimon
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable xray &>/dev/null
echo -e "${G}OK${NC}"

# 8. Finalização de Atalhos e Boot
echo "bash $BASE/menu.sh" > /usr/local/bin/menu
chmod +x /usr/local/bin/menu
echo -e "${G}OK${NC}"

# Salva as regras de iptables para o reboot
netfilter-persistent save &>/dev/null

echo -e "\n${G}✅ INSTALAÇÃO CONCLUÍDA!${NC}"
echo -e "${W}Portas Abertas: ${C}443 (Xray), 80 (WS), 81 (Web), 8443 (SSL)${NC}"
echo -e "${W}Digite ${C}menu${W} para começar.${NC}"
