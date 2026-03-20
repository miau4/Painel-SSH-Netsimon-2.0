cat << 'EOF' > /etc/painel/checkuser.py
from flask import Flask, jsonify
import subprocess
import datetime

app = Flask(__name__)

def get_expiry(username):
    try:
        # Busca no sistema (SSH)
        chage = subprocess.check_output(f"chage -l {username}", shell=True).decode()
        for line in chage.split('\n'):
            if "Account expires" in line:
                expiry_date = line.split(":")[1].strip()
                if "never" in expiry_date:
                    return "9999-12-31"
                return expiry_date
    except:
        return None

@app.route('/check/<username>', methods=['GET'])
def check_user(username):
    expiry = get_expiry(username)
    if expiry:
        return jsonify({
            "status": "active",
            "user": username,
            "expiry": expiry
        })
    else:
        return jsonify({"status": "not_found"}), 404

if __name__ == '__main__':
    # Roda na porta 5000 para os Apps consultarem
    app.run(host='0.0.0.0', port=5000)
EOF
