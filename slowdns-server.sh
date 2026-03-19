#!/bin/bash

SERVICE="slowdns-server"
DIR="/etc/slowdns"

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

pause() {
    read -p "Pressione ENTER..."
}

install_slowdns() {
    clear
    echo "=== INSTALAÇÃO SLOWDNS ==="

    read -p "Domínio (ex: dominio.com): " DOMAIN
    read -p "Subdomínio NS (ex: ns1): " SUB
    read -p "Porta UDP (recomendado 5300): " PORT

    [[ -z "$PORT" ]] && PORT=5300

    NS="${SUB}.${DOMAIN}"

    if [[ -z "$DOMAIN" || -z "$SUB" ]]; then
        echo -e "${RED}Dados inválidos!${NC}"
        pause
        return
    fi

    # Dependências
    apt update -y
    apt install git golang curl -y

    # Build apenas se não existir
    if [ ! -f /usr/local/dnstt-server ]; then
        cd /usr/local || exit

        rm -rf dnstt
        git clone https://www.bamsoftware.com/git/dnstt.git

        cd dnstt/dnstt-server || exit
        go build -o /usr/local/dnstt-server

        chmod +x /usr/local/dnstt-server
    fi

    mkdir -p $DIR

    /usr/local/dnstt-server -gen-key > $DIR/key.txt

    PRIVATE_KEY=$(grep PRIVATE $DIR/key.txt | awk '{print $2}')
    PUBLIC_KEY=$(grep PUBLIC $DIR/key.txt | awk '{print $2}')

    echo "$PRIVATE_KEY" > $DIR/private.key
    echo "$PUBLIC_KEY" > $DIR/public.key

    cat > /etc/systemd/system/${SERVICE}.service <<EOF
[Unit]
Description=SlowDNS Server
After=network.target

[Service]
ExecStart=/usr/local/dnstt-server \
-udp :$PORT \
-privkey-file $DIR/private.key \
-ns $NS

Restart=always
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable $SERVICE
    systemctl restart $SERVICE

    sleep 2

    if systemctl is-active --quiet $SERVICE; then
        IP=$(curl -s ifconfig.me)

        echo ""
        echo -e "${GREEN}SLOWDNS ATIVO!${NC}"
        echo -e "${CYAN}NS:${NC} $NS"
        echo -e "${CYAN}IP:${NC} $IP"
        echo -e "${CYAN}PORTA:${NC} $PORT"
        echo -e "${CYAN}PUBLIC KEY:${NC}"
        echo "$PUBLIC_KEY"
    else
        echo -e "${RED}Erro ao iniciar SlowDNS${NC}"
    fi
}

status_slowdns() {
    systemctl status $SERVICE --no-pager
}

restart_slowdns() {
    systemctl restart $SERVICE
    echo "Reiniciado!"
}

remove_slowdns() {
    systemctl stop $SERVICE
    systemctl disable $SERVICE

    rm -f /etc/systemd/system/${SERVICE}.service
    rm -rf $DIR

    systemctl daemon-reload

    echo "Removido!"
}

# MENU
while true; do
clear
echo "========== SLOWDNS MANAGER =========="
echo "1) Instalar SlowDNS"
echo "2) Status"
echo "3) Reiniciar"
echo "4) Remover"
echo "0) Voltar"
echo "====================================="
read -p "Escolha: " op

case $op in
1) install_slowdns; pause ;;
2) status_slowdns; pause ;;
3) restart_slowdns; pause ;;
4) remove_slowdns; pause ;;
0) break ;;
*) echo "Inválido"; sleep 1 ;;
esac

done
