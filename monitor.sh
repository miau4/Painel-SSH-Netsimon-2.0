cat << 'EOF' > /etc/painel/monitor.sh
#!/bin/bash
# MONITOR DE RECURSOS NETSIMON
G='\033[1;32m'; R='\033[1;31m'; C='\033[1;36m'; W='\033[1;37m'; NC='\033[0m'

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}            📊 MONITOR DE RECURSOS EM TEMPO REAL             ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "${W}CPU:${NC} $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%"
echo -e "${W}MEMÓRIA:${NC} $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
echo -e "${W}CONEXÕES SSH:${NC} $(ss -tnp | grep ":22" | grep "ESTAB" | wc -l)"
echo -e "${W}CONEXÕES XRAY:${NC} $(ss -tnp | grep -E ":443|:80" | grep "xray" | wc -l 2>/dev/null || echo 0)"
echo -e "${C}══════════════════════════════════════════════════════════════${NC}"
echo -e "${Y}Pressione CTRL+C para sair do monitor.${NC}"
EOF
chmod +x /etc/painel/monitor.sh
