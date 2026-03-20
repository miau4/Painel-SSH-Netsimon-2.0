#!/bin/bash
# NETSIMON ENTERPRISE - CRIAR TESTE TEMPORÁRIO
BASE="/etc/painel"
USERDB="/etc/xray-manager/users.db"
XRAY_CONF="/etc/xray/config.json"

# Cores
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}               ⏳ GERAR TESTE TEMPORÁRIO                      ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

read -p " Nome do Teste: " user
[[ -z "$user" ]] && exit 1
if id "$user" &>/dev/null; then echo -e "${R}Usuário já existe!${NC}"; sleep 2; exit 1; fi

echo -e "\n${W}Escolha a duração:${NC}"
echo -e " 1) 1 Hora"
echo -e " 2) 2 Horas"
echo -e " 3) 3 Horas"
read -p " Opção: " h_opt

case $h_opt in
    1) t_hours=1 ;;
    2) t_hours=2 ;;
    3) t_hours=3 ;;
    *) t_hours=1 ;;
esac

pass=$((RANDOM%9000+1000)) # Gera senha aleatória de 4 dígitos para o teste
uuid=$(cat /proc/sys/kernel/random/uuid)

# Criação no Sistema
useradd -M -s /bin/false "$user"
echo "$user:$pass" | chpasswd

# Adição no Xray
if [ -f "$XRAY_CONF" ]; then
    tmp=$(mktemp)
    jq --arg u "$user" --arg id "$uuid" '.inbounds[0].settings.clients += [{"id": $id, "alterId": 0, "email": $u}]' "$XRAY_CONF" > "$tmp" && mv "$tmp" "$XRAY_CONF"
    systemctl restart xray
fi

# Salva no Banco com marcação de expiração curta
exp=$(date -d "+$t_hours hours" +"%H:%M:%S")
echo "$user|$uuid|Teste-$exp|$pass|1" >> "$USERDB"

# AGENDAMENTO DA REMOÇÃO AUTOMÁTICA (Background)
# Ele vai esperar o tempo em segundos e rodar o deluser.sh
(sleep $((t_hours * 3600)) && bash "$BASE/deluser.sh" "$user" --auto) &

clear
echo -e "${Y}✅ TESTE GERADO COM SUCESSO!${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
echo -e "${W} Usuário : ${G}$user${NC}"
echo -e "${W} Senha   : ${G}$pass${NC}"
echo -e "${W} UUID    : ${G}$uuid${NC}"
echo -e "${W} Duração : ${G}$t_hours Hora(s)${NC}"
echo -e "${W} Status  : ${R}Exclusão Automática Ativa${NC}"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
read -p "Pressione ENTER..."
