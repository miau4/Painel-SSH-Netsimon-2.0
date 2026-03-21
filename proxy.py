#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import socket
import threading
import sys

SSH_HOST = '127.0.0.1'
SSH_PORT = 22
BUFFER_SIZE = 8192

def handle_client(client_socket):
    try:
        request = client_socket.recv(BUFFER_SIZE).decode('utf-8', errors='ignore')
        
        if "Upgrade: websocket" in request or "Connection: Upgrade" in request:
            response = (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                "\r\n"
            )
            client_socket.sendall(response.encode())
            
            target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target_socket.connect((SSH_HOST, SSH_PORT))
            
            t1 = threading.Thread(target=forward, args=(client_socket, target_socket))
            t2 = threading.Thread(target=forward, args=(target_socket, client_socket))
            t1.start()
            t2.start()
        else:
            client_socket.close()
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

def main(listen_port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', listen_port))
    except Exception as e:
        sys.exit(1)
    server.listen(100)
    while True:
        client_sock, addr = server.accept()
        threading.Thread(target=handle_client, args=(client_sock,), daemon=True).start()

if __name__ == "__main__":
    # Agora a porta padrão interna será 8080
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    main(port)
