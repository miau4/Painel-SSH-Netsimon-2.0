#!/bin/bash
# ==========================================
#    GERENCIADOR SLOWDNS - PAINEL NETSIMON
# ==========================================

# Cores Padronizadas
P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; NC='\033[0m'

# Caminhos
DIR="/etc/slowdns"
BIN="$DIR/dnstt-server"

show_status() {
    if systemctl is-active --quiet slowdns 2>/dev/null; then
        echo -e "${G}● ATIVO${NC}"
    else
        echo -e "${R}○ PARADO / NÃO INSTALADO${NC}"
    fi
}

install_slowdns() {
    clear
    echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${P}║${W}                📡 INSTALADOR SLOWDNS                         ${P}║${NC}"
    echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    echo -ne "${W}Digite seu NameServer (NS): ${NC}"; read NS_DOMAIN
    [[ -z "$NS_DOMAIN" ]] && return

    # 1. Preparação de Binário
    if [[ ! -f "$BIN" ]]; then
        echo -e "${Y}[1/3] Movendo binário compilado...${NC}"
        mkdir -p "$DIR"
        if [ -f "/root/dnstt-build/dnstt-server/dnstt-server" ]; then
            cp /root/dnstt-build/dnstt-server/dnstt-server "$BIN"
        else
            echo -e "${R}ERRO: Binário compilado não encontrado em /root/dnstt-build!${NC}"
            read -p "Pressione Enter..." ; return
        fi
        chmod +x "$BIN"
    fi

    # 2. Geração de Chaves
    echo -e "${Y}[2/3] Gerando par de chaves criptográficas...${NC}"
    cd "$DIR"
    rm -f priv.key pub.key
    "$BIN" -gen-key -privkey-file priv.key -pubkey-file pub.key > /dev/null 2>&1
    
    PRIV_KEY=$(cat priv.key 2>/dev/null)
    PUB_KEY=$(cat pub.key 2>/dev/null)

    if [[ -z "$PUB_KEY" ]]; then
        echo -e "${R}ERRO: Falha ao gerar arquivos de chave.${NC}"
        read -p "Pressione Enter..." ; return
    fi
    echo "$NS_DOMAIN" > domain

    # 3. Firewall e Systemd
    echo -e "${Y}[3/3] Configurando Firewall e Serviço Systemd...${NC}"
    iptables -F
    iptables -t nat -F
    iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353
    iptables -I INPUT -p udp --dport 53 -j ACCEPT
    iptables -I INPUT -p udp --dport 5353 -j ACCEPT

    cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=SlowDNS Netsimon 2.0
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$BIN -udp :5353 -privkey-file $DIR/priv.key $NS_DOMAIN 127.0.0.1:22
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable slowdns > /dev/null 2>&1
    systemctl restart slowdns

    clear
    echo -e "${G}✅ SLOWDNS CONFIGURADO COM SUCESSO!${NC}"
    echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
    echo -e "${W} NameServer (NS) : ${Y}$NS_DOMAIN${NC}"
    echo -e "${W} Chave Pública   : ${G}$PUB_KEY${NC}"
    echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
    echo -e "${W}Copie a chave acima para o seu aplicativo (Injetor/HTTP Custom).${NC}"
    read -p "Pressione [Enter] para voltar..."
}

# Menu Loop
while true; do
    clear
    echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${P}║${W}                📡 GERENCIADOR SLOWDNS                        ${P}║${NC}"
    echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e " STATUS: $(show_status)"
    [[ -f "$DIR/domain" ]] && echo -e " NS ATUAL: ${Y}$(cat $DIR/domain)${NC}"
    echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
    echo -e " ${G}[1]${W} Instalar / Reconfigurar SlowDNS${NC}"
    echo -e " ${G}[2]${W} Ver Minha Chave Pública (PUB KEY)${NC}"
    echo -e " ${R}[3]${W} Parar e Desinstalar SlowDNS${NC}"
    echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
    echo -e " ${R}[0] SAIR${NC}"
    echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
    echo -ne " Escolha uma opção: "; read opc
    
    case $opc in
        1) install_slowdns ;;
        2) 
            clear
            if [ -f "$DIR/pub.key" ]; then
                echo -e "${P}╔══════════════════════════════════════════╗${NC}"
                echo -e "${W}   SUA CHAVE PÚBLICA SLOWDNS:              ${NC}"
                echo -e "${P}╚══════════════════════════════════════════╝${NC}"
                echo -e "${G}$(cat $DIR/pub.key)${NC}"
                echo -e "${P}────────────────────────────────────────────${NC}"
            else
                echo -e "${R}Erro: SlowDNS não está instalado.${NC}"
            fi
            read -p "Pressione ENTER para voltar..." ;;
        3) 
            echo -e "${Y}Removendo SlowDNS e limpando regras...${NC}"
            systemctl stop slowdns >/dev/null 2>&1
            systemctl disable slowdns >/dev/null 2>&1
            rm -f /etc/systemd/system/slowdns.service
            systemctl daemon-reload
            # Limpa as regras de redirecionamento específicas
            iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353 2>/dev/null
            rm -rf "$DIR"
            echo -e "${G}SlowDNS removido com sucesso!${NC}"; sleep 2 ;;
        0) exit 0 ;;
        *) echo -e "${R}Opção inválida!${NC}"; sleep 1 ;;
    esac
done
