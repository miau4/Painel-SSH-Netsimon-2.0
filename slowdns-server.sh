#!/bin/bash
# ==========================================
# Gerenciador SlowDNS - Netsimon 2.0 (LINK FIX)
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
    echo "   INSTALADOR SLOWDNS (LINK CORRIGIDO)   "
    echo "========================================="
    
    read -p "Digite seu NameServer (NS): " NS_DOMAIN
    [[ -z "$NS_DOMAIN" ]] && return

    echo -e "\n[1/4] Preparando ambiente..."
    apt-get update -y > /dev/null 2>&1
    apt-get install -y wget iptables libc6-i386 > /dev/null 2>&1

    systemctl stop slowdns > /dev/null 2>&1
    mkdir -p /etc/slowdns
    cd /etc/slowdns
    rm -f dnstt-server

    echo "[2/4] Baixando binário do repositório funcional..."
    # LINK CORRIGIDO: Apontando para a pasta /bin/ do repositório hidessh99
    wget --no-check-certificate -O dnstt-server "https://raw.githubusercontent.com/hidessh99/autoscript-ssh-slowdns/main/bin/dnstt-server"

    # Verifica se o arquivo baixado é válido (tamanho maior que 0)
    if [[ ! -s "dnstt-server" ]]; then
        echo -e "\e[1;31mErro: Download falhou (404 ou conexão).\e[0m"
        echo "Tentando link alternativo..."
        wget --no-check-certificate -O dnstt-server "https://raw.githubusercontent.com/hidessh99/autoscript-ssh-slowdns/main/dnstt-server"
    fi

    if [[ ! -s "dnstt-server" ]]; then
        echo -e "\e[1;31mErro Fatal: Não foi possível obter o binário.\e[0m"
        read -p "Pressione Enter..."
        return
    fi
    
    chmod +x dnstt-server

    echo "[3/4] Gerando Chaves..."
    # Executa a geração
    ./dnstt-server -gen > keys.txt 2>&1
    
    PUB_KEY=$(grep "Public key:" keys.txt | awk '{print $3}')
    PRIV_KEY=$(grep "Private key:" keys.txt | awk '{print $3}')

    if [[ -z "$PUB_KEY" ]]; then
        echo -e "\e[1;31mErro: O binário baixado não executou.\e[0m"
        echo "Saída do sistema:"
        cat keys.txt
        read -p "Pressione Enter..."
        return
    fi

    echo "$NS_DOMAIN" > /etc/slowdns/domain
    echo "$PUB_KEY" > /etc/slowdns/pub.key
    echo "$PRIV_KEY" > /etc/slowdns/priv.key

    echo "[4/4] Configurando Firewall e Serviço..."
    # Regras Oracle
    iptables -F
    iptables -t nat -F
    iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
    iptables -I INPUT -p udp --dport 53 -j ACCEPT
    iptables -I INPUT -p udp --dport 5353 -j ACCEPT

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

# (Menu principal simplificado para o teste)
while true; do
    clear
    echo "========================================="
    echo "         GERENCIADOR SLOWDNS             "
    echo "========================================="
    echo -e "Status: $(show_status)"
    [[ -f "/etc/slowdns/domain" ]] && echo -e "NS: \e[1;33m$(cat /etc/slowdns/domain)\e[0m"
    echo "========================================="
    echo "[1] Instalar / Reconfigurar"
    echo "[2] Ver Chaves"
    echo "[0] Sair"
    read -p "Opção: " opc
    case $opc in
        1) install_slowdns ;;
        2) clear; cat /etc/slowdns/pub.key 2>/dev/null || echo "Não instalado"; read -p "Enter..." ;;
        0) exit ;;
    esac
done
