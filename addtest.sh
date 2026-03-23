#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - GERAR TESTE 2.0
# ==========================================

BASE="/etc/painel"
USERDB="/etc/painel/usuarios.db"
XRAY_CONF="/etc/xray/config.json"

# Cores Estilo WebSocket
P='\033[1;35m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; C='\033[1;36m'; B='\033[1;34m'; NC='\033[0m'

clear
echo -e "${P}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${P}║${W}                ⏳ GERAR TESTE TEMPORÁRIO                     ${P}║${NC}"
echo -e "${P}╚══════════════════════════════════════════════════════════════╝${NC}"

read -p " Nome do Teste: " user
[[ -z "$user" ]] && exit 1
if id "$user" &>/dev/null; then echo -e "\n${R}Erro: Usuário já existe!${NC}"; sleep 2; exit 1; fi

echo -e "\n${W}Duração do teste:${NC}"
echo -e " ${G}1)${W} 1 Hora"
echo -e " ${G}2)${W} 2 Horas"
echo -e " ${G}3)${W} 3 Horas"
echo -ne "\n${Y} Opção: ${NC}"; read h_opt

case $h_opt in
    1) t_hours=1 ;;
    2) t_hours=2 ;;
    3) t_hours=3 ;;
    *) t_hours=1 ;;
esac

# Gerando Senha e UUID
pass=$((RANDOM%9000+1000))
uuid=$(cat /proc/sys/kernel/random/uuid)

# Criando no Linux (SSH/WS)
useradd -M -s /bin/false "$user"
echo "$user:$pass" | chpasswd

# Adicionando ao Xray (VLESS)
if [ -f "$XRAY_CONF" ]; then
    tmp=$(mktemp)
    jq --arg u "$user" --arg id "$uuid" '.inbounds[0].settings.clients += [{"id": $id, "alterId": 0, "email": $u}]' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
    systemctl restart xray > /dev/null 2>&1
fi

# Salvando no Banco de Dados Unificado
exp_time=$(date -d "+$t_hours hours" +"%H:%M:%S")
echo "$user|$uuid|Teste-$exp_time|$pass|1" >> "$USERDB"

# Agendamento de remoção automática
(sleep $((t_hours * 3600)) && bash "$BASE/deluser.sh" "$user" --auto) &

clear
echo -e "${G}✅ TESTE CRIADO COM SUCESSO!${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
printf "${W} Usuário : ${Y}%-20s ${W} Senha  : ${Y}%-10s${NC}\n" "$user" "$pass"
printf "${W} Validade: ${G}%-20s ${W} Limite : ${Y}%-10s${NC}\n" "$t_hours Hora(s)" "1"
echo -e "${W} UUID    : ${C}$uuid${NC}"
echo -e "${P}────────────────────────────────────────────────────────────────${NC}"
read -p "Pressione ENTER para voltar..."
