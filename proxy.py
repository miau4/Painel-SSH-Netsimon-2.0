#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ==========================================
#   NETSIMON PROXY - WebSocket/SOCKS 2.1
# ==========================================
import socket, threading, sys

SSH_HOST = '127.0.0.1'
SSH_PORT = 22
BUFFER_SIZE = 8192
STATUS_MSG = "netsimon"  # Mensagem customizada no status 101

def handle_client(client_socket):
    target_socket = None
    try:
        request = client_socket.recv(BUFFER_SIZE)
        if not request:
            client_socket.close()
            return

        header = request.decode('utf-8', errors='ignore')
        # FIX: comparação case-insensitive (app envia "Websocket" com W maiúsculo,
        # e o Cloudflare normaliza headers para lowercase na origem)
        header_lower = header.lower()
        is_websocket = (
            "upgrade: websocket" in header_lower or
            "connection: upgrade" in header_lower
        )

        if is_websocket:
            # FIX: status customizado (igual servidor 1 que funciona)
            response = (
                f"HTTP/1.1 101 {STATUS_MSG}\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n\r\n"
            )
            client_socket.sendall(response.encode())

        # Conecta ao SSH local
        target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_socket.settimeout(10)
        target_socket.connect((SSH_HOST, SSH_PORT))
        target_socket.settimeout(None)

        # Só encaminha o request bruto se NÃO for WebSocket
        if not is_websocket:
            target_socket.sendall(request)

        # Inicia a ponte bidirecional
        t1 = threading.Thread(
            target=forward, args=(client_socket, target_socket), daemon=True
        )
        t2 = threading.Thread(
            target=forward, args=(target_socket, client_socket), daemon=True
        )
        t1.start()
        t2.start()

    except ConnectionRefusedError:
        # SSH não está acessível na porta configurada
        pass
    except Exception:
        pass
    finally:
        # Só fecha se os threads não foram iniciados (erro antes do start)
        # Os threads fecham os sockets quando terminam
        pass


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
        try:
            source.close()
        except Exception:
            pass
        try:
            destination.close()
        except Exception:
            pass


def main(port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', port))
    except Exception as e:
        print(f"[ERRO] Bind na porta {port} falhou: {e}")
        sys.exit(1)

    server.listen(200)
    print(f"[OK] Proxy escutando na porta {port}")

    while True:
        try:
            client, addr = server.accept()
            threading.Thread(
                target=handle_client, args=(client,), daemon=True
            ).start()
        except Exception:
            pass


if __name__ == "__main__":
    listen_port = int(sys.argv[1]) if len(sys.argv) > 1 else 80
    main(listen_port)
