#!/bin/bash

# Caminhos e Cores
NGINX_CONF="/etc/nginx/conf.d/websocket.conf"
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

pause() {
    echo -e "\n${YELLOW}Pressione ENTER para voltar...${NC}"
    read -p ""
}

install_ws() {
    clear
    echo -e "${CYAN}=== INSTALAÇÃO WEBSOCKET (NGINX PROXY) ===${NC}"

    # Coleta de Dados
    read -p "Domínio ou IP: " DOMAIN
    [[ -z "$DOMAIN" ]] && { echo -e "${RED}Erro: Domínio obrigatório!${NC}"; pause; return; }

    read -p "Porta que o WebSocket vai usar (Ex: 80): " WSPORT
    [[ -z "$WSPORT" ]] && WSPORT=80

    read -p "Porta do serviço de destino (SSH=22 ou porta do Xray/Python): " BPORT
    [[ -z "$BPORT" ]] && BPORT=22

    read -p "Caminho (Path) do WebSocket (Padrão: /ws): " WSPATH
    [[ -z "$WSPATH" ]] && WSPATH="/ws"

    # Instalação
    echo -e "\n${YELLOW}Instalando Nginx e JQ...${NC}"
    apt update -y && apt install nginx jq -y

    # Remover config default que costuma causar conflito na porta 80
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-available/default

    # Criando configuração do Nginx
    cat > $NGINX_CONF <<EOF
server {
    listen $WSPORT;
    server_name $DOMAIN;

    location $WSPATH {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:$BPORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        # Timeout longo para conexões SSH não caírem
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
EOF

    # Testar e Reiniciar
    nginx -t &>/dev/null
    if [[ $? -eq 0 ]]; then
        systemctl restart nginx
        systemctl enable nginx
        clear
        echo -e "${GREEN}==============================================="
        echo -e "       WEBSOCKET CONFIGURADO COM SUCESSO!      "
        echo -e "===============================================${NC}"
        echo -e "${CYAN}Domínio/IP:${NC} $DOMAIN"
        echo -e "${CYAN}Porta WS:  ${NC} $WSPORT"
        echo -e "${CYAN}Path WS:   ${NC} $WSPATH"
        echo -e "${CYAN}Destino:   ${NC} 127.0.0.1:$BPORT"
        echo -e "${GREEN}==============================================="
    else
        echo -e "${RED}Erro na configuração do Nginx! Verifique se a porta $WSPORT já está em uso.${NC}"
        rm -f $NGINX_CONF
    fi
}

restart_nginx() {
    systemctl restart nginx
    echo -e "${GREEN}Nginx reiniciado com sucesso!${NC}"
}

remove_ws() {
    rm -f $NGINX_CONF
    systemctl restart nginx
    echo -e "${RED}Configuração WebSocket removida.${NC}"
}

# MENU
while true; do
    clear
    echo -e "${CYAN}========== NETSIMON 2.0 - WEBSOCKET ==========${NC}"
    echo -e "${WHITE}1)${NC} Instalar/Configurar WebSocket"
    echo -e "${WHITE}2)${NC} Reiniciar Nginx"
    echo -e "${WHITE}3)${NC} Remover WebSocket"
    echo -e "${WHITE}0)${NC} Voltar"
    echo -e "${CYAN}============================================${NC}"
    read -p "Escolha: " op

    case $op in
        1) install_ws; pause ;;
        2) restart_nginx; pause ;;
        3) remove_ws; pause ;;
        0) break ;;
        *) echo -e "${RED}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
