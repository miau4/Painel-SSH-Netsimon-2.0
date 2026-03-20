#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - LIMITADOR HÍBRIDO
# ==========================================

USERDB="/etc/xray-manager/users.db"
XRAY_LOG="/var/log/xray/access.log"
LOG_LIMIT="/var/log/netsimon_limit.log"

# Cores para o Log Manual
RED='\033[1;31m'; GREEN='\033[1;32m'; NC='\033[0m'

# Garante que os arquivos existam
touch "$LOG_LIMIT"
[ ! -f "$XRAY_LOG" ] && touch "$XRAY_LOG"

while true; do
    if [ ! -f "$USERDB" ]; then
        sleep 10
        continue
    fi

    # Lendo o Banco de Dados (user|uuid|exp|pass|limit)
    while IFS='|' read -r user uuid exp pass limit; do
        [[ -z "$user" || "$user" =~ ^# ]] && continue
        
        # 1. CONTAGEM SSH (Processos ativos)
        contagem_ssh=$(ps aux | grep -i sshd | grep -v root | grep -v grep | grep "$user" | wc -l)

        # 2. CONTAGEM XRAY (IPs Únicos nos últimos 60 segundos)
        # Filtra o log pelo e-mail do usuário e conta quantos IPs diferentes aparecem
        if [ -f "$XRAY_LOG" ]; then
            contagem_xray=$(tail -n 100 "$XRAY_LOG" | grep "$user" | grep "accepted" | awk '{print $6}' | cut -d: -f1 | sort -u | wc -l)
        else
            contagem_xray=0
        fi

        # Soma total de conexões reais
        total_conexoes=$((contagem_ssh + contagem_xray))

        # 3. VERIFICAÇÃO DE ABUSO
        if [[ "$total_conexoes" -gt "$limit" ]]; then
            # Registra no log o motivo da queda
            echo "$(date '+%d/%m/%Y %H:%M:%S') - BLOQUEIO: $user | Limite: $limit | Atual: $total_conexoes (SSH:$contagem_ssh Xray:$contagem_xray)" >> "$LOG_LIMIT"
            
            # Derruba SSH
            pkill -u "$user" -f sshd
            
            # Para o Xray, como é um serviço compartilhado, o "derrubar" é via desconexão 
            # de sockets ou forçando o restart se o abuso for crítico (opcional)
            # systemctl restart xray (Use com cautela para não derrubar todos)
        fi
    done < "$USERDB"

    # Intervalo de Varredura (10s é o equilíbrio entre precisão e CPU)
    sleep 10
done
