#!/bin/bash
# ==========================================
# Gerenciador SlowDNS (DNSTT) - Netsimon 2.0
# Corrigido: Verificação de Binário e Chaves
# ==========================================

show_status() {
    if systemctl is-active --quiet slowdns; then
        echo -e "\e[1;32m[ATIVO]\e[0m"
    else
        echo -e "\e[1;31m[PARADO / NÃO INSTALADO]\e[0m"
    fi
}

view_info() {
    clear
    echo "========================================="
    echo "       INFORMAÇÕES DO SLOWDNS            "
    echo "========================================="
    if [ -f "/etc/slowdns/pub.key" ]; then
        PUB_KEY=$(cat /etc/slowdns/pub.key)
        NS_DOMAIN=$(cat /etc/slowdns/domain)
        echo -e "Status         : $(show_status)"
        echo -e "NameServer (NS): \e[1;33m$NS_DOMAIN\e[0m"
        echo -e "Chave Pública  : \e[1;33m$PUB_KEY\e[0m"
    else
        echo "O SlowDNS ainda não foi configurado corretamente."
    fi
    echo "========================================="
    read -p "Pressione [Enter] para voltar..."
}

install_slowdns() {
    clear
    echo "========================================="
    echo "   INSTALADOR SLOWDNS (DNSTT) NETSIMON   "
    echo "========================================="
    
    read -p "Digite seu NameServer (NS): " NS_DOMAIN
    [[ -z "$NS_DOMAIN" ]] && return

    echo -e "\n[1/5] Preparando ambiente..."
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y iptables wget coreutils > /dev/null 2>&1

    # Parar tudo antes de mexer
    systemctl stop slowdns > /dev/null 2>&1
    rm -rf /etc/slowdns && mkdir -p /etc/slowdns

    echo "[2/5] Baixando binário universal..."
    # Usando o binário oficial do projeto DNSTT para garantir compatibilidade
    cd /usr/local/bin
    rm -f dnstt-server
    
    # Tenta baixar o binário estável
    wget -q -O dnstt-server "https://github.com/miau4/Painel-SSH-Netsimon-2.0/raw/main/dnstt-server" || \
    wget -q -O dnstt-server "https://raw.githubusercontent.com/hidessh99/autoscript-ssh-slowdns/main/dnstt-server"
    
    chmod +x dnstt-server

    # Verificação crítica: o binário funciona?
    if ! ./dnstt-server -h > /dev/null 2>&1; then
        echo -e "\e[1;31mErro Crítico: O binário dnstt-server não é compatível com sua VPS.\e[0m"
        read -p "Pressione Enter..."
        return
    fi

    echo "[3/5] Gerando chaves..."
    cd /etc/slowdns
    /usr/local/bin/dnstt-server -gen > keys.txt 2>&1
    
    PRIV_KEY=$(grep "Private key:" keys.txt | awk '{print $3}')
    PUB_KEY=$(grep "Public key:" keys.txt | awk '{print $3}')

    if [[ -z "$PUB_KEY" ]]; then
        echo -e "\e[1;31mErro: Falha ao gerar chaves. Verifique as permissões.\e[0m"
        read -p "Pressione Enter..."
        return
    fi

    echo "$NS_DOMAIN" > /etc/slowdns/domain
    echo "$PUB_KEY" > /etc/slowdns/pub.key
    echo "$PRIV_KEY" > /etc/slowdns/priv.key

    echo "[4/5] Configurando Systemd..."
    cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=SlowDNS Netsimon
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/dnstt-server -udp :5353 -privkey-file /etc/slowdns/priv.key $NS_DOMAIN 127.0.0.1:22
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    echo "[5/5] Ajustando Iptables..."
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

remove_slowdns() {
    systemctl stop slowdns && systemctl disable slowdns
    rm -rf /etc/slowdns /etc/systemd/system/slowdns.service
    echo "Removido."; sleep 2
}

while true; do
    clear
    echo "========================================="
    echo "         GERENCIADOR SLOWDNS             "
    echo "========================================="
    echo -e "Status: $(show_status)"
    [[ -f "/etc/slowdns/domain" ]] && echo -e "NS: \e[1;33m$(cat /etc/slowdns/domain)\e[0m"
    echo "========================================="
    echo "[1] Instalar / Configurar"
    echo "[2] Ver Dados"
    echo "[3] Desinstalar"
    echo "[0] Sair"
    read -p "Opção: " opc
    case $opc in
        1) install_slowdns ;;
        2) view_info ;;
        3) remove_slowdns ;;
        0) exit ;;
    esac
done
