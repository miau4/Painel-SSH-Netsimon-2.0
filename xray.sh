#!/bin/bash
# ==========================================
#  NETSIMON ENTERPRISE - XRAY XHTTP 7.5
# ==========================================

# Caminhos do Sistema
XRAY_CONF="/etc/xray/config.json"
SSL_DIR="/etc/xray-manager/ssl"
BIN_XRAY=$(which xray)

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; M='\033[1;35m'; NC='\033[0m'
BG_G='\033[42m'; BG_R='\033[41m'

draw_status() {
    local status_text=""
    if systemctl is-active --quiet xray; then
        status_text="${BG_G}${W} ONLINE ${NC}"
    else
        status_text="${BG_R}${W} OFFLINE ${NC}"
    fi
    local port=$(jq -r '.inbounds[0].port' "$XRAY_CONF" 2>/dev/null || echo "443")
    local host=$(jq -r '.inbounds[0].streamSettings.xhttpSettings.host' "$XRAY_CONF" 2>/dev/null || echo "Azion")
    echo -e "${M}────────────────────────────────────────────────────────────${NC}"
    echo -e " STATUS: $status_text  ${W}|${NC} PORTA: ${G}$port${NC}  ${W}|${NC} HOST: ${Y}${host:0:15}...${NC}"
    echo -e "${M}────────────────────────────────────────────────────────────${NC}"
}

setup_xray() {
    clear
    echo -e "${C}⚙️  Otimizando Handshake e Bypass DNS...${NC}"
    mkdir -p /etc/xray
    apt update && apt install jq openssl curl ufw cron -y &>/dev/null
    
    # Gerar Certificado SSL
    mkdir -p "$SSL_DIR"
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -subj "/C=BR/ST=SP/L=SaoPaulo/O=NetSimon/CN=www.tim.com.br" \
    -keyout "$SSL_DIR/privkey.pem" -out "$SSL_DIR/fullchain.pem" &>/dev/null
    chmod 644 "$SSL_DIR/privkey.pem" "$SSL_DIR/fullchain.pem"

    # Configuração Mestra: Forçando Resolução no Servidor (Elimina erro de DNS no log)
    cat <<EOF > "$XRAY_CONF"
{
  "log": { "loglevel": "warning" },
  "dns": {
    "servers": ["localhost"]
  },
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": { "clients": [], "decryption": "none" },
    "streamSettings": {
      "network": "xhttp",
      "security": "tls",
      "xhttpSettings": { 
        "path": "/", 
        "host": "idglokgvu4k.map.azionedge.net", 
        "mode": "packet" 
      },
      "tlsSettings": {
        "serverName": "www.tim.com.br",
        "allowInsecure": true,
        "certificates": [{ "certificateFile": "$SSL_DIR/fullchain.pem", "keyFile": "$SSL_DIR/privkey.pem" }]
      }
    },
    "sniffing": { 
      "enabled": true, 
      "destOverride": ["http", "tls", "quic"],
      "metadataOnly": false
    }
  }],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": { "domainStrategy": "UseIP" },
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      { "type": "field", "ip": ["geoip:private"], "outboundTag": "block" },
      { "type": "field", "protocol": ["bittorrent"], "outboundTag": "block" }
    ]
  }
}
EOF
    
    # Auto-Reparo (Watchdog)
    echo "* * * * * root if ! systemctl is-active --quiet xray; then systemctl restart xray; fi" > /etc/cron.d/xray_watchdog
    
    systemctl daemon-reload
    systemctl restart xray
    echo -e "${G}✅ Sincronizado com Sucesso!${NC}"
    sleep 2
}

add_user() {
    clear
    draw_status
    echo -ne "${W}👤 Nome do Usuário: ${NC}"; read nick
    [ -z "$nick" ] && return
    echo -ne "${W}📅 Dias de Validade: ${NC}"; read dias
    [ -z "$dias" ] && dias=30
    
    uuid=$(cat /proc/sys/kernel/random/uuid)
    exp_date=$(date -d "+$dias days" +%d/%m/%Y)
    
    # Inserir Usuário no JSON
    jq --arg id "$uuid" --arg em "$nick | EXP: $exp_date" '.inbounds[0].settings.clients += [{"id": $id, "email": $em}]' "$XRAY_CONF" > "$XRAY_CONF.tmp"

    if jq . "$XRAY_CONF.tmp" >/dev/null 2>&1; then
        mv "$XRAY_CONF.tmp" "$XRAY_CONF"
        systemctl restart xray
        
        local host_ext=$(jq -r '.inbounds[0].streamSettings.xhttpSettings.host' "$XRAY_CONF")
        local porta=$(jq -r '.inbounds[0].port' "$XRAY_CONF")
        
        echo -e "${G}✅ USUÁRIO CRIADO!${NC}"
        echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${Y}VLESS XHTTP:${NC}"
        echo -e "${C}vless://$uuid@m.ofertas.tim.com.br:$porta?encryption=none&flow=none&type=xhttp&host=$host_ext&headerType=auto&path=%2F&security=tls&sni=www.tim.com.br#$nick${NC}"
        echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${R}❌ Erro ao salvar usuário.${NC}"
    fi
    read -p "ENTER para voltar..."
}

while true; do
    clear
    echo -e "${C}  🛰️  NETSIMON ENTERPRISE - XRAY XHTTP${NC}"
    draw_status
    echo -e " ${G}[1]${NC} INSTALAR / RECONFIGURAR XRAY"
    echo -e " ${G}[2]${NC} CRIAR NOVO USUÁRIO"
    echo -e " ${M}────────────────────────────────────────────────────────────${NC}"
    echo -e " ${Y}[3]${NC} 🔄 REINICIAR"
    echo -e " ${Y}[4]${NC} 🛑 PARAR"
    echo -e " ${Y}[5]${NC} 🌐 MUDAR HOST"
    echo -e " ${Y}[6]${NC} 🔌 MUDAR PORTA"
    echo -e " ${R}[0]${NC} SAIR"
    echo -e "${M}────────────────────────────────────────────────────────────${NC}"
    echo -ne " Escolha: "; read opt
    case $opt in
        1) setup_xray ;;
        2) add_user ;;
        3) systemctl restart xray && echo -e "${G}OK!${NC}" && sleep 1 ;;
        4) systemctl stop xray && echo -e "${R}OK!${NC}" && sleep 1 ;;
        5) 
            echo -ne "Novo Host: "; read nhost
            jq --arg h "$nhost" '.inbounds[0].streamSettings.xhttpSettings.host = $h' "$XRAY_CONF" > "$XRAY_CONF.tmp" && mv "$XRAY_CONF.tmp" "$XRAY_CONF"
            systemctl restart xray
        ;;
        6)
            echo -ne "Nova Porta: "; read nport
            jq --argjson p "$nport" '.inbounds[0].port = $p' "$XRAY_CONF" > "$XRAY_CONF.tmp" && mv "$XRAY_CONF.tmp" "$XRAY_CONF"
            ufw allow "$nport"/tcp && systemctl restart xray
        ;;
        0) exit 0 ;;
    esac
done
