cat << 'EOF' > /etc/painel/proxy.py
import socket, threading, thread, sys

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = 80
PASS = "NetSimon"

def main():
    print "NetSimon Proxy Started on Port 80"
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((LISTENING_ADDR, LISTENING_PORT))
    server.listen(100)
    while True:
        client, addr = server.accept()
        threading.Thread(target=proxy_thread, args=(client, addr)).start()

def proxy_thread(client, addr):
    try:
        data = client.recv(1024)
        if "HTTP/1.1" in data:
            target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            target.connect(('127.0.0.1', 22))
            client.send("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
            
            # Bridge
            def forward(src, dst):
                try:
                    while True:
                        d = src.recv(4096)
                        if not d: break
                        dst.send(d)
                except: pass
            
            threading.Thread(target=forward, args=(client, target)).start()
            forward(target, client)
    except: pass
    finally: client.close()

if __name__ == '__main__':
    main()
EOF
