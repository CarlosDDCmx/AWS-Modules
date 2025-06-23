from flask import Flask, jsonify
import subprocess

app = Flask(__name__)

@app.route('/hello')
def hello():
    return jsonify(message="Hello, World!")

@app.route('/status')
def status():
    uptime = subprocess.check_output('uptime -p', shell=True).decode('utf-8').strip()
    return jsonify(status="OK", uptime=uptime)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)