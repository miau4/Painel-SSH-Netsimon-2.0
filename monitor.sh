#!/bin/bash
# Cores para o watch -c
G='\e[32m'; R='\e[31m'; C='\e[36m'; Y='\e[33m'; N='\e[0m'

echo -e "${C}══════════════ MONITOR DE SERVIÇOS ══════════════${N}"
printf "${Y}%-15s | %-10s | %-10s${N}\n" "SERVIÇO" "STATUS" "PORTAS"
echo -e "-------------------------------------------------"

# Verificação Individual
SSH_P=$(netstat -tlpn | grep sshd | awk '{print $4}' | cut -d: -f2 | xargs)
echo -e "$(printf "%-15s | %-16s | %-10s" "SSH/SlowDNS" "$([ -n "$SSH_P" ] && echo -e "${G}ON${N}" || echo -e "${R}OFF${N}")" "${SSH_P:-22}")"

XRAY_P=$(grep '"port"' /etc/xray/config.json 2>/dev/null | awk '{print $2}' | sed 's/,//g')
echo -e "$(printf "%-15s | %-16s | %-10s" "Xray Vless" "$(systemctl is-active --quiet xray && echo -e "${G}ON${N}" || echo -e "${R}OFF${N}")" "${XRAY_P:-N/A}")"

WS_P=$(netstat -tlpn | grep python | awk '{print $4}' | cut -d: -f2 | xargs)
echo -e "$(printf "%-15s | %-16s | %-10s" "WebSocket" "$([ -n "$WS_P" ] && echo -e "${G}ON${N}" || echo -e "${R}OFF${N}")" "${WS_P:-N/A}")"

DNS_P=$(pgrep -f dnstt-server >/dev/null && echo -e "${G}ON${N}" || echo -e "${R}OFF${N}")
echo -e "$(printf "%-15s | %-16s | %-10s" "SlowDNS" "$DNS_P" "53")"
echo -e "-------------------------------------------------"
bash /etc/painel/online.sh | tail -n +5 # Mostra o online embaixo
