#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - CRIAR USUÁRIO 2.0
# ==========================================

# Caminhos Corrigidos conforme análise do sistema
BASE="/etc/painel"
USERDB="/etc/painel/usuarios.db"
# Ajustado para o caminho que o systemctl está lendo de fato:
XRAY_CONF="/usr/local/etc/xray/config.json"

# Criar diretórios se não existirem
[[ ! -d "$BASE" ]] && mkdir -p "$BASE"
[[ ! -f "$USERDB" ]] && touch "$USERDB"

# Cores Estilo WebSocket
P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; B='\033[1;34m'; NC='\033[0m'

clear
echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${P}║${W}                🚀 CRIAR NOVO USUÁRIO PRO                     ${P}║${NC}"
echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"

read -p " Nome do Usuário: " user
[[ -z "$user" ]] && exit 1

# Verificar se usuário já existe no sistema ou no banco
if grep -qw "$user" "$USERDB" || id "$user" &>/dev/null; then 
    echo -e "\n${R}Erro: Usuário já existe!${NC}"; sleep 2; exit 1; 
fi

read -p " Senha (SSH/Proxy): " pass
[[ -z "$pass" ]] && pass="1234"

read -p " Dias de Validade: " dias
[[ -z "$dias" ]] && dias=30

read -p " Limite de Conexões: " limite
[[ -z "$limite" ]] && limite=1

# Configuração no Sistema (Linux/SSH/WS)
useradd -M -s /bin/false "$user" &>/dev/null
echo "$user:$pass" | chpasswd &>/dev/null

# Gerar UUID Único para Xray
uuid=$(cat /proc/sys/kernel/random/uuid)

# Injetar no Xray (Lógica xHTTP sem alterId)
if [ -f "$XRAY_CONF" ]; then
    # Usamos o jq para procurar especificamente pelo inbound que NÃO é a API (porta 443)
    # E removemos o alterId para compatibilidade total com VLESS/xHTTP
    tmp=$(mktemp)
    jq --arg u "$user" --arg id "$uuid" \
    '(.inbounds[] | select(.port == 443)).settings.clients += [{"id": $id, "email": $u}]' \
    "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
    
    # Reinício limpo do serviço
    systemctl restart xray > /dev/null 2>&1
fi

# Salvar no Banco Único
exp=$(date -d "+$dias days" +"%Y-%m-%d")
echo "$user|$uuid|$exp|$pass|$limite" >> "$USERDB"

clear
echo -e "${G}✅ USUÁRIO CRIADO COM SUCESSO!${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
printf "${W} Usuário : ${Y}%-20s ${W} Senha  : ${Y}%-10s${NC}\n" "$user" "$pass"
printf "${W} Validade: ${Y}%-20s ${W} Limite : ${Y}%-10s${NC}\n" "$exp" "$limite"
echo -e "${W} UUID    : ${C}$uuid${NC}"
echo -e "${W} Protocol: ${B}VLESS / xHTTP${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
read -p "Pressione ENTER para voltar..."
