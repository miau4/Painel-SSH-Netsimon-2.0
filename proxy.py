import socket, threading, sys

def handle_client(client_socket, target_host, target_port):
    try:
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((target_host, target_port))
    except Exception as e:
        client_socket.close()
        return

    def forward(source, destination):
        try:
            while True:
                data = source.recv(4096)
                if not data: break
                destination.sendall(data)
        except: pass
        finally:
            source.close()
            destination.close()

    threading.Thread(target=forward, args=(client_socket, target_socket)).start()
    threading.Thread(target=forward, args=(target_socket, client_socket)).start()

def main():
    if len(sys.argv) < 2:
        print("Uso: python3 proxy.py <porta>")
        sys.exit(1)

    listen_port = int(sys.argv[1])
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind(('0.0.0.0', listen_port))
        server.listen(100)
        print(f"[*] WebSocket Proxy rodando na porta {listen_port}")
    except Exception as e:
        print(f"[!] Erro ao abrir porta {listen_port}: {e}")
        sys.exit(1)

    while True:
        client, addr = server.accept()
        # Handshake simples para aceitar a conexão
        try:
            data = client.recv(1024).decode('utf-8', errors='ignore')
            if "Upgrade: websocket" in data or "CONNECT" in data:
                client.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
                handle_client(client, '127.0.0.1', 22)
            else:
                client.close()
        except:
            client.close()

if __name__ == "__main__":
    main()
