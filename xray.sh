#!/bin/bash

CONFIG="/etc/xray/config.json"
USERS_FILE="/etc/xray/users.txt"

# Cores
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

pause() {
    echo -e "\n${YELLOW}Pressione ENTER para voltar...${NC}"
    read -p ""
}

install_xray() {
    clear
    echo -e "${CYAN}=== INSTALAÇÃO XRAY CORE ===${NC}"
    
    # Instala JQ se não houver
    apt update && apt install jq curl -y

    if command -v xray >/dev/null; then
        echo -e "${GREEN}Xray já está instalado.${NC}"
    else
        echo -e "${YELLOW}Baixando e instalando Xray oficial...${NC}"
        bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
    fi
    pause
}

generate_config() {
    clear
    echo -e "${CYAN}=== GERAR CONFIGURAÇÃO BASE ===${NC}"
    
    read -p "Porta para o Xray (Padrão 443): " PORT
    [[ -z "$PORT" ]] && PORT=443

    read -p "Caminho/Path WS (Padrão /xrayws): " WS_PATH
    [[ -z "$WS_PATH" ]] && WS_PATH="/xrayws"

    mkdir -p /etc/xray /var/log/xray
    touch $USERS_FILE

    cat > "$CONFIG" <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$WS_PATH"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

    systemctl restart xray
    echo -e "${GREEN}Configuração base criada na porta $PORT com Path $WS_PATH!${NC}"
    echo -e "${YELLOW}Nota: O Xray está ouvindo apenas localmente (127.0.0.1).${NC}"
    echo -e "${YELLOW}Use o script de WebSocket (Nginx) para dar acesso externo.${NC}"
}

add_user() {
    clear
    echo -e "${CYAN}=== ADICIONAR NOVO USUÁRIO VLESS ===${NC}"
    
    if [ ! -f "$CONFIG" ]; then
        echo -e "${RED}Erro: Gere a Config Base primeiro (Opção 2).${NC}"
        return
    fi

    read -p "Nome do usuário (apenas para registro): " USERNAME
    [[ -z "$USERNAME" ]] && USERNAME="user_$(date +%s)"
    
    UUID=$(xray uuid)
    tmp=$(mktemp)

    # Adiciona o cliente ao JSON usando JQ
    jq --arg uuid "$UUID" --arg email "$USERNAME" \
    '.inbounds[0].settings.clients += [{"id": $uuid, "email": $email}]' \
    "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"

    echo "User: $USERNAME | UUID: $UUID | Date: $(date)" >> $USERS_FILE
    
    systemctl restart xray
    
    echo -e "${GREEN}Usuário adicionado com sucesso!${NC}"
    echo -e "${CYAN}UUID:${NC} $UUID"
    echo -e "${CYAN}Protocolo:${NC} VLESS-WS"
}

remove_xray() {
    echo -e "${RED}Removendo Xray e configurações...${NC}"
    systemctl stop xray
    systemctl disable xray
    bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) --remove
    rm -rf /etc/xray
    rm -f /etc/systemd/system/xray.service
    echo -e "${GREEN}Xray removido.${NC}"
}

# MENU
while true; do
    clear
    echo -e "${CYAN}========== NETSIMON 2.0 - XRAY MANAGER ==========${NC}"
    echo -e "${WHITE}1)${NC} Instalar Xray Core"
    echo -e "${WHITE}2)${NC} Configurar Porta/Protocolo (Base)"
    echo -e "${WHITE}3)${NC} Criar Novo Usuário (UUID)"
    echo -e "${WHITE}4)${NC} Reiniciar Xray"
    echo -e "${WHITE}5)${NC} Ver Status"
    echo -e "${WHITE}6)${NC} Desinstalar Xray"
    echo -e "${WHITE}0)${NC} Voltar"
    echo -e "${CYAN}=================================================${NC}"
    read -p "Escolha: " op

    case $op in
        1) install_xray ;;
        2) generate_config; pause ;;
        3) add_user; pause ;;
        4) systemctl restart xray; echo "Reiniciado"; sleep 1 ;;
        5) systemctl status xray --no-pager; pause ;;
        6) remove_xray; pause ;;
        0) break ;;
        *) echo "Opção inválida"; sleep 1 ;;
    esac
done
