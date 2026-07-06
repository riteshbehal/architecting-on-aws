#!/bin/bash

set -e

# Detect package manager
if command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
else
    PKG_MANAGER="yum"
fi

# Update system
$PKG_MANAGER update -y

# Install Python and pip
$PKG_MANAGER install -y python3 python3-pip

# Install Python packages
pip3 install --upgrade pip || true
pip3 install flask psutil flask-cors --break-system-packages || pip3 install flask psutil flask-cors

# Set application directory
APP_DIR="/opt/cloudfreeks-cpu-app"
mkdir -p $APP_DIR/templates

# Create Flask app
cat << 'EOF' > $APP_DIR/app.py
from flask import Flask, render_template, jsonify
from flask_cors import CORS
import psutil
import multiprocessing
import time
import os
import signal

app = Flask(__name__)
CORS(app)

load_processes = []

def cpu_load():
    while True:
        pass

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/cpu_percentage')
def cpu_percentage():
    return jsonify(cpu=psutil.cpu_percent(interval=1))

@app.route('/increase_load')
def increase_load():
    global load_processes

    if not load_processes:
        cpu_count = multiprocessing.cpu_count()

        # Start load on all available vCPUs
        for _ in range(cpu_count):
            process = multiprocessing.Process(target=cpu_load)
            process.start()
            load_processes.append(process)

    return jsonify(status='CPU Load Increased')

@app.route('/cancel_load')
def cancel_load():
    global load_processes

    for process in load_processes:
        if process.is_alive():
            os.kill(process.pid, signal.SIGTERM)

    load_processes = []

    return jsonify(status='CPU Load Cancelled')

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80)
EOF

# Create HTML template
cat << 'EOF' > $APP_DIR/templates/index.html
<!DOCTYPE html>
<html>
<head>
    <title>CloudFreeks - CPU Control</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin-top: 40px;
        }

        .branding {
            color: #0077B5;
            font-weight: bold;
            font-size: 26px;
            margin-top: 20px;
        }

        .meter {
            height: 20px;
            background: #555;
            border-radius: 25px;
            padding: 10px;
            width: 70%;
            margin: 30px auto;
            box-shadow: inset 0 -1px 1px rgba(255, 255, 255, 0.3);
        }

        .meter > span {
            display: block;
            height: 100%;
            border-radius: 20px;
            background-color: #33cc33;
            width: 0%;
        }

        button {
            padding: 12px 20px;
            margin: 10px;
            font-size: 16px;
            cursor: pointer;
        }

        a {
            display: block;
            margin-top: 10px;
            margin-bottom: 20px;
        }
    </style>

    <script>
        function updateCpuUsage() {
            fetch('/cpu_percentage')
                .then(response => response.json())
                .then(data => {
                    const percentage = data.cpu;
                    document.getElementById('cpu-percentage-meter').style.width = percentage + '%';
                    document.getElementById('cpu-text').innerText = percentage + '%';
                })
                .catch(error => {
                    document.getElementById('cpu-text').innerText = 'Unable to fetch CPU data';
                });
        }

        function increaseLoad() {
            fetch('/increase_load')
                .then(() => updateCpuUsage());
        }

        function cancelLoad() {
            fetch('/cancel_load')
                .then(() => updateCpuUsage());
        }

        setInterval(updateCpuUsage, 2000);
    </script>
</head>

<body onload="updateCpuUsage()">

    <h2 class="branding">CloudFreeks</h2>

    <h3>EC2 CPU Utilization Demo</h3>

    <div class="meter">
        <span id="cpu-percentage-meter"></span>
    </div>

    <p id="cpu-text" style="margin-top: 20px;">Loading...</p>

    <button onclick="increaseLoad()">Increase CPU Load</button>
    <button onclick="cancelLoad()">Cancel Load</button>

    <p style="margin-top: 30px;">
        Powered by <span class="branding">CloudFreeks</span>
    </p>

</body>
</html>
EOF

# Create systemd service
cat << EOF > /etc/systemd/system/cloudfreeks-cpu-app.service
[Unit]
Description=CloudFreeks CPU Monitoring Demo App
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl daemon-reload
systemctl enable cloudfreeks-cpu-app
systemctl start cloudfreeks-cpu-app