#!/bin/bash

SERVICE="slowdns-server"
DIR="/etc/slowdns"
BIN="/usr/local/bin/dnstt-server"

# Cores para interface
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

pause() {
    echo -e "\n${YELLOW}Pressione ENTER para voltar ao menu...${NC}"
    read -p ""
}

install_slowdns() {
    clear
    echo -e "${CYAN}=== CONFIGURAÇÃO SLOWDNS (DNSTT) ===${NC}"

    # Coleta de dados
    read -p "Domínio/NS (ex: ns-br.meudominio.com): " NS
    if [[ -z "$NS" ]]; then
        echo -e "${RED}Erro: O NameServer (NS) é obrigatório!${NC}"
        pause
        return
    fi

    read -p "Porta UDP para o SlowDNS (Padrão 5300): " PORT
    [[ -z "$PORT" ]] && PORT=5300

    read -p "Porta local para encaminhar (SSH Padrão 22): " LPORT
    [[ -z "$LPORT" ]] && LPORT=22

    # Instalação de dependências
    echo -e "\n${YELLOW}Instalando dependências e compilando (isso pode demorar)...${NC}"
    apt update -y && apt install git golang curl -y

    # Download e Build do DNSTT
    if [ ! -f "$BIN" ]; then
        cd /tmp || exit
        rm -rf dnstt
        git clone https://www.bamsoftware.com/git/dnstt.git
        cd dnstt/dnstt-server || exit
        go build
        mv dnstt-server $BIN
        chmod +x $BIN
    fi

    # Configuração de chaves
    mkdir -p $DIR
    cd $DIR || exit
    $BIN -gen-key -privkey-file server.priv -pubkey-file server.pub > /dev/null 2>&1
    
    PRIV_KEY=$(cat server.priv)
    PUB_KEY=$(cat server.pub)

    # Criação do Serviço Systemd
    cat > /etc/systemd/system/${SERVICE}.service <<EOF
[Unit]
Description=SlowDNS DNSTT Server
After=network.target

[Service]
Type=simple
ExecStart=$BIN -udp :$PORT -privkey-file $DIR/server.priv -pubkey-file $DIR/server.pub $NS 127.0.0.1:$LPORT
Restart=always
RestartSec=3
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF

    # Inicialização
    systemctl daemon-reload
    systemctl enable $SERVICE
    systemctl restart $SERVICE

    sleep 2

    if systemctl is-active --quiet $SERVICE; then
        IP=$(curl -s ifconfig.me)
        clear
        echo -e "${GREEN}==============================================="
        echo -e "       SLOWDNS INSTALADO COM SUCESSO!          "
        echo -e "===============================================${NC}"
        echo -e "${CYAN}NS (NameServer):${NC} $NS"
        echo -e "${CYAN}Porta UDP:      ${NC} $PORT"
        echo -e "${CYAN}Chave Pública:  ${NC} $PUB_KEY"
        echo -e "${CYAN}IP do Servidor: ${NC} $IP"
        echo -e "${GREEN}==============================================="
        echo -e "${YELLOW}Dica: No App, use a porta 53 ou 5300 dependendo"
        echo -e "do seu encaminhamento de porta no Cloudflare/DNS.${NC}"
    else
        echo -e "${RED}Erro: O serviço não subiu. Verifique as portas.${NC}"
    fi
}

status_slowdns() {
    clear
    echo -e "${CYAN}=== STATUS DO SERVIÇO ===${NC}"
    systemctl status $SERVICE --no-pager
}

restart_slowdns() {
    systemctl restart $SERVICE
    echo -e "${GREEN}Serviço reiniciado!${NC}"
}

remove_slowdns() {
    systemctl stop $SERVICE
    systemctl disable $SERVICE
    rm -f /etc/systemd/system/${SERVICE}.service
    rm -rf $DIR
    systemctl daemon-reload
    echo -e "${RED}SlowDNS removido completamente.${NC}"
}

# MENU
while true; do
    clear
    echo -e "${CYAN}========== NETSIMON 2.0 - SLOWDNS ==========${NC}"
    echo -e "${WHITE}1)${NC} Instalar/Configurar SlowDNS"
    echo -e "${WHITE}2)${NC} Ver Status"
    echo -e "${WHITE}3)${NC} Reiniciar Serviço"
    echo -e "${WHITE}4)${NC} Remover SlowDNS"
    echo -e "${WHITE}0)${NC} Voltar ao Menu Principal"
    echo -e "${CYAN}============================================${NC}"
    read -p "Escolha uma opção: " op

    case $op in
        1) install_slowdns; pause ;;
        2) status_slowdns; pause ;;
        3) restart_slowdns; pause ;;
        4) remove_slowdns; pause ;;
        0) break ;;
        *) echo -e "${RED}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
