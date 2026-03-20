import socket
import threading
import sys

LISTENING_ADDR = '0.0.0.0'
TARGET_ADDR = '127.0.0.1'
TARGET_PORT = 22

def handler(client_socket, target_addr, target_port):
    try:
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((target_addr, target_port))
    except:
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
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 80
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind((LISTENING_ADDR, port))
        server.listen(100)
        print(f"WS Online na porta {port}")
    except Exception as e:
        sys.exit(1)

    while True:
        client_sock, addr = server.accept()
        threading.Thread(target=handler, args=(client_sock, TARGET_ADDR, TARGET_PORT)).start()

if __name__ == '__main__':
    main()
