#!/bin/bash

# Diretórios e Arquivos
DNS_DIR="/etc/slowdns"
BIN_DNS="$DNS_DIR/dnstt-server"
PUB_KEY="$DNS_DIR/server.pub"
PRIV_KEY="$DNS_DIR/server.key"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}             📡 SLOWDNS / DNSTT MANAGER PRO                  ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

# Status Check
PID=$(pgrep -f dnstt-server)
if [ -z "$PID" ]; then
    echo -e "Status: ${R}OFFLINE${NC}"
else
    echo -e "Status: ${G}ONLINE (PID: $PID)${NC}"
fi
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"

menu_dns() {
    echo -e "1) Instalar e Configurar SlowDNS"
    echo -e "2) Parar SlowDNS"
    echo -e "3) Ver Chave Pública (Public Key)"
    echo -e "4) Desinstalar Completo"
    echo -e "0) Voltar"
    echo -ne "\nEscolha: "
    read op
}

install_dns() {
    clear
    echo -e "${Y}[+] Iniciando Configuração Robusta do SlowDNS...${NC}"
    
    # 1. Dependências e Binário
    apt update -y && apt install -y git build-essential &>/dev/null
    mkdir -p "$DNS_DIR"
    
    if [ ! -f "$BIN_DNS" ]; then
        echo -e "[+] Baixando e Compilando DNSTT (Aguarde)..."
        cd "$DNS_DIR" || exit
        git clone https://www.bamsoftware.com/git/dnstt.git &>/dev/null
        cd dnstt/dnstt-server && go build &>/dev/null || apt install golang -y && go build &>/dev/null
        cp dnstt-server "$BIN_DNS"
    fi

    # 2. Geração de Chaves
    if [ ! -f "$PUB_KEY" ]; then
        echo -e "[+] Gerando novas chaves criptográficas..."
        cd "$DNS_DIR" && "$BIN_DNS" -gen-key -privkey "$PRIV_KEY" -pubkey "$PUB_KEY"
    fi

    # 3. Configuração do NS
    read -p "Digite seu NameServer (NS) (ex: ns1.seudominio.com): " ns
    [[ -z "$ns" ]] && { echo -e "${R}NS Obrigatório!${NC}"; return; }

    # 4. LIBERAÇÃO DA PORTA 53 (O MAIS IMPORTANTE)
    echo -e "[+] Configurando Interface de Rede e Firewall..."
    if grep -q "DNSStubListener=yes" /etc/systemd/resolved.conf; then
        sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
        sed -i 's/DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
        systemctl restart systemd-resolved
    fi

    # Redirecionamento IPTABLES (A mágica do SlowDNS)
    iptables -I INPUT -p udp --dport 5300 -j ACCEPT
    iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
    ip6tables -I INPUT -p udp --dport 5300 -j ACCEPT
    ip6tables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300

    # 5. Execução em Segundo Plano
    echo -e "[+] Iniciando Servidor na porta 5300..."
    nohup "$BIN_DNS" -udp :5300 -privkey "$PRIV_KEY" "$ns" 127.0.0.1:22 > /dev/null 2>&1 &

    echo -e "${G}✅ SlowDNS Ativo e Configurado!${NC}"
    echo -e "${W}Chave Pública:${Y} $(cat "$PUB_KEY")${NC}"
    echo -e "${W}NS:${Y} $ns${NC}"
    read -p "Aperte ENTER para continuar..."
}

show_key() {
    if [ -f "$PUB_KEY" ]; then
        echo -e "\n${W}SUA PUBLIC KEY:${NC}"
        echo -e "${G}$(cat "$PUB_KEY")${NC}\n"
    else
        echo -e "${R}Chaves não encontradas! Instale primeiro.${NC}"
    fi
    read -p "ENTER..."
}

case $op in
    1) install_dns ;;
    2) pkill -f dnstt-server; echo "Parado."; sleep 2 ;;
    3) show_key ;;
    4) 
        pkill -f dnstt-server
        rm -rf "$DNS_DIR"
        iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
        echo "Removido."; sleep 2 ;;
    0) exit 0 ;;
esac

menu_dns
