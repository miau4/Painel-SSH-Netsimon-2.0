#!/bin/bash
# ==========================================
#    NETSIMON ENTERPRISE - WEBSOCKET & SOCKS
# ==========================================

# Definição de Cores (Paleta Enterprise)
C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'
W='\033[1;37m'; P='\033[1;35m'; B='\033[1;34m'; NC='\033[0m'

DIR="/etc/painel"
PROXY_PY="$DIR/proxy.py"

# Criar diretório se não existir
[[ ! -d "$DIR" ]] && mkdir -p "$DIR"

# Funções de Status
status_ws_80() { pgrep -f "proxy.py 80$" > /dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}"; }
status_ws_8080() { pgrep -f "proxy.py 8080$" > /dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}"; }

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}           🌐  NETSIMON WEBSOCKET & SOCKS MANAGER           ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
echo -e " ${W}Status WebSocket 80:   $(status_ws_80)   ${W}Status WebSocket 8080: $(status_ws_8080)${NC}"
echo -e "${C}────────────────────────────────────────────────────────────────${NC}"
echo -e " ${G}1)${W} Iniciar WebSocket ${C}(Porta 80)${NC}"
echo -e " ${G}2)${W} Iniciar WebSocket ${C}(Porta 8080)${NC}"
echo -e " ${R}3)${W} Parar WebSocket${NC}"
echo -e "${C}────────────────────────────────────────────────────────────────${NC}"
echo -e " ${B}4)${W} Iniciar Proxy Socks ${P}(Porta 80)${NC}"
echo -e " ${B}5)${W} Iniciar Proxy Socks ${P}(Porta 8080)${NC}"
echo -e " ${R}6)${W} Parar Proxy Socks${NC}"
echo -e "${C}────────────────────────────────────────────────────────────────${NC}"
echo -e " ${Y}7)${W} Portas Ativas${NC}"
echo -e " ${W}0)${W} Voltar ao Menu Principal${NC}"
echo -e "${C}────────────────────────────────────────────────────────────────${NC}"
echo -ne "${Y} Selecione uma opção: ${NC}"; read opt

case $opt in
    1)
        if pgrep -f "proxy.py 80$" > /dev/null; then
            echo -e "\n${Y}[!] WebSocket já está rodando na porta 80.${NC}"
        else
            nohup python3 "$PROXY_PY" 80 > /dev/null 2>&1 &
            echo -e "\n${G}[OK] WebSocket iniciado na porta 80!${NC}"
        fi
        sleep 2; $DIR/websocket.sh ;;
    2)
        if pgrep -f "proxy.py 8080$" > /dev/null; then
            echo -e "\n${Y}[!] WebSocket já está rodando na porta 8080.${NC}"
        else
            nohup python3 "$PROXY_PY" 8080 > /dev/null 2>&1 &
            echo -e "\n${G}[OK] WebSocket iniciado na porta 8080!${NC}"
        fi
        sleep 2; $DIR/websocket.sh ;;
    3)
        pkill -f "proxy.py 80$" 2>/dev/null
        pkill -f "proxy.py 8080$" 2>/dev/null
        echo -e "\n${R}[!] Todos os WebSockets foram parados.${NC}"
        sleep 2; $DIR/websocket.sh ;;
    4)
        # O Proxy Socks usa o mesmo motor do proxy.py
        if pgrep -f "proxy.py 80$" > /dev/null; then
            echo -e "\n${Y}[!] Porta 80 já está ocupada.${NC}"
        else
            nohup python3 "$PROXY_PY" 80 > /dev/null 2>&1 &
            echo -e "\n${G}[OK] Proxy Socks iniciado na porta 80!${NC}"
        fi
        sleep 2; $DIR/websocket.sh ;;
    5)
        if pgrep -f "proxy.py 8080$" > /dev/null; then
            echo -e "\n${Y}[!] Porta 8080 já está ocupada.${NC}"
        else
            nohup python3 "$PROXY_PY" 8080 > /dev/null 2>&1 &
            echo -e "\n${G}[OK] Proxy Socks iniciado na porta 8080!${NC}"
        fi
        sleep 2; $DIR/websocket.sh ;;
    6)
        pkill -f "proxy.py 80$" 2>/dev/null
        pkill -f "proxy.py 8080$" 2>/dev/null
        echo -e "\n${R}[!] Proxy Socks desativado.${NC}"
        sleep 2; $DIR/websocket.sh ;;
    7)
        echo -e "\n${C}══════════════ PORTAS ATIVAS (PYTHON) ══════════════${NC}"
        netstat -tunlp | grep python3 | awk '{print $4 " -> " $7}' | sed 's/0.0.0.0://g'
        echo -e "${C}════════════════════════════════════════════════════${NC}"
        read -p "Pressione ENTER para voltar..."
        $DIR/websocket.sh ;;
    0) exit 0 ;;
    *) echo -e "\n${R}Opção Inválida!${NC}"; sleep 1; $DIR/websocket.sh ;;
esac
