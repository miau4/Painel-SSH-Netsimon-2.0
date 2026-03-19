#!/bin/bash

CONFIG="/etc/xray/config.json"

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

pause() {
    read -p "Pressione ENTER..."
}

get_xray_port() {
    jq -r '.inbounds[0].port' $CONFIG 2>/dev/null
}

install_ws() {
    clear
    echo "=== WEBSOCKET SETUP ==="

    read -p "Domínio: " DOMAIN

    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Domínio inválido!${NC}"
        pause
        return
    fi

    PORT=$(get_xray_port)

    if [[ -z "$PORT" ]]; then
        echo -e "${RED}Xray não configurado!${NC}"
        pause
        return
    fi

    apt update -y
    apt install nginx jq -y

    mkdir -p /etc/nginx/sites-enabled

    cat > /etc/nginx/sites-enabled/ws.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /ws {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;

        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

    nginx -t || {
        echo -e "${RED}Erro na configuração do Nginx!${NC}"
        pause
        return
    }

    systemctl restart nginx
    systemctl enable nginx

    echo -e "${GREEN}WebSocket ativo!${NC}"
    echo -e "${CYAN}URL:${NC} http://$DOMAIN/ws"
}

restart_nginx() {
    systemctl restart nginx
    echo "Nginx reiniciado"
}

remove_ws() {
    rm -f /etc/nginx/sites-enabled/ws.conf
    systemctl restart nginx
    echo "WebSocket removido"
}

# MENU
while true; do
clear
echo "========== WEBSOCKET MANAGER =========="
echo "1) Instalar WebSocket"
echo "2) Reiniciar Nginx"
echo "3) Remover WebSocket"
echo "0) Voltar"
echo "======================================="
read -p "Escolha: " op

case $op in
1) install_ws; pause ;;
2) restart_nginx; pause ;;
3) remove_ws; pause ;;
0) break ;;
*) echo "Inválido"; sleep 1 ;;
esac

done
