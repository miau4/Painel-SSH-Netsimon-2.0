#!/bin/bash
# ==========================================
# Instalação do SlowDNS (DNSTT) - Netsimon 2.0
# ==========================================

clear
echo "========================================="
echo "   INSTALADOR SLOWDNS (DNSTT) NETSIMON   "
echo "========================================="
echo ""

# 1. Solicita o NameServer do usuário
read -p "Digite seu NameServer (NS) [ex: ns.seudominio.com]: " NS_DOMAIN
if [ -z "$NS_DOMAIN" ]; then
    echo "Erro: NameServer não pode ficar vazio!"
    exit 1
fi

echo -e "\n[1/5] Instalando dependências e limpando instalações antigas..."
apt-get update -y -q > /dev/null 2>&1
apt-get install -y iptables dnsutils wget unzip > /dev/null 2>&1

# Parar serviços antigos caso existam
systemctl stop slowdns > /dev/null 2>&1
systemctl disable slowdns > /dev/null 2>&1
rm -rf /etc/slowdns
rm -f /etc/systemd/system/slowdns.service

echo "[2/5] Baixando o binário DNSTT-Server..."
cd /usr/local/bin
wget -q -O dnstt-server "https://raw.githubusercontent.com/hidessh99/autoscript-ssh-slowdns/main/dnstt-server"
chmod +x dnstt-server

echo "[3/5] Gerando chaves de criptografia..."
mkdir -p /etc/slowdns
cd /etc/slowdns
/usr/local/bin/dnstt-server -gen > keys.txt
PRIV_KEY=$(cat keys.txt | grep "Private key:" | awk '{print $3}')
PUB_KEY=$(cat keys.txt | grep "Public key:" | awk '{print $3}')

# Salvando os dados para consulta futura
echo "$NS_DOMAIN" > /etc/slowdns/domain
echo "$PUB_KEY" > /etc/slowdns/pub.key
echo "$PRIV_KEY" > /etc/slowdns/priv.key

echo "[4/5] Configurando o serviço de segundo plano (Systemd)..."
cat > /etc/systemd/system/slowdns.service <<EOF
[Unit]
Description=SlowDNS (DNSTT) Server - Netsimon
After=network.target

[Service]
Type=simple
User=root
# O servidor escuta na porta interna 5353 e injeta no SSH local (127.0.0.1:22)
ExecStart=/usr/local/bin/dnstt-server -udp :5353 -privkey-file /etc/slowdns/priv.key $NS_DOMAIN 127.0.0.1:22
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "[5/5] Aplicando regras de Firewall (Iptables)..."
# Removemos regras antigas se existirem
iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353 > /dev/null 2>&1
iptables -D INPUT -p udp --dport 5353 -j ACCEPT > /dev/null 2>&1
iptables -D INPUT -p udp --dport 53 -j ACCEPT > /dev/null 2>&1

# Inserimos as novas regras
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -I INPUT -p udp --dport 5353 -j ACCEPT
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5353

# Salvar iptables (pode variar de OS para OS, usando iptables-persistent)
dpkg-query -W -f='${Status}' iptables-persistent 2>/dev/null | grep -c "ok installed" > /dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent > /dev/null 2>&1
netfilter-persistent save > /dev/null 2>&1

# Iniciar o serviço
systemctl daemon-reload
systemctl enable slowdns > /dev/null 2>&1
systemctl restart slowdns

clear
echo "========================================="
echo "       SLOWDNS INSTALADO COM SUCESSO!    "
echo "========================================="
echo "Utilize os dados abaixo no seu aplicativo cliente:"
echo ""
echo "NameServer (NS) : $NS_DOMAIN"
echo "Chave Pública   : $PUB_KEY"
echo "========================================="
echo "Nota: Certifique-se de que o apontamento NS na"
echo "sua Cloudflare/Registro de Domínio está correto"
echo "e apontando para o IP desta VPS."
echo "========================================="
