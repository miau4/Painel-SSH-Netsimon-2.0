import socket
import threading
import sys

# Configurações Padrão
LISTENING_ADDR = '0.0.0.0'
TARGET_ADDR = '127.0.0.1'
TARGET_PORT = 22 # Porta do SSH Local

# Cores para o Log (Apenas se rodar manualmente)
G = '\033[1;32m'
R = '\033[1;31m'
NC = '\033[0m'

def handler(client_socket, target_addr, target_port):
    try:
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.connect((target_addr, target_port))
    except Exception as e:
        client_socket.close()
        return

    def forward(source, destination):
        try:
            while True:
                data = source.recv(4096)
                if not data:
                    break
                destination.sendall(data)
        except:
            pass
        finally:
            source.close()
            destination.close()

    threading.Thread(target=forward, args=(client_socket, target_socket)).start()
    threading.Thread(target=forward, args=(target_socket, client_socket)).start()

def main():
    # Verifica se uma porta foi passada como argumento
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"{R}Erro: Porta inválida.{NC}")
            sys.exit(1)
    else:
        port = 80 # Porta padrão caso não informe nada

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind((LISTENING_ADDR, port))
        server.listen(100)
        print(f"{G}[+] WebSocket Rodando na Porta: {port}{NC}")
    except Exception as e:
        print(f"{R}Erro ao iniciar na porta {port}: {e}{NC}")
        sys.exit(1)

    while True:
        client_sock, addr = server.accept()
        threading.Thread(target=handler, args=(client_sock, TARGET_ADDR, TARGET_PORT)).start()

if __name__ == '__main__':
    main()
