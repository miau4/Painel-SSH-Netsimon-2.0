#!/bin/bash
# ==========================================
# Gerenciador SlowDNS - Netsimon 2.0 (FIX UBUNTU 22)
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
    echo "   INSTALADOR SLOWDNS (ULTRA FIX)        "
    echo "========================================="
    
    read -p "Digite seu NameServer (NS): " NS_DOMAIN
    [[ -z "$NS_DOMAIN" ]] && return

    echo -e "\n[1/4] Preparando bibliotecas e Firewall..."
    # Abre o firewall da Oracle internamente
    iptables -F > /dev/null 2>&1
    iptables -P INPUT ACCEPT > /dev/null 2>&1
    
    # Instala bibliotecas que binários antigos do DNSTT precisam
    apt-get update -y > /dev/null 2>&1
    apt-get install -y wget iptables libc6-i386 lib32z1 > /dev/null 2>&1

    echo "[2/4] Baixando Binário Oficial do Projeto..."
    systemctl stop slowdns > /dev/null 2>&1
    mkdir -p /etc/slowdns
    cd /etc/slowdns
    rm -f dnstt-server
    
    # Download direto do binário do autoscript funcional que você passou
    wget --no-check-certificate -O dnstt-server "https://raw.githubusercontent.com/hidessh99/autoscript-ssh-slowdns/main/dnstt-server"
    
    if [[ ! -s "dnstt-server" ]]; then
        echo "Erro: Falha no download do binário. Verifique sua conexão."
        read -p "Pressione Enter..."
        return
    fi
    
    chmod +x dnstt-server

    echo "[3/4] Gerando Chaves..."
    # Tenta rodar o binário. Se der erro aqui, é incompatibilidade de arquitetura.
    ./dnstt-server -gen > keys.txt 2>&1
    
    PUB_KEY=$(grep "Public key:" keys.txt | awk '{print $3}')
    PRIV_KEY=$(grep "Private key:" keys.txt | awk '{print $3}')

    if [[ -z "$PUB_KEY" ]]; then
        echo -e "\e[1;31mErro Crítico: O binário baixado não conseguiu rodar nesta VPS.\e[0m"
        echo "A saída do erro foi:"
        cat keys.txt
        read -p "Pressione Enter para ver o que fazer..."
        return
    fi

    echo "$NS_DOMAIN" > /etc/slowdns/domain
    echo "$PUB_KEY" > /etc/slowdns/pub.key
    echo "$PRIV_KEY" > /etc/slowdns/priv.key

    echo "[4/4] Configurando Serviço e Redirecionamento..."
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

    # Redirecionamento da porta 53 para a 5353 (onde o DNSTT ouve)
    iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
    iptables -I INPUT -p udp --dport 53 -j ACCEPT
    iptables -I INPUT -p udp --dport 5353 -j ACCEPT

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

# (O resto do menu permanece igual...)
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
