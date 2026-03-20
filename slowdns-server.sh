#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - SLOWDNS MODULE
# ==========================================

DNS_DIR="/etc/slowdns"
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; NC='\033[0m'

setup_dns() {
    clear
    echo -e "${C}🛠️ Configurando SlowDNS...${NC}"
    mkdir -p "$DNS_DIR"
    
    # Download do binário (Ajuste para o seu link se necessário)
    wget -q -O "$DNS_DIR/dns-server" "https://github.com/miau4/Painel-SSH-Netsimon-2.0/raw/main/dns-server"
    chmod +x "$DNS_DIR/dns-server"
    
    # Geração automática das chaves
    cd "$DNS_DIR"
    ./dns-server -gen-key -privkey-file server.key -pubkey-file server.pub
    echo -e "${G}Chaves geradas com sucesso!${NC}"
    cd - &>/dev/null
    sleep 2
}

start_dns() {
    systemctl stop systemd-resolved &>/dev/null
    read -p "Digite seu NameServer (NS): " ns
    [ -z "$ns" ] && return
    
    # Inicia na porta 53 UDP apontando para o SSH (22)
    nohup "$DNS_DIR/dns-server" -udp :53 -privkey-file "$DNS_DIR/server.key" "$ns" 127.0.0.1:22 > /dev/null 2>&1 &
    echo -e "${G}SlowDNS Online na Porta 53!${NC}"
    sleep 2
}

clear
echo -e " 1) Instalar e Gerar Chaves\n 2) Iniciar (Porta 53)\n 3) Parar\n 0) Sair"
read -p "Opção: " opt
case $opt in
    1) setup_dns ;;
    2) start_dns ;;
    3) pkill -f dns-server; systemctl start systemd-resolved &>/dev/null; echo "Parado!"; sleep 2 ;;
esac
