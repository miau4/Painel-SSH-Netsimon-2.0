#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - LIMITADOR HÍBRIDO
# ==========================================

# Caminhos unificados conforme o padrão 2.0
USERDB="/etc/painel/usuarios.db"
XRAY_LOG="/var/log/xray/access.log"
LOG_LIMIT="/var/log/netsimon_limit.log"

# Cores para o Log Manual (caso rode em primeiro plano)
RED='\033[1;31m'; GREEN='\033[1;32m'; YEL='\033[1;33m'; NC='\033[0m'

# Garante que os arquivos existam e tenham permissão
touch "$LOG_LIMIT"
chmod 666 "$LOG_LIMIT"
[ ! -f "$XRAY_LOG" ] && touch "$XRAY_LOG" && chmod 666 "$XRAY_LOG"

echo -e "${GREEN}[+] MONITOR DE CONEXÕES NETSIMON ATIVADO...${NC}"

while true; do
    # Verifica se o banco de dados existe antes de processar
    if [ ! -f "$USERDB" ] || [ ! -s "$USERDB" ]; then
        sleep 10
        continue
    fi

    # Lendo o Banco de Dados Unificado (user|uuid|exp|pass|limit)
    while IFS='|' read -r user uuid exp pass limit; do
        # Pula linhas vazias ou comentários
        [[ -z "$user" || "$user" =~ ^# ]] && continue
        
        # 1. CONTAGEM SSH (Processos ativos do usuário logado)
        # O grep -w garante que não conte usuários com nomes parecidos (ex: 'user' e 'user1')
        contagem_ssh=$(ps aux | grep -i sshd | grep -v root | grep -v grep | grep -w "$user" | wc -l)

        # 2. CONTAGEM XRAY (IPs Únicos nos logs recentes)
        # PULO DO GATO: Filtramos as últimas 200 linhas do log para ver conexões 'accepted'
        # O awk pega o IP (coluna 6 ou 7 dependendo da config) e o sort -u conta IPs únicos
        if [ -f "$XRAY_LOG" ]; then
            # Captura conexões ativas do protocolo VLESS/xHTTP associadas ao email (user)
            contagem_xray=$(tail -n 200 "$XRAY_LOG" | grep "$user" | grep "accepted" | awk '{print $6}' | cut -d: -f1 | sort -u | wc -l)
        else
            contagem_xray=0
        fi

        # Soma total de conexões reais do cliente
        total_conexoes=$((contagem_ssh + contagem_xray))

        # 3. VERIFICAÇÃO DE ABUSO (Comparação com o limite do banco)
        if [[ "$total_conexoes" -gt "$limit" ]]; then
            # Registro de auditoria para o administrador
            DATA_LOG=$(date '+%d/%m/%Y %H:%M:%S')
            echo "$DATA_LOG - BLOQUEIO: $user | Limite: $limit | Atual: $total_conexoes (SSH:$contagem_ssh Xray:$contagem_xray)" >> "$LOG_LIMIT"
            
            # --- PROTOCOLO DE EXPULSÃO ---
            
            # A) Derruba todas as sessões SSH/WebSocket do usuário imediatamente
            pkill -u "$user" -f sshd &>/dev/null
            pkill -u "$user" -f "proxy.py" &>/dev/null # Se estiver usando proxy python por usuário
            
            # B) PULO DO GATO XRAY: 
            # O Xray não permite derrubar um ID sem reiniciar o serviço ou usar a API.
            # Para não derrubar todos os clientes com 'systemctl restart', limpamos os sockets órfãos
            # Isso força o app do cliente a tentar reconectar, onde ele baterá no limite de novo.
            lsof -ti tcp:443 -u "$user" | xargs kill -9 &>/dev/null 
            
            # C) Log visual se rodar em modo debug
            echo -e "${RED}[$DATA_LOG] Usuário $user desconectado! ($total_conexoes/$limit)${NC}"
        fi
    done < "$USERDB"

    # Intervalo de Varredura: 10 segundos para não estressar a CPU da Oracle
    sleep 10
done
