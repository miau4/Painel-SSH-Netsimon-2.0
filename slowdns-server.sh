#!/bin/bash
# ==========================================
# Gerenciador SlowDNS (DNSTT) - Netsimon 2.0
# Versão: Ultra-Compatível (Direct Binary)
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
    echo "   INSTALADOR SLOWDNS (MODO DIRETO)      "
    echo "========================================="
    
    read -p "Digite seu NameServer (NS): " NS_DOMAIN
    [[ -z "$NS_DOMAIN" ]] && return

    echo -e "\n[1/4] Limpando vestígios antigos..."
    systemctl stop slowdns > /dev/null 2>&1
    rm -rf /etc/slowdns && mkdir -p /etc/slowdns
    
    echo "[2/4] Baixando binário testado..."
    # Baixando do repositório que você enviou como funcional
    wget -q -O /etc/slowdns/dnstt-server "https://raw.githubusercontent.com/hidessh99/autoscript-ssh-slowdns/main/dnstt-server"
    chmod +x /etc/slowdns/dnstt-server

    echo "[3/4] Gerando chaves (Tentativa Direta)..."
    cd /etc/slowdns
    # Executa o binário direto do diretório /etc/slowdns para evitar bloqueios de /usr/local/bin
    ./dnstt-server -gen > keys.txt 2>&1
    
    PRIV_KEY=$(grep "Private key:" keys.txt | awk '{print $3}')
    PUB_KEY=$(grep "Public key:" keys.txt | awk '{print $3}')

    # Se a chave ainda estiver vazia, tentamos rodar com permissão forçada
    if [[ -z "$PUB_KEY" ]]; then
        echo "Tentando método alternativo de geração..."
        /etc/slowdns/dnstt-server -gen > /etc/slowdns/keys.txt 2>&1
        PUB_KEY=$(grep "Public key:" /etc/slowdns/keys.txt | awk '{print $3}')
    fi

    if [[ -z "$PUB_KEY" ]]; then
        echo -e "\e[1;31mErro: O sistema não permitiu a execução do binário.\e[0m"
        echo "Dica: Verifique se sua VPS é OpenVZ ou KVM."
        read -p "Pressione Enter..."
        return
    fi

    echo "$NS_DOMAIN" > /etc/slowdns/domain
    echo "$PUB_KEY" > /etc/slowdns/pub.key
    echo "$PRIV_KEY" > /etc/slowdns/priv.key

    echo "[4/4] Finalizando Configuração e Firewall..."
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

    # Configuração de IPtables (Limpando e aplicando)
    iptables -t nat -F PREROUTING > /dev/null 2>&1
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
    echo "Configuração salva em /etc/slowdns/"
    read -p "Pressione [Enter] para voltar..."
}

# --- Menu Principal do Script ---
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
                echo "NameServer: $(cat /etc/slowdns/domain)"
                echo "Chave Pub: $(cat /etc/slowdns/pub.key)"
            else
                echo "SlowDNS não instalado."
            fi
            read -p "Aperte Enter..." ;;
        3) systemctl stop slowdns; rm -rf /etc/slowdns; echo "Removido."; sleep 2 ;;
        0) exit ;;
    esac
done
