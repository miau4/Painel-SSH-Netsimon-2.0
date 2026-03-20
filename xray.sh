#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - XRAY XHTTP 3.0
# ==========================================

XRAY_CONF="/usr/local/etc/xray/config.json"
SSL_DIR="/etc/xray-manager/ssl"
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

get_ip() { wget -qO- ipv4.icanhazip.com || wget -qO- ifconfig.me/ip; }

setup_xray() {
    clear
    echo -e "${C}⚙️ Instalando Xray Core (Protocolo XHTTP)...${NC}"
    
    # Instalação limpa do Core
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    apt install jq openssl -y

    # Geração de Certificados para TLS
    mkdir -p "$SSL_DIR"
    local domain=$(get_ip)
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -subj "/C=BR/ST=SP/L=SaoPaulo/O=NetSimon/CN=$domain" \
    -keyout "$SSL_DIR/privkey.pem" -out "$SSL_DIR/fullchain.pem" &>/dev/null

    # JSON ESTRUTURADO PARA XHTTP (Foco em SNI e HOST)
    cat <<EOF > "$XRAY_CONF"
{
    "log": { "loglevel": "warning" },
    "dns": {
        "servers": ["1.1.1.1", "8.8.8.8"]
    },
    "inbounds": [{
        "port": 443,
        "protocol": "vless",
        "settings": {
            "clients": [],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "xhttp",
            "security": "tls",
            "xhttpSettings": {
                "path": "/",
                "host": "9z6izazwwmq.map.azionedge.net",
                "mode": "auto"
            },
            "tlsSettings": {
                "certificates": [{
                    "certificateFile": "$SSL_DIR/fullchain.pem",
                    "keyFile": "$SSL_DIR/privkey.pem"
                }],
                "serverName": "www.tim.com.br",
                "allowInsecure": true
            }
        }
    }],
    "outbounds": [{ "protocol": "freedom" }]
}
EOF
    systemctl restart xray
    echo -e "${G}✅ Xray XHTTP configurado na porta 443!${NC}"
    sleep 2
}

add_user() {
    clear
    echo -ne "${W}Nome do Usuário: ${NC}"; read nick
    [ -z "$nick" ] && return
    uuid=$(cat /proc/sys/kernel/random/uuid)
    
    # Injeta UUID no JSON (Level 8 conforme seu exemplo)
    jq ".inbounds[0].settings.clients += [{\"id\": \"$uuid\", \"level\": 8, \"encryption\": \"none\"}]" "$XRAY_CONF" > "$XRAY_CONF.tmp" && mv "$XRAY_CONF.tmp" "$XRAY_CONF"
    systemctl restart xray
    
    ip=$(get_ip)
    # Variáveis fixas do seu link de exemplo
    SNI="www.tim.com.br"
    HOST="9z6izazwwmq.map.azionedge.net"
    
    clear
    echo -e "${G}✅ USUÁRIO CRIADO!${NC}"
    echo -e "${Y}Link VLESS XHTTP:${NC}"
    echo -e "${C}vless://$uuid@$ip:443?encryption=none&flow=none&type=xhttp&host=$HOST&headerType=auto&path=%2F&security=tls&sni=$SNI#$nick${NC}"
    echo -e "${W}--------------------------------------------${NC}"
    read -p "ENTER para voltar..."
}

# Menu de Navegação
while true; do
clear
echo -e "${C} 🛰️  NETSIMON - MÓDULO XRAY XHTTP ${NC}"
echo -e " 1) Instalar/Resetar Configuração"
echo -e " 2) Criar Usuário (Gerar Link)"
echo -e " 0) Voltar"
echo -ne "\nEscolha: "; read opt
case $opt in
    1) setup_xray ;;
    2) add_user ;;
    0) exit 0 ;;
esac
done
