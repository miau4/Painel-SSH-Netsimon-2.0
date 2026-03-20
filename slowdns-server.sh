#!/bin/bash
# ==========================================
# Gerenciador SlowDNS - Netsimon 2.0 (FINAL FIX)
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
    echo "   INSTALADOR SLOWDNS (LINK REAL 2026)   "
    echo "========================================="
    
    read -p "Digite seu NameServer (NS): " NS_DOMAIN
    [[ -z "$NS_DOMAIN" ]] && return

    echo -e "\n[1/4] Limpando e preparando ambiente..."
    apt-get update -y > /dev/null 2>&1
    apt-get install -y wget iptables libc6-i386 > /dev/null 2>&1

    systemctl stop slowdns > /dev/null 2>&1
    mkdir -p /etc/slowdns
    cd /etc/slowdns
    rm -f dnstt-server

    echo "[2/4] Baixando binário (Link Direto Confirmado)..."
    # ESTE É O LINK REAL: O arquivo está na pasta 'slowdns' do repositório que você mandou
    wget --no-check-certificate -O dnstt-server "https://raw.githubusercontent.com/hidessh99/autoscript-ssh-slowdns/main/slowdns/dnstt-server"

    # Se o primeiro falhar, tenta o link reserva do projeto original
    if [[ ! -s "dnstt-server" ]]; then
        echo "Link 1 falhou, tentando Link 2 (Reserva)..."
        wget --no-check-certificate -O dnstt-server "https://github.com/miau4/Painel-SSH-Netsimon-2.0/raw/main/dnstt-server"
    fi

    if [[ ! -s "dnstt-server" ]]; then
        echo -e "\e[1;31mErro Fatal: Link de download quebrado ou offline.\e[0m"
        read -p "Pressione [Enter] para voltar..."
        return
    fi
    
    chmod +x dnstt-server

    echo "[3/4] Gerando Chaves Criptográficas..."
    # Executa a geração de chaves
    ./dnstt-server -gen > keys.txt 2>&1
    
    PUB_KEY=$(grep "Public key:" keys.txt | awk '{print $3}')
    PRIV_KEY=$(grep "Private key:" keys.txt | awk '{print $3}')

    if [[ -z "$PUB_KEY" ]]; then
        echo -e "\e[1;31mErro: Binário incompatível ou falha na geração.\e[0m"
        echo "Log de erro:"
        cat keys.txt
        read -p "Pressione [Enter]..."
        return
    fi

    # Salva os dados
    echo "$NS_DOMAIN" > /etc/slowdns/domain
    echo "$PUB_KEY" > /etc/slowdns/pub.key
    echo "$PRIV_KEY" > /etc/slowdns/priv.key

    echo "[4/4] Configurando Firewall e Systemd..."
    # Regras para liberar o tráfego DNS na Oracle
    iptables -F
    iptables -X
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
WorkingDirectory=/etc/slowdns
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
    echo "TUDO PRONTO! Agora configure seu App."
    read -p "Pressione [Enter] para voltar..."
}

# (Menu Principal)
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
    echo "[3] Desinstalar Tudo"
    echo "[0] Sair"
    echo "========================================="
    read -p "Opção: " opc
    case $opc in
        1) install_slowdns ;;
        2) 
            clear
            if [ -f "/etc/slowdns/pub.key" ]; then
                echo "NameServer: $(cat /etc/slowdns/domain)"
                echo "Chave Pública: $(cat /etc/slowdns/pub.key)"
            else
                echo "SlowDNS não está instalado."
            fi
            read -p "Pressione [Enter]..." ;;
        3) 
            systemctl stop slowdns
            rm -rf /etc/slowdns /etc/systemd/system/slowdns.service
            echo "Removido com sucesso!"; sleep 2 ;;
        0) exit ;;
    esac
done
