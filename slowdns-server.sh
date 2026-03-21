#!/bin/bash
# ==========================================
# Gerenciador SlowDNS - Netsimon 2.0 (FINAL)
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
    echo "   INSTALADOR SLOWDNS (VERSÃO FINAL)     "
    echo "========================================="
    
    read -p "Digite seu NameServer (NS): " NS_DOMAIN
    [[ -z "$NS_DOMAIN" ]] && return

    # Usando o que já compilamos para ganhar tempo
    if [[ ! -f "/etc/slowdns/dnstt-server" ]]; then
        echo "[1/3] Movendo binário compilado..."
        mkdir -p /etc/slowdns
        cp /root/dnstt-build/dnstt-server/dnstt-server /etc/slowdns/dnstt-server
        chmod +x /etc/slowdns/dnstt-server
    fi

    cd /etc/slowdns

    echo "[2/3] Gerando Chaves (Novo Comando)..."
    rm -f server.key server.pub
    
    # Comando atualizado conforme o log de erro anterior
    ./dnstt-server -gen-key -privkey-file priv.key -pubkey-file pub.key > /dev/null 2>&1
    
    # Lendo as chaves geradas nos arquivos
    PRIV_KEY=$(cat priv.key 2>/dev/null)
    PUB_KEY=$(cat pub.key 2>/dev/null)

    if [[ -z "$PUB_KEY" ]]; then
        echo -e "\e[1;31mERRO: Falha ao gerar arquivos de chave.\e[0m"
        read -p "Pressione Enter..."
        return
    fi

    echo "$NS_DOMAIN" > domain

    echo "[3/3] Configurando Firewall e Serviço..."
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
WorkingDirectory=/etc/slowdns
ExecStart=/etc/slowdns/dnstt-server -udp :5353 -privkey-file /etc/slowdns/priv.key $NS_DOMAIN 127.0.0.1:22
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable slowdns > /dev/null 2>&1
    systemctl restart slowdns

    clear
    echo "========================================="
    echo "       SLOWDNS INSTALADO COM SUCESSO!    "
    echo "========================================="
    echo -e "Status          : $(show_status)"
    echo -e "NameServer (NS) : \e[1;33m$NS_DOMAIN\e[0m"
    echo -e "Chave Pública   : \e[1;32m$PUB_KEY\e[0m"
    echo "========================================="
    echo "Copie a chave acima para o seu aplicativo."
    read -p "Pressione [Enter] para voltar..."
}

# Menu Principal
while true; do
    clear
    echo "========================================="
    echo "         GERENCIADOR SLOWDNS             "
    echo "========================================="
    echo -e "Status: $(show_status)"
    [[ -f "/etc/slowdns/domain" ]] && echo -e "NS: \e[1;33m$(cat /etc/slowdns/domain)\e[0m"
    echo "========================================="
    echo "[1] Instalar / Reconfigurar"
    echo "[2] Ver Chave Pública"
    echo "[3] Desinstalar"
    echo "[0] Sair"
    read -p "Opção: " opc
    case $opc in
        1) install_slowdns ;;
        2) 
            clear
            if [ -f "/etc/slowdns/pub.key" ]; then
                echo "Chave Pública: $(cat /etc/slowdns/pub.key)"
            else
                echo "Não instalado."
            fi
            read -p "Enter..." ;;
        3) systemctl stop slowdns; rm -rf /etc/slowdns; echo "Removido!"; sleep 2 ;;
        0) exit ;;
    esac
done
