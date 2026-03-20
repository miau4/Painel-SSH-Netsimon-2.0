#!/bin/bash
# XRAY MANAGER PRO - NETSIMON ENTERPRISE

CONF_DIR="/etc/xray"
CONF="$CONF_DIR/config.json"
CERT="$CONF_DIR/server.crt"
KEY="$CONF_DIR/server.key"
LOG_ACC="/var/log/xray/access.log"
LOG_ERR="/var/log/xray/error.log"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                 ⚡ XRAY CORE MANAGER PRO ⚡                  ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# Verificação de Status Detalhada
if systemctl is-active --quiet xray; then
    VER=$(xray version | head -n1 | awk '{print $2}')
    PORT=$(grep '"port"' "$CONF" 2>/dev/null | head -n 1 | awk '{print $2}' | sed 's/,//g')
    NET=$(grep '"network"' "$CONF" 2>/dev/null | head -n 1 | awk -F'"' '{print $4}')
    echo -e " Status: ${G}ONLINE${NC} | Versão: ${Y}$VER${NC}"
    echo -e " Porta: ${Y}${PORT:-N/A}${NC}   | Rede: ${Y}${NET:-N/A}${NC}"
else
    echo -e " Status: ${R}OFFLINE / NÃO INSTALADO${NC}"
fi
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"

menu_xray() {
    echo -e "${W} 1)${NC} Instalar Xray Core (VLESS + XHTTP + TLS)"
    echo -e "${W} 2)${NC} Alterar Porta de Conexão"
    echo -e "${W} 3)${NC} Ver Logs de Acesso (Tempo Real)"
    echo -e "${W} 4)${NC} Ver Erros do Sistema"
    echo -e "${W} 5)${NC} Reiniciar Serviço"
    echo -e "${W} 6)${NC} Parar Serviço"
    echo -e "${W} 7)${NC} Desinstalar Xray Completamente"
    echo -e "${W} 0)${NC} Voltar ao Menu Principal"
    echo -ne "\n${Y}Escolha uma opção: ${NC}"
    read op
}

install_xray() {
    clear
    echo -e "${C}[+] Verificando dependências do sistema...${NC}"
    apt update -y && apt install -y curl jq openssl socat &>/dev/null

    echo -e "${C}[+] Baixando Xray Core Oficial (Script XTLS)...${NC}"
    bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) &>/dev/null

    echo -e "${C}[+] Gerando Certificados TLS de 4096 bits (Autoassinados)...${NC}"
    mkdir -p "$CONF_DIR"
    mkdir -p /var/log/xray
    openssl req -x509 -newkey rsa:4096 -nodes -sha256 -days 3650 \
        -keyout "$KEY" -out "$CERT" \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=NetSimon/CN=9z6izazwwmq.map.azionedge.net" &>/dev/null
    chown -R nobody:nogroup /var/log/xray

    echo -ne "${Y}Informe a porta para o VLESS TLS (Padrão 443): ${NC}"
    read nport
    [[ -z "$nport" ]] && nport=443

    echo -e "${C}[+] Criando Configuração Otimizada (XHTTP)...${NC}"
    cat > "$CONF" <<EOF
{
  "log": {
    "access": "$LOG_ACC",
    "error": "$LOG_ERR",
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": $nport,
    "protocol": "vless",
    "settings": {
      "clients": [],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "xhttp",
      "security": "tls",
      "tlsSettings": {
        "certificates": [
          {
            "certificateFile": "$CERT",
            "keyFile": "$KEY"
          }
        ],
        "allowInsecure": true
      },
      "xhttpSettings": {
        "path": "/",
        "host": "9z6izazwwmq.map.azionedge.net",
        "mode": "auto"
      }
    }
  }],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {"domainStrategy": "UseIP"}
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "dns": {
    "servers": ["1.1.1.1", "8.8.8.8"]
  }
}
EOF
    systemctl daemon-reload
    systemctl enable xray
    systemctl restart xray
    
    if systemctl is-active --quiet xray; then
        echo -e "\n${G}✅ XRAY INSTALADO COM SUCESSO!${NC}"
        echo -e "${W}Porta:${Y} $nport${NC}"
        echo -e "${W}Transporte:${Y} XHTTP${NC}"
    else
        echo -e "\n${R}❌ Erro ao iniciar o Xray. Verifique os logs.${NC}"
    fi
    read -p "Pressione ENTER para continuar..."
}

case $op in
    1) install_xray ;;
    2)
        read -p "Informe a nova porta: " p_nova
        if [[ "$p_nova" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"port\": [0-9]*/\"port\": $p_nova/" "$CONF"
            systemctl restart xray
            echo -e "${G}Porta alterada com sucesso!${NC}"
        else
            echo -e "${R}Porta inválida.${NC}"
        fi
        sleep 2 ;;
    3) tail -f "$LOG_ACC" ;;
    4) tail -f "$LOG_ERR" ;;
    5) systemctl restart xray; echo -e "${G}Reiniciado.${NC}"; sleep 2 ;;
    6) systemctl stop xray; echo -e "${R}Parado.${NC}"; sleep 2 ;;
    7) 
        echo -ne "${R}Tem certeza que deseja remover? (s/n): ${NC}"
        read confirm
        if [[ "$confirm" == "s" ]]; then
            bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) remove --purge &>/dev/null
            rm -rf "$CONF_DIR"
            echo -e "${G}Xray removido completamente.${NC}"
        fi
        sleep 2 ;;
    0) exit 0 ;;
esac

menu_xray
