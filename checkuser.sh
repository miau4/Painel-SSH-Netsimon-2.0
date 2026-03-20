cat << 'EOF' > /etc/painel/checkuser.sh
#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - CHECKUSER API
# ==========================================

C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'

install_deps() {
    if ! command -v pip3 &>/dev/null; then
        apt install python3-pip -y &>/dev/null
    fi
    pip3 install flask &>/dev/null
}

check_status() {
    pgrep -f "checkuser.py" > /dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}"
}

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                🆔 CHECKUSER API MANAGER                      ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
install_deps

echo -e " Status da API: $(check_status)"
echo -e " Link de Consulta: ${Y}http://$(wget -qO- ifconfig.me):5000/check/USUARIO${NC}"
echo -e "--------------------------------------------"
echo -e " 1) Iniciar API CheckUser"
echo -e " 2) Parar API CheckUser"
echo -e " 3) Ver Logs de Requisições"
echo -e " 0) Voltar"
echo -ne "\n${Y}Escolha: ${NC}"; read opt

case $opt in
    1)
        nohup python3 /etc/painel/checkuser.py > /dev/null 2>&1 &
        echo -e "${G}API Iniciada na porta 5000!${NC}"
        ;;
    2)
        pkill -f "checkuser.py"
        echo -e "${R}API Parada!${NC}"
        ;;
    3)
        echo -e "${Y}Mostrando acessos em tempo real...${NC}"
        netstat -anp | grep :5000
        read -p "Pressione ENTER..."
        ;;
    *) exit 0 ;;
esac
sleep 1
EOF
chmod +x /etc/painel/checkuser.sh
