#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - XRAY MANAGER 2.0
# ==========================================

BASE_DIR="/etc/painel"
XRAY_CONF="/usr/local/etc/xray/config.json"
SSL_DIR="/etc/xray-manager/ssl"
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

# Função para Gerar Certificado (Essencial para Conexão VPN)
gerar_cert() {
    mkdir -p "$SSL_DIR"
    local domain=$(wget -qO- ifconfig.me)
    echo -e "${Y}[!] Gerando Certificado TLS para $domain...${NC}"
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -subj "/C=BR/ST=SP/L=SaoPaulo/O=NetSimon/CN=$domain" \
    -keyout "$SSL_DIR/privkey.pem" -out "$SSL_DIR/fullchain.pem" &>/dev/null
    echo -e "${G}[OK] Certificados gerados em $SSL_DIR${NC}"
}

# Função para Instalar o Xray Core se não existir
check_install() {
    if [ ! -f "/usr/local/bin/xray" ]; then
        echo -e "${Y}[!] Instalando Xray-Core Oficial...${NC}"
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install &>/dev/null
    fi
}

# Gerar Configuração Base (VLESS + TLS)
gerar_config() {
    local port=$1
    [ -z "$port" ] && port="443"
    
    cat <<EOF > "$XRAY_CONF"
{
    "log": { "loglevel": "warning" },
    "inbounds": [{
        "port": $port,
        "protocol": "vless",
        "settings": {
            "clients": [],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "tcp",
            "security": "tls",
            "tlsSettings": {
                "certificates": [{
                    "certificateFile": "$SSL_DIR/fullchain.pem",
                    "keyFile": "$SSL_DIR/privkey.pem"
                }]
            }
        }
    }],
    "outbounds": [{ "protocol": "freedom" }]
}
EOF
    systemctl restart xray
}

# Adicionar Usuário e Gerar Link para Aplicativo
add_user() {
    echo -ne "${W}Nome do Usuário: ${NC}"; read nick
    uuid=$(cat /proc/sys/kernel/random/uuid)
    port=$(jq -r '.inbounds[0].port' "$XRAY_CONF")
    ip=$(wget -qO- ifconfig.me)
    
    # Adiciona ao JSON
    jq ".inbounds[0].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$nick\", \"level\": 0}]" "$XRAY_CONF" > "$XRAY_CONF.tmp" && mv "$XRAY_CONF.tmp" "$XRAY_CONF"
    
    systemctl restart xray
    
    # Gera o Link VLESS (Configuração Definitiva para Apps)
    clear
    echo -e "${G}✅ USUÁRIO XRAY CRIADO!${NC}"
    echo -e "${W}--------------------------------------------${NC}"
    echo -e "${Y}Link para o Aplicativo (v2rayNG / Napsternet):${NC}"
    echo -e "${C}vless://$uuid@$ip:$port?security=tls&encryption=none&type=tcp#$nick${NC}"
    echo -e "${W}--------------------------------------------${NC}"
    read -p "Pressione ENTER para voltar..."
}

# Menu de Controle
clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                📡 XRAY ENTERPRISE MANAGER                    ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e " 1) Instalar/Resetar Xray Core"
echo -e " 2) Gerar Novos Certificados SSL"
echo -e " 3) Criar Usuário VLESS + TLS"
echo -e " 4) Ver Logs de Conexão"
echo -e " 0) Voltar ao Menu"
echo -ne "\n${Y}Escolha: ${NC}"; read opt

case $opt in
    1) check_install; gerar_cert; gerar_config 443; echo -e "${G}Pronto!${NC}"; sleep 2 ;;
    2) gerar_cert; systemctl restart xray; sleep 2 ;;
    3) add_user ;;
    4) journalctl -u xray --no-pager -n 50; read -p "ENTER..." ;;
    *) exit 0 ;;
esac
