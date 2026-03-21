#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import socket
import threading
import sys

# Configurações de destino (Onde o SSH está rodando)
SSH_HOST = '127.0.0.1'
SSH_PORT = 22
BUFFER_SIZE = 8192

def handle_client(client_socket):
    try:
        # Recebe o cabeçalho inicial da requisição (Handshake)
        request = client_socket.recv(BUFFER_SIZE).decode('utf-8', errors='ignore')
        
        # Verifica se é uma requisição WebSocket ou conexão via Cloudflare
        if "Upgrade: websocket" in request or "Connection: Upgrade" in request:
            # Responde ao cliente/Cloudflare que a troca de protocolo foi aceita
            response = (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                "\r\n"
            )
            client_socket.sendall(response.encode())
            
            # Conecta ao serviço SSH local
            target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target_socket.connect((SSH_HOST, SSH_PORT))
            
            # Inicia o encaminhamento bidirecional (Full-Duplex)
            t1 = threading.Thread(target=forward, args=(client_socket, target_socket))
            t2 = threading.Thread(target=forward, args=(target_socket, client_socket))
            t1.start()
            t2.start()
        else:
            # Se não for WebSocket, fecha a conexão para segurança
            client_socket.close()
            
    except Exception:
        client_socket.close()

def forward(source, destination):
    try:
        while True:
            data = source.recv(BUFFER_SIZE)
            if not data:
                break
            destination.sendall(data)
    except Exception:
        pass
    finally:
        source.close()
        destination.close()

def main(listen_port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind(('0.0.0.0', listen_port))
    except Exception as e:
        print(f"Erro ao iniciar na porta {listen_port}: {e}")
        sys.exit(1)
        
    server.listen(100)
    
    while True:
        client_sock, addr = server.accept()
        client_thread = threading.Thread(target=handle_client, args=(client_sock,))
        client_thread.daemon = True
        client_thread.start()

if __name__ == "__main__":
    # Define a porta via argumento ou padrão 80
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 80
    main(port)
