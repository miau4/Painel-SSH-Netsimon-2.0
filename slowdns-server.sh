#!/bin/bash
# ==========================================
#   NETSIMON ENTERPRISE - SLOWDNS MANAGER 2.0
# ==========================================

C='\033[1;36m'; G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; W='\033[1;37m'; NC='\033[0m'
DNS_DIR="/etc/slowdns"
BIN="$DNS_DIR/dns-server"

# Função para pegar o IP Limpo (sem HTML)
get_ip() {
    local ip=$(wget -qO- ipv4.icanhazip.com || wget -qO- ifconfig.me/ip)
    echo "$ip"
}

# Instalação e Geração de Chaves
install_bin() {
    mkdir -p "$DNS_DIR"
    if [ ! -f "$BIN" ]; then
        echo -e "${Y}[!] Baixando binário oficial...${NC}"
        wget -q -O "$BIN" "https://github.com/miau4/Painel-SSH-Netsimon-2.0/raw/main/dns-server"
        chmod +x "$BIN"
    fi
    
    # Se a chave pública não existe, tenta gerar
    if [ ! -f "$DNS_DIR/server.pub" ]; then
        echo -e "${Y}[!] Gerando novo par de chaves...${NC}"
        cd "$DNS_DIR"
        ./dns-server -gen-key -privkey-file server.key -pubkey-file server.pub &>/dev/null
        cd - &>/dev/null
    fi
}

check_status() {
    pgrep -f "dns-server" > /dev/null && echo -e "${G}ON${NC}" || echo -e "${R}OFF${NC}"
}

clear
echo -e "${C}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C}║${W}                🛰️  SLOWDNS ENTERPRISE MANAGER                 ${C}║${NC}"
echo -e "${C}╚══════════════════════════════════════════════════════════════╝${NC}"
install_bin

# Verificação se as chaves foram realmente criadas
if [ ! -f "$DNS_DIR/server.pub" ]; then
    echo -e "${R}[!] ERRO: As chaves não foram geradas. Verifique o binário.${NC}"
    pub_key="NÃO GERADA"
else
    pub_key=$(cat "$DNS_DIR/server.pub")
fi

echo -e " Status Atual: $(check_status)"
echo -e " Chave Pública: ${Y}$pub_key${NC}"
echo -e "--------------------------------------------"
echo -e " 1) Configurar e Iniciar SlowDNS"
echo -e " 2) Parar SlowDNS"
echo -e " 3) Ver Dados de Conexão (Para o App)"
echo -e " 0) Voltar"
echo -ne "\n${Y}Escolha: ${NC}"; read opt

case $opt in
    1)
        if pgrep -f "dns-server" > /dev/null; then
            echo -e "${Y}SlowDNS já está rodando! Pare primeiro para reconfigurar.${NC}"
        else
            echo -ne "${W}Digite seu NameServer (NS): ${NC}"; read ns
            [ -z "$ns" ] && echo -e "${R}NS Obrigatório!${NC}" && sleep 2 && exit 1
            
            echo "$ns" > "$DNS_DIR/ns_name"
            echo -ne "${W}Porta de Redirecionamento (SSH/Xray): ${NC}"; read port
            [ -z "$port" ] && port="22"

            # Libera a porta 53
            systemctl stop systemd-resolved &>/dev/null
            
            echo -e "${Y}Iniciando serviço...${NC}"
            nohup "$BIN" -udp :53 -privkey-file "$DNS_DIR/server.key" "$ns" 127.0.0.1:"$port" > /dev/null 2>&1 &
            sleep 2
            echo -e "${G}[OK] SlowDNS em execução!${NC}"
        fi
        ;;
    2)
        pkill -f "dns-server"
        systemctl start systemd-resolved &>/dev/null
        echo -e "${R}SlowDNS Parado e DNS do Sistema Restaurado!${NC}"
        ;;
    3)
        clear
        if [ ! -f "$DNS_DIR/server.pub" ]; then
             echo -e "${R}Erro: Chave pública não encontrada!${NC}"
        else
            ns_atual=$(cat "$DNS_DIR/ns_name" 2>/dev/null || echo "NÃO CONFIGURADO")
            echo -e "${G}--- DADOS DE CONFIGURAÇÃO NO APP ---${NC}"
            echo -e "${W}DNS/IP do Servidor: ${C}$(get_ip)${NC}"
            echo -e "${W}Chave Pública:      ${C}$(cat $DNS_DIR/server.pub)${NC}"
            echo -e "${W}NameServer (NS):    ${Y}$ns_atual${NC}"
            echo -e "------------------------------------"
        fi
        read -p "Pressione ENTER para voltar..."
        ;;
    *) exit 0 ;;
esac
