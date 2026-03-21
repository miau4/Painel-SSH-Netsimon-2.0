#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import socket, threading, sys

# Configurações padrão
SSH_HOST = '127.0.0.1'
SSH_PORT = 22
BUFFER_SIZE = 8192

def handle_client(client_socket):
    try:
        # Espia os primeiros bytes para decidir o protocolo
        request = client_socket.recv(BUFFER_SIZE)
        if not request:
            return
            
        header = request.decode('utf-8', errors='ignore')
        
        # Lógica para WebSocket (Cloudflare/CDN)
        if "Upgrade: websocket" in header or "Connection: Upgrade" in header:
            response = (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n\r\n"
            )
            client_socket.sendall(response.encode())
        
        # Conecta ao SSH local
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((SSH_HOST, SSH_PORT))
        
        # Se não for WS, enviamos o que já lemos para o SSH direto (Socks/HTTP Proxy)
        if "Upgrade: websocket" not in header:
            target_socket.sendall(request)

        # Inicia a ponte
        threading.Thread(target=forward, args=(client_socket, target_socket), daemon=True).start()
        threading.Thread(target=forward, args=(target_socket, client_socket), daemon=True).start()
        
    except Exception:
        client_socket.close()

def forward(source, destination):
    try:
        while True:
            data = source.recv(BUFFER_SIZE)
            if not data: break
            destination.sendall(data)
    except Exception: pass
    finally:
        source.close()
        destination.close()

def main(port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', port))
    except:
        sys.exit(1)
    server.listen(100)
    while True:
        client, _ = server.accept()
        threading.Thread(target=handle_client, args=(client,), daemon=True).start()

if __name__ == "__main__":
    listen_port = int(sys.argv[1]) if len(sys.argv) > 1 else 80
    main(listen_port)
