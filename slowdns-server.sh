#!/bin/bash
# ==========================================
# Gerenciador SlowDNS - Netsimon 2.0 (ORACLE EDITION)
# ==========================================

show_status() {
    if systemctl is-active --quiet slowdns; then
        echo -e "\e[1;32m[ATIVO]\e[0m"
    else
        echo -e "\e[1;31m[PARADO / NÃO INSTALADO]\e[0m"
    fi
}

install_slowdns() {
    clear
    echo "========================================="
    echo "   INSTALADOR SLOWDNS (ORACLE CLOUD)     "
    echo "========================================="
    
    read -p "Digite seu NameServer (NS): " NS_DOMAIN
    [[ -z "$NS_DOMAIN" ]] && return

    echo -e "\n[1/4] Abrindo Firewall da Oracle..."
    # Comando vital para Oracle: limpa as regras que bloqueiam portas DNS
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # Instalar dependências de execução
    apt-get update -y > /dev/null 2>&1
    apt-get install -y wget iptables cron dnsutils -y > /dev/null 2>&1

    echo "[2/4] Baixando Binário..."
    systemctl stop slowdns > /dev/null 2>&1
    mkdir -p /etc/slowdns
    # Download do binário que funciona no Ubuntu 22.04
    wget -q -O /etc/slowdns/dnstt-server "https://github.com/miau4/Painel-SSH-Netsimon-2.0/raw/main/dnstt-server" || \
    wget -q -O /etc/slowdns/dnstt-server "https://raw.githubusercontent.com/hidessh99/autoscript-ssh-slowdns/main/dnstt-server"
    
    chmod 777 /etc/slowdns/dnstt-server

    echo "[3/4] Gerando Chaves..."
    cd /etc/slowdns
    # Forçar a geração ignorando erros de ambiente
    ./dnstt-server -gen > keys.txt 2>&1
    
    PUB_KEY=$(grep "Public key:" keys.txt | awk '{print $3}')
    PRIV_KEY=$(grep "Private key:" keys.txt | awk '{print $3}')

    if [[ -z "$PUB_KEY" ]]; then
        echo -e "\e[1;31mErro: Não foi possível executar o binário.\e[0m"
        echo "Tentando baixar binário alternativo..."
        wget -q -O /etc/slowdns/dnstt-server "https://github.com/miau4/Painel-SSH-Netsimon-2.0/raw/main/dnstt-server"
        chmod +x /etc/slowdns/dnstt-server
        ./dnstt-server -gen > keys.txt 2>&1
        PUB_KEY=$(grep "Public key:" keys.txt | awk '{print $3}')
    fi

    echo "$NS_DOMAIN" > /etc/slowdns/domain
    echo "$PUB_KEY" > /etc/slowdns/pub.key
    echo "$PRIV_KEY" > /etc/slowdns/priv.key

    echo "[4/4] Ativando Serviço..."
    cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=SlowDNS Netsimon
After=network.target

[Service]
Type=simple
User=root
ExecStart=/etc/slowdns/dnstt-server -udp :5353 -privkey-file /etc/slowdns/priv.key $NS_DOMAIN 127.0.0.1:22
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Regras de Redirecionamento
    iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
    iptables -I INPUT -p udp --dport 53 -j ACCEPT
    
    systemctl daemon-reload
    systemctl enable slowdns > /dev/null 2>&1
    systemctl start slowdns

    clear
    echo "========================================="
    echo "       SLOWDNS INSTALADO COM SUCESSO!    "
    echo "========================================="
    echo -e "Status          : $(show_status)"
    echo -e "NameServer (NS) : \e[1;33m$NS_DOMAIN\e[0m"
    echo -e "Chave Pública   : \e[1;33m$PUB_KEY\e[0m"
    echo "========================================="
    read -p "Pressione [Enter] para voltar..."
}

# --- O RESTANTE DO MENU CONTINUA IGUAL ---
while true; do
    clear
    echo "========================================="
    echo "         GERENCIADOR SLOWDNS             "
    echo "========================================="
    echo -e "Status: $(show_status)"
    [[ -f "/etc/slowdns/domain" ]] && echo -e "NS: \e[1;33m$(cat /etc/slowdns/domain)\e[0m"
    echo "========================================="
    echo "[1] Instalar / Reconfigurar"
    echo "[2] Ver Chaves e Dados"
    echo "[3] Desinstalar"
    echo "[0] Sair"
    read -p "Opção: " opc
    case $opc in
        1) install_slowdns ;;
        2) 
            clear
            if [ -f "/etc/slowdns/pub.key" ]; then
                echo "NS: $(cat /etc/slowdns/domain)"
                echo "Key: $(cat /etc/slowdns/pub.key)"
            fi
            read -p "Enter..." ;;
        3) systemctl stop slowdns; rm -rf /etc/slowdns; echo "Removido."; sleep 2 ;;
        0) exit ;;
    esac
done
