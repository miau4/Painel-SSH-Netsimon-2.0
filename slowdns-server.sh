#!/bin/bash
# ==========================================
# Gerenciador SlowDNS (DNSTT) - Netsimon 2.0
# ==========================================

# Função para checar se o serviço está rodando
show_status() {
    if systemctl is-active --quiet slowdns; then
        echo -e "\e[1;32m[ATIVO]\e[0m"
    else
        echo -e "\e[1;31m[PARADO / NÃO INSTALADO]\e[0m"
    fi
}

# Função para ver os dados de acesso
view_info() {
    clear
    echo "========================================="
    echo "       INFORMAÇÕES DO SLOWDNS            "
    echo "========================================="
    if [ -f "/etc/slowdns/pub.key" ] && [ -f "/etc/slowdns/domain" ]; then
        PUB_KEY=$(cat /etc/slowdns/pub.key)
        NS_DOMAIN=$(cat /etc/slowdns/domain)
        echo -e "Status         : $(show_status)"
        echo -e "NameServer (NS): \e[1;33m$NS_DOMAIN\e[0m"
        echo -e "Chave Pública  : \e[1;33m$PUB_KEY\e[0m"
    else
        echo "O SlowDNS ainda não foi configurado no servidor."
    fi
    echo "========================================="
    # Pausa a tela para o usuário conseguir ler e copiar
    read -p "Pressione [Enter] para voltar..."
}

# Função de Instalação
install_slowdns() {
    clear
    echo "========================================="
    echo "   INSTALADOR SLOWDNS (DNSTT) NETSIMON   "
    echo "========================================="
    echo ""

    read -p "Digite seu NameServer (NS) [ex: ns.seudominio.com]: " NS_DOMAIN
    if [ -z "$NS_DOMAIN" ]; then
        echo "Erro: NameServer não pode ficar vazio!"
        sleep 2
        return
    fi

    echo -e "\n[1/5] Instalando dependências..."
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y iptables dnsutils wget unzip > /dev/null 2>&1

    # Limpa instalações anteriores
    systemctl stop slowdns > /dev/null 2>&1
    systemctl disable slowdns > /dev/null 2>&1
    rm -rf /etc/slowdns
    rm -f /etc/systemd/system/slowdns.service

    echo "[2/5] Baixando o servidor DNSTT..."
    cd /usr/local/bin
    wget -q -O dnstt-server "https://raw.githubusercontent.com/hidessh99/autoscript-ssh-slowdns/main/dnstt-server"
    chmod +x dnstt-server

    echo "[3/5] Gerando chaves de criptografia..."
    mkdir -p /etc/slowdns
    cd /etc/slowdns
    /usr/local/bin/dnstt-server -gen > keys.txt
    PRIV_KEY=$(cat keys.txt | grep "Private key:" | awk '{print $3}')
    PUB_KEY=$(cat keys.txt | grep "Public key:" | awk '{print $3}')

    echo "$NS_DOMAIN" > /etc/slowdns/domain
    echo "$PUB_KEY" > /etc/slowdns/pub.key
    echo "$PRIV_KEY" > /etc/slowdns/priv.key

    echo "[4/5] Configurando o serviço..."
    cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=SlowDNS (DNSTT) Server - Netsimon
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/dnstt-server -udp :5353 -privkey-file /etc/slowdns/priv.key $NS_DOMAIN 127.0.0.1:22
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    echo "[5/5] Aplicando regras de Firewall (Iptables)..."
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353 > /dev/null 2>&1
    iptables -D INPUT -p udp --dport 5353 -j ACCEPT > /dev/null 2>&1
    iptables -D INPUT -p udp --dport 53 -j ACCEPT > /dev/null 2>&1

    iptables -I INPUT -p udp --dport 53 -j ACCEPT
    iptables -I INPUT -p udp --dport 5353 -j ACCEPT
    iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353

    dpkg-query -W -f='${Status}' iptables-persistent 2>/dev/null | grep -c "ok installed" > /dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent > /dev/null 2>&1
    netfilter-persistent save > /dev/null 2>&1

    systemctl daemon-reload
    systemctl enable slowdns > /dev/null 2>&1
    systemctl restart slowdns

    clear
    echo "========================================="
    echo "       SLOWDNS INSTALADO COM SUCESSO!    "
    echo "========================================="
    echo -e "Status          : $(show_status)"
    echo -e "NameServer (NS) : \e[1;33m$NS_DOMAIN\e[0m"
    echo -e "Chave Pública   : \e[1;33m$PUB_KEY\e[0m"
    echo "========================================="
    echo "Copie a chave acima para usar no seu app!"
    echo "========================================="
    # A MÁGICA ACONTECE AQUI: O script pausa até você apertar Enter
    read -p "Pressione [Enter] para voltar ao menu do SlowDNS..."
}

# Função para desinstalar
remove_slowdns() {
    clear
    echo "Removendo SlowDNS do sistema..."
    systemctl stop slowdns > /dev/null 2>&1
    systemctl disable slowdns > /dev/null 2>&1
    rm -rf /etc/slowdns
    rm -f /etc/systemd/system/slowdns.service
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353 > /dev/null 2>&1
    netfilter-persistent save > /dev/null 2>&1
    echo "Removido com sucesso!"
    sleep 2
}

# Loop do Menu do SlowDNS
while true; do
    clear
    echo "========================================="
    echo "         GERENCIADOR SLOWDNS             "
    echo "========================================="
    # Informações estáticas no topo
    echo -e "Status do Serviço: $(show_status)"
    if [ -f "/etc/slowdns/domain" ]; then
        echo -e "NS Atual: \e[1;33m$(cat /etc/slowdns/domain)\e[0m"
    fi
    echo "========================================="
    echo "[1] - Instalar / Configurar SlowDNS"
    echo "[2] - Ver Informações (Chave/NS)"
    echo "[3] - Desinstalar SlowDNS"
    echo "[0] - Voltar ao Menu Principal"
    echo "========================================="
    read -p "Escolha uma opção: " opc

    case $opc in
        1) install_slowdns ;;
        2) view_info ;;
        3) remove_slowdns ;;
        0) exit 0 ;;
        *) echo "Opção inválida!"; sleep 1 ;;
    esac
done
