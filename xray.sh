#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - XRAY MANAGER 2.2
# ==========================================

XRAY_CONF="/usr/local/etc/xray/config.json"
SSL_DIR="/etc/xray-manager/ssl"
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

# Captura de IP limpa para evitar erros de HTML no link
get_ip() {
    local ip=$(wget -qO- ipv4.icanhazip.com || wget -qO- ifconfig.me/ip || curl -s checkip.amazonaws.com)
    echo "$ip" | tr -d '[:space:]'
}

# Gerador de Certificado SSL Auto-assinado
gerar_cert() {
    mkdir -p "$SSL_DIR"
    local domain=$(get_ip)
    echo -e "${Y}[!] Gerando Certificado TLS para $domain...${NC}"
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -subj "/C=BR/ST=SP/L=SaoPaulo/O=NetSimon/CN=$domain" \
    -keyout "$SSL_DIR/privkey.pem" -out "$SSL_DIR/fullchain.pem" &>/dev/null
    chmod -R 755 "$SSL_DIR"
}

# Configuração de Portas conforme solicitado (80/8080 ou 443)
gerar_config_enterprise() {
    clear
    echo -e "${C}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${C}║${W}          CONFIGURAÇÃO DE PROTOCOLOS XRAY             ${C}║${NC}"
    echo -e "${C}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e " 1) VLESS + TLS (Porta: 443 | Interna: 1080)"
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
    echo -e "${G}[OK] Configuração de Rede Aplicada!${NC}"
    sleep 2
}

# Criação de Usuário com Link Limpo
add_user() {
    echo -ne "${W}Nome do Usuário: ${NC}"; read nick
    [ -z "$nick" ] && return
    uuid=$(cat /proc/sys/kernel/random/uuid)
    ip=$(get_ip)
    
    # Injeta o usuário em todos os inbounds (funciona em todas as portas configuradas)
    jq ".inbounds[].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$nick\", \"level\": 0}]" "$XRAY_CONF" > "$XRAY_CONF.tmp" && mv "$XRAY_CONF.tmp" "$XRAY_CONF"
    systemctl restart xray
    
    port=$(jq -r '.inbounds[0].port' "$XRAY_CONF")
    
    clear
    echo -e "${G}✅ USUÁRIO XRAY CRIADO!${NC}"
    echo -e "${W}--------------------------------------------${NC}"
    echo -e "${Y}Link VLESS:${NC}"
    echo -e "${C}vless://$uuid@$ip:$port?path=/netsimon&security=none&encryption=none&type=ws#$nick${NC}"
    echo -e "${W}--------------------------------------------${NC}"
    read -p "Pressione ENTER para voltar..."
}

# Status Detalhado solicitado
status_detalhado() {
    clear
    echo -e "${C}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${C}║${W}           DETALHES TÉCNICOS DE REDE - XRAY           ${C}║${NC}"
    echo -e "${C}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e "${W}Portas Ativas no JSON:${NC}"
    jq -r '.inbounds[] | "-> Porta: \(.port) | Protocolo: \(.protocol) | Rede: \(.streamSettings.network)"' "$XRAY_CONF"
    echo -e "\n${W}Status Real da Porta (Netstat):${NC}"
    netstat -tpln | grep xray | awk '{print $4}'
    echo -e "\n${W}Processo:${NC} $(pgrep xray > /dev/null && echo -e "${G}ATIVO${NC}" || echo -e "${R}PARADO${NC}")"
    echo -e "${C}══════════════════════════════════════════════════════${NC}"
    read -p "Pressione ENTER para voltar..."
}

# Menu de Interface
clear
echo -e "${C} 1)${W} Instalar/Resetar Xray Core"
echo -e "${C} 2)${W} Configurar Portas (443 / 80+8080)"
echo -e "${C} 3)${W} Criar Novo Usuário"
echo -e "${C} 4)${W} Status Detalhado do Sistema"
echo -e "${C} 0)${W} Voltar ao Menu Principal"
echo -ne "\n${Y}Escolha: ${NC}"; read opt

case $opt in
    1) bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; gerar_config_enterprise ;;
    2) gerar_config_enterprise ;;
    3) add_user ;;
    4) status_detalhado ;;
    *) exit 0 ;;
esac
