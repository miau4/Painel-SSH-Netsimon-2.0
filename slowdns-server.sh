#!/bin/bash
# SLOWDNS MANAGER PRO - NETSIMON ENTERPRISE

DNS_DIR="/etc/slowdns"
BIN_DNS="$DNS_DIR/dnstt-server"
PUB_KEY="$DNS_DIR/server.pub"
PRIV_KEY="$DNS_DIR/server.key"
NS_FILE="$DNS_DIR/ns_name"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}             📡 SLOWDNS / DNSTT MANAGER PRO                  ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

PID=$(pgrep -f dnstt-server)
if [ -z "$PID" ]; then
    echo -e " Status: ${R}OFFLINE${NC}"
else
    NS_ATUAL=$(cat "$NS_FILE" 2>/dev/null)
    echo -e " Status: ${G}ONLINE${NC} | NS: ${Y}$NS_ATUAL${NC}"
fi
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"

menu_dns() {
    echo -e " 1) Instalar/Configurar SlowDNS (DNSTT)"
    echo -e " 2) Ver Informações de Conexão (Chaves/NS)"
    echo -e " 3) Reiniciar Servidor DNS"
    echo -e " 4) Parar Servidor DNS"
    echo -e " 5) Desinstalar e Limpar Firewall"
    echo -e " 0) Voltar"
    echo -ne "\n${Y}Escolha: ${NC}"
    read op
}

install_dns() {
    clear
    echo -e "${C}[+] Instalando dependências (GoLang, Git, Build)...${NC}"
    apt update -y && apt install -y git build-essential golang &>/dev/null
    
    mkdir -p "$DNS_DIR"
    cd "$DNS_DIR" || exit

    if [ ! -f "$BIN_DNS" ]; then
        echo -e "${C}[+] Baixando e Compilando DNSTT Oficial...${NC}"
        git clone https://www.bamsoftware.com/git/dnstt.git /tmp/dnstt &>/dev/null
        cd /tmp/dnstt/dnstt-server && go build &>/dev/null
        cp dnstt-server "$BIN_DNS" && chmod +x "$BIN_DNS"
    fi

    if [ ! -f "$PUB_KEY" ]; then
        echo -e "${C}[+] Gerando novas chaves criptográficas do servidor...${NC}"
        "$BIN_DNS" -gen-key -privkey "$PRIV_KEY" -pubkey "$PUB_KEY"
    fi

    echo -ne "${Y}Informe seu NameServer (NS) (ex: ns.seudominio.com): ${NC}"
    read ns
    [[ -z "$ns" ]] && { echo -e "${R}Erro: NS é obrigatório!${NC}"; sleep 2; return; }
    echo "$ns" > "$NS_FILE"

    echo -e "${C}[+] Otimizando Porta 53 (Removendo conflitos do Systemd)...${NC}"
    if grep -q "DNSStubListener=yes" /etc/systemd/resolved.conf; then
        sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
        sed -i 's/DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
        systemctl restart systemd-resolved
    fi

    echo -e "${C}[+] Configurando Redirecionamento UDP (IPTABLES)...${NC}"
    iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
    ip6tables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null

    echo -e "${C}[+] Iniciando em background...${NC}"
    nohup "$BIN_DNS" -udp :5300 -privkey "$PRIV_KEY" "$ns" 127.0.0.1:22 > /dev/null 2>&1 &
    
    echo -e "\n${G}✅ SLOWDNS ATIVO!${NC}"
    echo -e "${W}Chave Pública:${Y} $(cat $PUB_KEY)${NC}"
    read -p "ENTER para continuar..."
}

case $op in
    1) install_dns ;;
    2)
        if [ -f "$PUB_KEY" ]; then
            echo -e "\n${W}DADOS DE CONEXÃO:${NC}"
            echo -e "NS: ${Y}$(cat $NS_FILE)${NC}"
            echo -e "Chave Pública: ${G}$(cat $PUB_KEY)${NC}\n"
        else
            echo -e "${R}Serviço não configurado.${NC}"
        fi
        read -p "ENTER..." ;;
    3) pkill -f dnstt-server; nohup "$BIN_DNS" -udp :5300 -privkey "$PRIV_KEY" "$(cat $NS_FILE)" 127.0.0.1:22 > /dev/null 2>&1 &; echo "Reiniciado."; sleep 2 ;;
    4) pkill -f dnstt-server; echo "Parado."; sleep 2 ;;
    5)
        pkill -f dnstt-server
        iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null
        rm -rf "$DNS_DIR"
        echo "Tudo limpo."; sleep 2 ;;
    0) exit 0 ;;
esac

menu_dns
