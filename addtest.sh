#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - TESTE RÁPIDO 2.0
# ==========================================

BASE="/etc/painel"
USERDB="/etc/painel/usuarios.db"
XRAY_CONF="/usr/local/etc/xray/config.json"
LOG_LIMIT="/var/log/netsimon_limit.log"

# Cores Estilo WebSocket
P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; B='\033[1;34m'; NC='\033[0m'

clear
echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${P}║${W}                ⚡ GERAR TESTE TEMPORÁRIO 2.0                 ${P}║${NC}"
echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"

# Gerar nome aleatório se o admin não quiser digitar
read -p " Nome do Teste (ou Enter para aleatório): " user
if [[ -z "$user" ]]; then
    user="teste$(base64 /dev/urandom | tr -d '/+' | head -c 4 | tr '[:upper:]' '[:lower:]')"
fi

# Verificar duplicatas
if grep -qw "$user" "$USERDB" || id "$user" &>/dev/null; then 
    echo -e "\n${R}Erro: Usuário '$user' já existe!${NC}"; sleep 2; exit 1; 
fi

read -p " Senha (Padrão 123): " pass
[[ -z "$pass" ]] && pass="123"

echo -e "${W}Tempo de duração (ex: 30m, 1h, 2h):${NC}"
read -p " Duração: " tempo
[[ -z "$tempo" ]] && tempo="30m"

# 1. Configuração no Sistema
useradd -M -s /bin/false "$user" &>/dev/null
echo "$user:$pass" | chpasswd &>/dev/null

# 2. Xray (VLESS/xHTTP)
uuid=$(cat /proc/sys/kernel/random/uuid)
if [ -f "$XRAY_CONF" ]; then
    tmp=$(mktemp)
    jq --arg u "$user" --arg id "$uuid" \
    '(.inbounds[] | select(.port == 443)).settings.clients += [{"id": $id, "email": $u}]' \
    "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
    systemctl restart xray > /dev/null 2>&1
fi

# 3. Banco de Dados (Validade hoje, pois é teste)
exp=$(date +"%Y-%m-%d")
echo "$user|$uuid|$exp|$pass|1" >> "$USERDB"

# 4. O PULO DO GATO: Agendamento da Auto-Destruição
# Usamos o comando 'at' para chamar o deluser.sh no futuro
if command -v at &>/dev/null; then
    echo "bash $BASE/deluser.sh $user --auto" | at now + $tempo &>/dev/null
    AVISO_AUTO="${G}AUTO-REMOÇÃO ATIVADA EM: ${Y}$tempo${NC}"
else
    # Se não tiver 'at', instala rapidinho
    apt install at -y &>/dev/null
    systemctl enable --now atd &>/dev/null
    echo "bash $BASE/deluser.sh $user --auto" | at now + $tempo &>/dev/null
    AVISO_AUTO="${G}AUTO-REMOÇÃO ATIVADA EM: ${Y}$tempo${NC}"
fi

clear
echo -e "${G}✅ CONTA DE TESTE CRIADA!${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
printf "${W} Usuário : ${Y}%-20s ${W} Senha  : ${Y}%-10s${NC}\n" "$user" "$pass"
printf "${W} Duração : ${Y}%-20s ${W} Limite : ${Y}%-10s${NC}\n" "$tempo" "1"
echo -e "${W} UUID    : ${C}$uuid${NC}"
echo -e "${AVISO_AUTO}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
echo "$(date '+%d/%m/%Y %H:%M:%S') - SISTEMA: Teste $user criado por $tempo." >> "$LOG_LIMIT"
read -p "Pressione ENTER para voltar..."
