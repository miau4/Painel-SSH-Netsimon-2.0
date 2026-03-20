cat << 'EOF' > /etc/painel/slowdns-server.sh
#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - SLOWDNS MANAGER 2.0
# ==========================================

C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'
DNS_DIR="/etc/slowdns"
BIN="$DNS_DIR/dns-server"

# Função para instalar o binário caso não exista
install_bin() {
    if [ ! -f "$BIN" ]; then
        echo -e "${Y}[!] Baixando binários do SlowDNS...${NC}"
        mkdir -p "$DNS_DIR"
        # Download do binário compilado para Linux 64bits
        wget -q -O "$BIN" "https://github.com/miau4/Painel-SSH-Netsimon-2.0/raw/main/dns-server"
        chmod +x "$BIN"
    fi
    
    if [ ! -f "$DNS_DIR/server.key" ]; then
        echo -e "${Y}[!] Gerando par de chaves SlowDNS...${NC}"
        # Comando para gerar chaves (privada e pública)
        $BIN -gen-key -privkey-file "$DNS_DIR/server.key" -pubkey-file "$DNS_DIR/server.pub" &>/dev/null
    fi
}

check_status() {
    pgrep -f "dns-server" > /dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}"
}

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                🛰️  SLOWDNS ENTERPRISE MANAGER                 ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
install_bin

echo -e " Status Atual: $(check_status)"
echo -e " Chave Pública: ${Y}$(cat $DNS_DIR/server.pub 2>/dev/null)${NC}"
echo -e "--------------------------------------------"
echo -e " 1) Iniciar SlowDNS"
echo -e " 2) Parar SlowDNS"
echo -e " 3) Ver Dados de Conexão (Para o App)"
echo -e " 0) Voltar"
echo -ne "\n${Y}Escolha: ${NC}"; read opt

case $opt in
    1)
        if pgrep -f "dns-server" > /dev/null; then
            echo -e "${Y}SlowDNS já está rodando!${NC}"
        else
            echo -ne "${W}NS (NameServer): ${NC}"; read ns
            echo -ne "${W}Porta de Redirecionamento (SSH): ${NC}"; read port
            [ -z "$port" ] && port="22"
            
            # Comando de execução Enterprise
            nohup $BIN -udp :53 -privkey-file "$DNS_DIR/server.key" $ns 127.0.0.1:$port > /dev/null 2>&1 &
            sleep 2
            echo -e "${G}[OK] Iniciado!${NC}"
        fi
        ;;
    2)
        pkill -f "dns-server"
        echo -e "${R}SlowDNS Parado!${NC}"
        ;;
    3)
        clear
        pub=$(cat $DNS_DIR/server.pub)
        ip=$(wget -qO- ifconfig.me)
        echo -e "${G}--- DADOS DE CONFIGURAÇÃO NO APP ---${NC}"
        echo -e "${W}DNS IP: ${C}$ip${NC}"
        echo -e "${W}Public Key: ${C}$pub${NC}"
        echo -e "${W}NameServer (NS): ${Y}(O que você configurou)${NC}"
        echo -e "------------------------------------"
        read -p "Pressione ENTER para voltar..."
        ;;
    *) exit 0 ;;
esac
sleep 1
EOF
chmod +x /etc/painel/slowdns-server.sh
