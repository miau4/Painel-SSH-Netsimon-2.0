#!/bin/bash

# Diretórios
CONF_DIR="/etc/xray"
CONF="$CONF_DIR/config.json"
CERT="$CONF_DIR/server.crt"
KEY="$CONF_DIR/server.key"

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                 ⚡ XRAY CORE MANAGER ⚡                      ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"

# Status Check
if systemctl is-active --quiet xray; then
    PORT=$(grep '"port"' "$CONF" 2>/dev/null | head -n 1 | awk '{print $2}' | sed 's/,//g')
    NET=$(grep '"network"' "$CONF" 2>/dev/null | head -n 1 | awk -F'"' '{print $4}')
    echo -e "${CYAN}║${NC} Status: ${GREEN}ONLINE${NC}  |  Porta: ${YELLOW}${PORT:-N/A}${NC}  |  Rede: ${YELLOW}${NET:-N/A}${NC}"
else
    echo -e "${CYAN}║${NC} Status: ${RED}OFFLINE / NÃO INSTALADO${NC}"
fi
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e "1) Instalar Xray Core (VLESS + XHTTP + TLS)"
echo -e "2) Alterar Porta"
echo -e "3) Parar Serviço Xray"
echo -e "4) Desinstalar Xray"
echo -e "0) Voltar"
echo -ne "\nEscolha: "
read op

case $op in
    1)
        clear
        echo -e "${CYAN}[+] Iniciando instalação autônoma do Xray...${NC}"
        
        # 1. Instala dependências básicas e o Core oficial
        apt update -y && apt install -y curl jq openssl
        bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
        
        # 2. Gera Certificado TLS Autoassinado (Obrigatório para o seu JSON)
        echo -e "${CYAN}[+] Gerando certificados TLS de alta segurança...${NC}"
        mkdir -p "$CONF_DIR"
        openssl req -x509 -newkey rsa:4096 -nodes -sha256 -days 3650 \
            -keyout "$KEY" -out "$CERT" \
            -subj "/C=BR/ST=SP/L=SaoPaulo/O=NetSimon/CN=9z6izazwwmq.map.azionedge.net" &>/dev/null
        
        # 3. Solicita a porta
        read -p "Digite a porta para o VLESS TLS (Padrão 443): " nport
        [[ -z "$nport" ]] && nport=443

        # 4. Gera o config.json perfeitamente compatível com o seu cliente (XHTTP)
        echo -e "${CYAN}[+] Configurando Servidor (XHTTP + TLS)...${NC}"
        cat > "$CONF" <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
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
          ]
        },
        "xhttpSettings": {
          "path": "/",
          "mode": "auto"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF
        # Permissões e Restart
        chown -R nobody:nogroup /var/log/xray
        systemctl daemon-reload
        systemctl enable xray
        systemctl restart xray
        
        echo -e "${GREEN}✅ Xray instalado e rodando na porta $nport com XHTTP/TLS!${NC}"
        read -p "ENTER para voltar..."
        ;;
    2)
        read -p "Nova Porta: " p_nova
        if [ -f "$CONF" ]; then
            sed -i "s/\"port\": [0-9]*/\"port\": $p_nova/" "$CONF"
            systemctl restart xray
            echo -e "${GREEN}Porta alterada para $p_nova!${NC}"
        else
            echo -e "${RED}Xray não configurado!${NC}"
        fi
        read -p "ENTER para voltar..."
        ;;
    3)
        systemctl stop xray
        echo -e "${YELLOW}Serviço Xray parado.${NC}"
        sleep 2
        ;;
    4)
        bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) remove --purge
        rm -rf /etc/xray
        echo -e "${RED}Xray removido do sistema!${NC}"
        sleep 2
        ;;
    0) exit 0 ;;
    *) echo -e "${RED}Opção inválida!${NC}"; sleep 1 ;;
esac
