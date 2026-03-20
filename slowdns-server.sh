#!/bin/bash

# Cores
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

clear
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}        🛰️  INSTALAÇÃO SLOWDNS (DNSTT)      ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

# 1. PERGUNTAS
read -p "Domínio principal (ex: google.com): " dom
read -p "Subdomínio NS (ex: ns.google.com): " ns
read -p "Porta UDP (Recomendado 5300): " port
[[ -z "$port" ]] && port=5300

# 2. LIBERAR PORTA 53 (ESSENCIAL PARA UBUNTU NOBLE)
echo -e "${CYAN}[+] Resetando DNS do sistema...${NC}"
systemctl stop systemd-resolved &>/dev/null
systemctl disable systemd-resolved &>/dev/null
fuser -k 53/udp &>/dev/null # Mata qualquer processo na 53

# Ajusta o DNS para o servidor não perder internet
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# 3. DEPENDÊNCIAS
echo -e "${CYAN}[+] Instalando dependências...${NC}"
apt update -y
apt install -y git golang curl iptables-persistent &>/dev/null

# 4. DOWNLOAD E COMPILAÇÃO (LIMPA ANTES)
cd /root || exit
rm -rf dnstt
git clone https://github.com/m13253/dnstt.git &>/dev/null
cd dnstt/dnstt-server || exit
go build &>/dev/null

if [ ! -f "dnstt-server" ]; then
    echo -e "${RED}Erro fatal: Falha na compilação do GO!${NC}"
    exit 1
fi

# 5. GERAR CHAVES (O SERVIÇO SÓ LIGA SE ELAS EXISTIREM)
echo -e "${CYAN}[+] Gerando chaves de criptografia...${NC}"
./dnstt-server -gen-key -privkey server.priv -pubkey server.pub &>/dev/null
PRIV_KEY=$(cat server.priv)
PUB_KEY=$(cat server.pub)

# 6. CONFIGURAR FIREWALL (REDIRECIONAMENTO)
echo -e "${CYAN}[+] Configurando IPTABLES...${NC}"
iptables -F
iptables -t nat -F
iptables -I INPUT -p udp --dport $port -j ACCEPT
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports $port
netfilter-persistent save &>/dev/null

# 7. CRIAR SERVIÇO SYSTEMD
echo -e "${CYAN}[+] Criando serviço DNSTT...${NC}"
cat > /etc/systemd/system/slowdns-server.service <<EOF
[Unit]
Description=SlowDNS Server NETSIMON
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/dnstt/dnstt-server
ExecStart=/root/dnstt/dnstt-server -udp :$port -privkey server.priv $ns 127.0.0.1:22
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 8. START
systemctl daemon-reload
systemctl enable slowdns-server
systemctl restart slowdns-server

# 9. VALIDAÇÃO FINAL
if systemctl is-active --quiet slowdns-server; then
    clear
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo -e "${GREEN}       ✅ SLOWDNS ATIVO COM SUCESSO!       ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}NS (Nameserver):${NC} $ns"
    echo -e "${CYAN}Chave Pública  :${NC} ${YELLOW}$PUB_KEY${NC}"
    echo -e "${CYAN}Porta UDP      :${NC} 53 (Redirecionada para $port)"
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo -e "Anote a chave amarela acima para o seu app."
else
    echo -e "${RED}Erro: O serviço não subiu.${NC}"
    echo -e "Log do erro:"
    journalctl -u slowdns-server --no-pager | tail -n 5
fi

read -p "Pressione ENTER para voltar..."
