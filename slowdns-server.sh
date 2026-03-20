#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - SLOWDNS REPAIR
# ==========================================

C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'
DNS_DIR="/etc/slowdns"
BIN="$DNS_DIR/dns-server"

install_bin() {
    mkdir -p "$DNS_DIR"
    
    # Se o binário não existe ou não executa, baixa novamente
    if [ ! -f "$BIN" ] || ! "$BIN" -version &>/dev/null; then
        echo -e "${Y}[!] Baixando binário universal (x86_64)...${NC}"
        # Link alternativo direto do repositório oficial do DNSTT/SlowDNS
        wget -q -O "$BIN" "https://github.com/miau4/Painel-SSH-Netsimon-2.0/raw/main/dns-server"
        chmod +x "$BIN"
    fi
    
    # Tenta gerar as chaves. Se o binário falhar aqui, o problema é a arquitetura da VPS.
    if [ ! -f "$DNS_DIR/server.pub" ]; then
        echo -e "${Y}[!] Tentando gerar chaves...${NC}"
        cd "$DNS_DIR"
        ./dns-server -gen-key -privkey-file server.key -pubkey-file server.pub
        cd - &>/dev/null
    fi
}

get_ip() {
    wget -qO- ipv4.icanhazip.com || echo "SEU_IP_AQUI"
}

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                🛰️  SLOWDNS REPAIR MANAGER                     ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

install_bin

# VALIDAÇÃO CRÍTICA
if [ ! -f "$DNS_DIR/server.pub" ]; then
    echo -e "${R}-------------------------------------------------------${NC}"
    echo -e "${R}ERRO CRÍTICO: O binário 'dns-server' não rodou nesta VPS.${NC}"
    echo -e "${W}Causa provável: Sua VPS é ARM (Oracle Ampere) e o binário é x86.${NC}"
    echo -e "${R}-------------------------------------------------------${NC}"
    read -p "Pressione ENTER para sair e corrigir o binário..."
    exit 1
fi

pub_key=$(cat "$DNS_DIR/server.pub")

echo -e " Status: $(pgrep -f "dns-server" > /dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}")"
echo -e " Chave Pública: ${Y}$pub_key${NC}"
echo -e "--------------------------------------------"
echo -e " 1) Configurar e Iniciar"
echo -e " 2) Parar"
echo -e " 0) Voltar"
echo -ne "\n${Y}Escolha: ${NC}"; read opt

case $opt in
    1)
        pkill -f "dns-server"
        echo -ne "${W}NameServer (NS): ${NC}"; read ns
        [ -z "$ns" ] && exit 1
        echo "$ns" > "$DNS_DIR/ns_name"
        
        systemctl stop systemd-resolved &>/dev/null
        nohup "$BIN" -udp :53 -privkey-file "$DNS_DIR/server.key" "$ns" 127.0.0.1:22 > /dev/null 2>&1 &
        sleep 2
        echo -e "${G}[OK] Ativado!${NC}"
        ;;
    2)
        pkill -f "dns-server"
        systemctl start systemd-resolved &>/dev/null
        echo -e "${R}Parado!${NC}"
        ;;
    *) exit 0 ;;
esac
