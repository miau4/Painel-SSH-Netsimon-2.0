#!/bin/bash

clear
echo "===================================="
echo "   INSTALADOR NETSIMON ENTERPRISE"
echo "===================================="

# ===============================
# ROOT CHECK
# ===============================
if [ "$EUID" -ne 0 ]; then
    echo "Execute como root!"
    exit 1
fi

# ===============================
# VARIÁVEIS
# ===============================
BASE="/etc/painel"
REPO="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon/main"

FILES=(
menu.sh
xray.sh
websocket.sh
slowdns-server.sh
adduser.sh
deluser.sh
online.sh
limit.sh
unblock.sh
)

# ===============================
# INSTALAR DEPENDÊNCIAS
# ===============================
echo "[+] Instalando dependências..."
apt update -y
apt install -y curl wget jq nginx

# ===============================
# CRIAR ESTRUTURA
# ===============================
echo "[+] Criando estrutura..."
mkdir -p $BASE
mkdir -p /etc/xray-manager

touch /etc/xray-manager/users.xray
touch /etc/xray-manager/blocked.db

# ===============================
# DOWNLOAD DOS ARQUIVOS
# ===============================
echo "[+] Baixando arquivos..."

for file in "${FILES[@]}"; do
    echo " - $file"

    wget -q -O $BASE/$file $REPO/$file

    if [ ! -s "$BASE/$file" ]; then
        echo "Erro ao baixar $file"
        exit 1
    fi
done

# ===============================
# PERMISSÕES
# ===============================
chmod +x $BASE/*.sh

# ===============================
# COMANDO GLOBAL
# ===============================
ln -sf $BASE/menu.sh /usr/local/bin/menu
chmod +x /usr/local/bin/menu

# ===============================
# XRAY CONFIG BASE
# ===============================
if [ ! -f /etc/xray/config.json ]; then
    echo "[+] Criando config base do Xray..."

    mkdir -p /etc/xray

    cat > /etc/xray/config.json <<EOF
{
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
fi

# ===============================
# FINAL
# ===============================
echo ""
echo "===================================="
echo " INSTALAÇÃO CONCLUÍDA"
echo "===================================="
echo "Comando: menu"
echo ""
