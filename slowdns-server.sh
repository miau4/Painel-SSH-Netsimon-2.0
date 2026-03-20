#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - SLOWDNS MANAGER
# ==========================================

DNS_DIR="/etc/slowdns"
BIN="$DNS_DIR/dns-server"
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

# Garante que o binário e pastas existam
mkdir -p "$DNS_DIR"

install_dns() {
    echo -e "${Y}[!] Baixando binário dns-server...${NC}"
    wget -q -O "$BIN" "https://github.com/miau4/Painel-SSH-Netsimon-2.0/raw/main/dns-server"
    chmod +x "$BIN"
    
    if [ ! -f "$DNS_DIR/server.pub" ]; then
        cd "$DNS_DIR"
        ./dns-server -gen-key -privkey-file server.key -pubkey-file server.pub
        cd - &>/dev/null
    fi
}

start_dns() {
    pkill -f "dns-server"
    systemctl stop systemd-resolved &>/dev/null
    
    echo -ne "${W}Digite seu NameServer (NS): ${NC}"; read ns
    [ -z "$ns" ] && return
    
    # Porta 53 é a porta padrão para DNS
    nohup "$BIN" -udp :53 -privkey-file "$DNS_DIR/server.key" "$ns" 127.0.0.1:22 > /dev/null 2>&1 &
    echo -e "${G}[OK] SlowDNS Iniciado na Porta 53!${NC}"
    sleep 2
}

# Menu
clear
echo -e " 1) Instalar/Gerar Chaves"
echo -e " 2) Iniciar SlowDNS (Porta 53)"
echo -e " 3) Parar SlowDNS"
echo -e " 0) Voltar"
echo -ne "\nEscolha: "; read opt
case $opt in
    1) install_dns ;;
    2) start_dns ;;
    3) pkill -f "dns-server"; systemctl start systemd-resolved &>/dev/null; echo -e "${R}Parado!${NC}"; sleep 2 ;;
    *) exit 0 ;;
esac
