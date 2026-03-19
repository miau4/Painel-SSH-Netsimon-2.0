#!/bin/bash

# ===============================
# CONFIGURAÇÕES E CORES
# ===============================
BASE="/etc/painel"
XRAY_MGR="/etc/xray-manager"
REPO="https://raw.githubusercontent.com/miau4/Painel-SSH-Netsimon/main"

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Lista de arquivos que DEVEM estar no seu repositório GitHub
FILES=(
"menu.sh"
"xray.sh"
"websocket.sh"
"slowdns-server.sh"
"adduser.sh"
"deluser.sh"
"online.sh"
"limit.sh"
"unblock.sh"
)

clear
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}    INSTALADOR NETSIMON ENTERPRISE 2.0    ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"

# 1. ROOT CHECK
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Erro: Execute como root!${NC}"
    exit 1
fi

# 2. INSTALAR DEPENDÊNCIAS
echo -e "${YELLOW}[1/5] Instalando dependências essenciais...${NC}"
apt update -y
apt install -y curl wget jq nginx golang bsdmainutils &>/dev/null

# 3. CRIAR ESTRUTURA DE PASTAS E BANCO
echo -e "${YELLOW}[2/5] Criando estrutura de diretórios...${NC}"
mkdir -p "$BASE"
mkdir -p "$XRAY_MGR"
mkdir -p "/etc/xray"

# Criando arquivos de banco de dados se não existirem
[ ! -f "$XRAY_MGR/users.db" ] && touch "$XRAY_MGR/users.db"
[ ! -f "$XRAY_MGR/blocked.db" ] && touch "$XRAY_MGR/blocked.db"

# 4. DOWNLOAD DOS ARQUIVOS DO GITHUB
echo -e "${YELLOW}[3/5] Baixando scripts do repositório...${NC}"

for file in "${FILES[@]}"; do
    echo -e "  ${CYAN}下载:${NC} $file"
    # Baixa o arquivo do GitHub sobrescrevendo o antigo
    wget -q -O "$BASE/$file" "$REPO/$file"

    if [ ! -s "$BASE/$file" ]; then
        echo -e "${RED}Erro crítico: Falha ao baixar $file${NC}"
        echo -e "${YELLOW}Verifique se o nome do arquivo no GitHub está correto.${NC}"
        exit 1
    fi
    chmod +x "$BASE/$file"
done

# 5. CONFIGURAÇÃO GLOBAL E ATALHOS
echo -e "${YELLOW}[4/5] Configurando atalhos do sistema...${NC}"

# Atalho 'p' ou 'menu' para abrir o painel
cat > "/usr/local/bin/p" <<EOF
#!/bin/bash
bash $BASE/menu.sh
EOF
chmod +x "/usr/local/bin/p"
ln -sf /usr/local/bin/p /usr/local/bin/menu

# 6. CONFIGURAÇÃO INICIAL DO XRAY (Evita erro de JSON vazio)
if [ ! -f /etc/xray/config.json ]; then
    echo -e "${YELLOW}[5/5] Criando config base do Xray...${NC}"
    cat > /etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
fi

# ===============================
# FINALIZAÇÃO
# ===============================
clear
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}       INSTALAÇÃO CONCLUÍDA COM SUCESSO!  ${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${WHITE}Comando para abrir o painel:${NC} ${YELLOW}p${NC} ou ${YELLOW}menu${NC}"
echo -e "${CYAN}Diretório dos scripts:${NC} $BASE"
echo -e "${GREEN}══════════════════════════════════════════${NC}"

read -p "Deseja abrir o painel agora? (s/n): " abrir
[[ "$abrir" == "s" || "$abrir" == "S" ]] && bash "$BASE/menu.sh"
