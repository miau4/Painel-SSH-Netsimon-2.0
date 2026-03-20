#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - XRAY MANAGER 2.2
# ==========================================

XRAY_CONF="/usr/local/etc/xray/config.json"
SSL_DIR="/etc/xray-manager/ssl"
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

status_detalhado() {
    clear
    echo -e "${C}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${C}║${W}           DETALHES TÉCNICOS DE REDE - XRAY           ${C}║${NC}"
    echo -e "${C}╚══════════════════════════════════════════════════════╝${NC}"
    
    echo -e "${W}Protocolos e Portas Ativas:${NC}"
    # Mapeia o JSON para mostrar Porta -> Protocolo -> Path
    jq -r '.inbounds[] | "Porta: \(.port) | Protocolo: \(.protocol) | Stream: \(.streamSettings.network)"' "$XRAY_CONF"
    
    echo -e "\n${W}Status do Processo:${NC}"
    pgrep xray > /dev/null && echo -e "${G}CORE ATIVO${NC}" || echo -e "${R}CORE PARADO${NC}"
    echo -e "${C}══════════════════════════════════════════════════════${NC}"
    read -p "Pressione ENTER para voltar..."
}

gerar_config_enterprise() {
    clear
    echo -e "${W}Selecione a Configuração de Porta para WebSocket/VLESS:${NC}"
    echo -e "1) Padrão Seguro (Porta 443 + Interna 1080)"
    echo -e "2) Padrão HTTP (Portas 80 e 8080 Simultâneas)"
    echo -e "3) Personalizada"
    echo -ne "\nEscolha: "; read p_opt

    case $p_opt in
        1) 
            # Inbound 443 (Externo) redirecionando internamente se necessário
            inbounds='{ "port": 443, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "'$SSL_DIR'/fullchain.pem", "keyFile": "'$SSL_DIR'/privkey.pem" }] } } }'
            ;;
        2)
            # Inbound 80 e 8080 Simultâneos (WebSocket/HTTP)
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
