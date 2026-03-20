#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - XRAY MANAGER 2.2
# ==========================================

XRAY_CONF="/usr/local/etc/xray/config.json"
SSL_DIR="/etc/xray-manager/ssl"
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

get_ip() {
    local ip=$(wget -qO- ipv4.icanhazip.com || wget -qO- ifconfig.me/ip || curl -s checkip.amazonaws.com)
    echo "$ip" | tr -d '[:space:]'
}

gerar_cert() {
    mkdir -p "$SSL_DIR"
    local domain=$(get_ip)
    echo -e "${Y}[!] Gerando Certificado TLS para $domain...${NC}"
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -subj "/C=BR/ST=SP/L=SaoPaulo/O=NetSimon/CN=$domain" \
    -keyout "$SSL_DIR/privkey.pem" -out "$SSL_DIR/fullchain.pem" &>/dev/null
    chmod -R 755 "$SSL_DIR"
}

gerar_config_enterprise() {
    clear
    echo -e "${C} Escolha o Modo de Operação Xray:${NC}"
    echo -e " 1) VLESS + TLS (Portas: 443 Externa / 1080 Interna)"
    echo -e " 2) WebSocket HTTP (Portas: 80 e 8080 Simultâneas)"
    echo -e " 3) Porta Personalizada"
    echo -ne "\nEscolha: "; read p_opt

    case $p_opt in
        1) 
            [ ! -f "$SSL_DIR/fullchain.pem" ] && gerar_cert
            inbounds='{ "port": 443, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "'$SSL_DIR'/fullchain.pem", "keyFile": "'$SSL_DIR'/privkey.pem" }] } } }'
            ;;
        2)
            inbounds='{ "port": 80, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/netsimon" } } }, 
                      { "port": 8080, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/netsimon" } } }'
            ;;
        3)
            echo -ne "Digite a porta desejada: "; read p_user
            inbounds='{ "port": '$p_user', "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/netsimon" } } }'
            ;;
    esac

    cat <<EOF > "$XRAY_CONF"
{
    "log": { "loglevel": "warning" },
    "inbounds": [ $inbounds ],
    "outbounds": [{ "protocol": "freedom" }]
}
EOF
    systemctl restart xray
    echo -e "${G}[OK] Configuração Aplicada!${NC}"
    sleep 2
}

add_user() {
    echo -ne "${W}Nome do Usuário: ${NC}"; read nick
    [ -z "$nick" ] && return
    uuid=$(cat /proc/sys/kernel/random/uuid)
    ip=$(get_ip)
    
    # Adiciona a todos os inbounds ativos (80, 8080, etc)
    jq ".inbounds[].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$nick\", \"level\": 0}]" "$XRAY_CONF" > "$XRAY_CONF.tmp" && mv "$XRAY_CONF.tmp" "$XRAY_CONF"
    systemctl restart xray
    
    # Pega a primeira porta do config para o link
    port=$(jq -r '.inbounds[0].port' "$XRAY_CONF")
    
    clear
    echo -e "${G}✅ USUÁRIO CRIADO!${NC}"
    echo -e "Link: ${C}vless://$uuid@$ip:$port?path=/netsimon&security=none&encryption=none&type=ws#$nick${NC}"
    read -p "ENTER para voltar..."
}

status_detalhado() {
    clear
    echo -e "${C}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${C}║${W}           DETALHES TÉCNICOS DE REDE - XRAY           ${C}║${NC}"
    echo -e "${C}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e "${W}Portas Ativas no Core:${NC}"
    jq -r '.inbounds[] | "-> Porta: \(.port) | Protocolo: \(.protocol) | Rede: \(.streamSettings.network)"' "$XRAY_CONF"
    echo -e "\n${W}Processo:${NC} $(pgrep xray > /dev/null && echo -e "${G}ATIVO${NC}" || echo -e "${R}PARADO${NC}")"
    echo -e "${C}══════════════════════════════════════════════════════${NC}"
    read -p "ENTER para voltar..."
}

# Menu
clear
echo -e " 1) Instalar/Resetar Xray"
echo -e " 2) Configurar Portas (Sugerido: 443 ou 80/8080)"
echo -e " 3) Criar Usuário VLESS"
echo -e " 4) Status Detalhado"
echo -e " 0) Voltar"
echo -ne "\nEscolha: "; read opt
case $opt in
    1) bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; gerar_config_enterprise ;;
    2) gerar_config_enterprise ;;
    3) add_user ;;
    4) status_detalhado ;;
    *) exit 0 ;;
esac
