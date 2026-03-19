#!/bin/bash

USERS="/etc/xray-manager/users.xray"
CONFIG="/etc/xray/config.json"

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
NC='\033[0m'

# ----------------- VALIDAÇÃO -----------------
[ ! -f "$USERS" ] && echo "Arquivo de usuários não encontrado!" && exit

clear
echo -e "${CYAN}══════════════════════════════${NC}"
echo -e "${RED}      ❌ REMOVER USUÁRIO${NC}"
echo -e "${CYAN}══════════════════════════════${NC}"

# ----------------- LISTA -----------------
mapfile -t lista < <(cut -d'|' -f1 "$USERS")

if [ ${#lista[@]} -eq 0 ]; then
    echo "Nenhum usuário encontrado."
    read -n1 -r -p "Pressione qualquer tecla..."
    exit
fi

for i in "${!lista[@]}"; do
    printf "%02d) %s\n" "$((i+1))" "${lista[$i]}"
done

echo ""
read -p "Escolha o número: " num

# ----------------- VALIDAÇÃO -----------------
if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#lista[@]}" ]; then
    echo -e "${RED}Opção inválida!${NC}"
    sleep 2
    exit
fi

user="${lista[$((num-1))]}"

linha=$(grep "^$user|" "$USERS")
uuid=$(echo "$linha" | cut -d'|' -f2)

if [ -z "$uuid" ]; then
    echo -e "${RED}Erro ao localizar UUID!${NC}"
    exit
fi

# ----------------- CONFIRMAÇÃO -----------------
echo ""
echo "Usuário: $user"
read -p "Confirmar remoção? (s/n): " confirm
[[ "$confirm" != "s" && "$confirm" != "S" ]] && exit

# ----------------- REMOVE DB -----------------
tmp_users=$(mktemp)
grep -v "^$user|" "$USERS" > "$tmp_users" && mv "$tmp_users" "$USERS"

# ----------------- REMOVE XRAY -----------------
if [ -f "$CONFIG" ] && command -v jq >/dev/null; then

    tmp=$(mktemp)

    jq --arg uuid "$uuid" '
    .inbounds[0].settings.clients |= map(select(.id != $uuid))
    ' "$CONFIG" > "$tmp"

    if [ $? -eq 0 ] && [ -s "$tmp" ]; then
        mv "$tmp" "$CONFIG"
        systemctl restart xray 2>/dev/null
    else
        echo -e "${RED}Erro ao atualizar config.json${NC}"
        rm -f "$tmp"
    fi

else
    echo "Xray ou jq não disponível — removido apenas do banco"
fi

# ----------------- RESULTADO -----------------
clear
echo -e "${GREEN}══════════════════════════════${NC}"
echo -e "${GREEN}   ✅ USUÁRIO REMOVIDO${NC}"
echo -e "${GREEN}══════════════════════════════${NC}"

echo "Usuário: $user"
echo ""

read -n1 -r -p "Pressione qualquer tecla..."
