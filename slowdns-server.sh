#!/bin/bash
# ==========================================
# Gerenciador SlowDNS (DNSTT) - Netsimon 2.0
# Versão: Auto-Compilável (Resistente a Erros)
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
    echo "   INSTALADOR SLOWDNS (COMPILADOR GO)    "
    echo "========================================="
    
    read -p "Digite seu NameServer (NS): " NS_DOMAIN
    [[ -z "$NS_DOMAIN" ]] && return

    echo -e "\n[1/5] Instalando Go e dependências (isso pode demorar...)"
    apt-get update -y -q > /dev/null 2>&1
    apt-get install -y git golang-go iptables wget > /dev/null 2>&1

    # Limpeza
    systemctl stop slowdns > /dev/null 2>&1
    rm -rf /etc/slowdns && mkdir -p /etc/slowdns
    rm -rf /root/dnstt

    echo "[2/5] Clonando e Compilando o DNSTT (Garantindo Compatibilidade)..."
    cd /root
    git clone https://www.bamsoftware.com/git/dnstt.git > /dev/null 2>&1
    cd dnstt/dnstt-server
    go build > /dev/null 2>&1
    
    if [[ ! -f "dnstt-server" ]]; then
        echo -e "\e[1;31mErro: Falha ao compilar o binário. Verifique sua conexão.\e[0m"
        read -p "Pressione Enter..."
        return
    fi
    
    mv dnstt-server /usr/local/bin/
    chmod +x /usr/local/bin/dnstt-server

    echo "[3/5] Gerando chaves criptográficas..."
    cd /etc/slowdns
    /usr/local/bin/dnstt-server -gen > keys.txt 2>&1
    
    PRIV_KEY=$(grep "Private key:" keys.txt | awk '{print $3}')
    PUB_KEY=$(grep "Public key:" keys.txt | awk '{print $3}')

    if [[ -z "$PUB_KEY" ]]; then
        echo -e "\e[1;31mErro: O binário compilado falhou ao gerar chaves.\e[0m"
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

    echo "[5/5] Configurando redirecionamento de portas..."
    # Limpa regras velhas para não duplicar
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
    read -p "Pressione [Enter] para voltar..."
}

# ... (restante das funções de menu iguais ao anterior)

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
        2) 
            clear
            echo "========================================="
            echo "       DADOS DE ACESSO SLOWDNS           "
            echo "========================================="
            if [ -f "/etc/slowdns/pub.key" ]; then
                echo -e "NS: $(cat /etc/slowdns/domain)"
                echo -e "Chave: $(cat /etc/slowdns/pub.key)"
            else
                echo "Não instalado."
            fi
            read -p "Pressione Enter..."
            ;;
        3) 
            systemctl stop slowdns
            rm -rf /etc/slowdns
            echo "Removido."; sleep 2 ;;
        0) exit ;;
    esac
done
