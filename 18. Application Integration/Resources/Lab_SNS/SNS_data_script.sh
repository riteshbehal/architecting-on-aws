#!/bin/bash
set -e

APP_DIR="/opt/cloudfreeks-sns-demo"
PORT="8000"

echo "==> Installing dependencies..."

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y python3 python3-pip python3-venv nginx
elif command -v dnf >/dev/null 2>&1; then
  dnf update -y
  dnf install -y python3 python3-pip nginx
elif command -v yum >/dev/null 2>&1; then
  yum update -y
  yum install -y python3 python3-pip nginx
else
  echo "Unsupported OS package manager"
  exit 1
fi

mkdir -p "$APP_DIR"
cd "$APP_DIR"

echo "==> Creating Python app..."

cat > app.py <<'PY'
from flask import Flask, request, jsonify, Response
import json
import time
import os
import requests  # ✅ FIX: required for SNS subscription confirmation
from datetime import datetime

app = Flask(__name__)

DATA_DIR = "/opt/cloudfreeks-sns-demo/data"
MODE_FILE = os.path.join(DATA_DIR, "mode.json")
MSG_FILE  = os.path.join(DATA_DIR, "messages.json")

os.makedirs(DATA_DIR, exist_ok=True)

def load_mode():
    if not os.path.exists(MODE_FILE):
        save_mode(True)
    with open(MODE_FILE, "r") as f:
        return json.load(f).get("enabled", True)

def save_mode(enabled: bool):
    with open(MODE_FILE, "w") as f:
        json.dump({"enabled": enabled, "updated_at": int(time.time())}, f)

def load_messages():
    if not os.path.exists(MSG_FILE):
        with open(MSG_FILE, "w") as f:
            json.dump([], f)
    with open(MSG_FILE, "r") as f:
        return json.load(f)

def save_messages(messages):
    with open(MSG_FILE, "w") as f:
        json.dump(messages[-80:], f)  # keep last 80

def append_message(entry):
    msgs = load_messages()
    msgs.append(entry)
    save_messages(msgs)

HTML = r"""
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Cloudfreeks SNS Demo</title>
  <style>
    :root{
      --bg:#0b1220; --card:#0f1a30; --muted:#93a4c7; --text:#e7eeff;
      --brand:#4f8cff; --good:#25c97a; --bad:#ff5d5d; --line:#1e2b4d;
    }
    *{box-sizing:border-box}
    body{
      margin:0; font-family: ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Arial;
      background:
        radial-gradient(1200px 600px at 20% 0%, rgba(79,140,255,.22), transparent 60%),
        radial-gradient(900px 500px at 80% 10%, rgba(37,201,122,.16), transparent 55%),
        var(--bg);
      color:var(--text);
    }
    .wrap{max-width:1100px;margin:0 auto;padding:28px 18px 60px}
    .top{
      display:flex; gap:16px; align-items:center; justify-content:space-between; flex-wrap:wrap;
      padding:18px 18px; border:1px solid var(--line); background:rgba(15,26,48,.72);
      border-radius:18px; backdrop-filter: blur(6px);
    }
    .brand{display:flex;gap:14px;align-items:center}
    .logo{
      width:44px;height:44px;border-radius:14px;
      background: linear-gradient(135deg, rgba(79,140,255,1), rgba(37,201,122,1));
      box-shadow: 0 10px 35px rgba(79,140,255,.18);
    }
    .title h1{margin:0;font-size:18px;letter-spacing:.2px}
    .title p{margin:3px 0 0;color:var(--muted);font-size:13px}

    /* BIG STATUS BANNER */
    .banner{
      margin-top:16px;
      padding:16px 16px;
      border-radius:18px;
      border:1px solid var(--line);
      background: rgba(15,26,48,.72);
      backdrop-filter: blur(6px);
      display:flex; align-items:center; justify-content:space-between; gap:14px; flex-wrap:wrap;
    }
    .banner .left{
      display:flex; flex-direction:column; gap:4px;
    }
    .banner .state{
      font-size:14px; font-weight:800; letter-spacing:.2px;
      display:flex; align-items:center; gap:10px;
    }
    .badge{
      padding:6px 10px; border-radius:999px; font-size:12px; font-weight:800;
      border:1px solid var(--line);
      background: rgba(11,18,32,.35);
    }
    .badge.on{border-color: rgba(37,201,122,.55); background: rgba(37,201,122,.15); color:#c7ffe6;}
    .badge.off{border-color: rgba(255,93,93,.55); background: rgba(255,93,93,.12); color:#ffd1d1;}
    .sub{color:var(--muted); font-size:13px}

    /* Toggle Switch */
    .toggleWrap{display:flex; align-items:center; gap:12px}
    .toggleLabel{color:var(--muted); font-size:13px; font-weight:700}
    .switch{
      position:relative; width:64px; height:34px; display:inline-block;
    }
    .switch input{display:none}
    .slider{
      position:absolute; inset:0; cursor:pointer;
      background: rgba(255,93,93,.35);
      border:1px solid rgba(255,93,93,.55);
      transition:.2s; border-radius:999px;
      box-shadow: inset 0 0 0 2px rgba(11,18,32,.15);
    }
    .slider:before{
      content:""; position:absolute; height:26px; width:26px; left:4px; top:3px;
      background: #fff; border-radius:999px; transition:.2s;
      box-shadow: 0 8px 18px rgba(0,0,0,.25);
    }
    input:checked + .slider{
      background: rgba(37,201,122,.28);
      border:1px solid rgba(37,201,122,.55);
    }
    input:checked + .slider:before{ transform: translateX(30px); }

    .grid{display:grid;grid-template-columns: 1.1fr .9fr; gap:16px; margin-top:16px}
    @media (max-width: 900px){ .grid{grid-template-columns:1fr} }
    .card{
      border:1px solid var(--line); background:rgba(15,26,48,.72);
      border-radius:18px; padding:16px; backdrop-filter: blur(6px);
    }
    .card h2{margin:0 0 8px;font-size:15px}
    .hint{color:var(--muted);font-size:13px;line-height:1.5;margin:0}
    code{
      display:block; padding:12px; border-radius:14px; border:1px solid var(--line);
      background: rgba(11,18,32,.45); color: #d9e6ff; font-size:12px; overflow:auto;
      margin-top:10px;
    }
    .list{margin-top:10px; display:flex; flex-direction:column; gap:10px}
    .msg{
      border:1px solid var(--line); background: rgba(11,18,32,.35);
      border-radius:14px; padding:12px;
    }
    .meta{display:flex;gap:10px;flex-wrap:wrap;color:var(--muted);font-size:12px;margin-bottom:6px}
    .msg pre{margin:0;white-space:pre-wrap;word-break:break-word;font-size:13px;color:var(--text)}
    a{color:#bcd3ff;text-decoration:none}
    a:hover{text-decoration:underline}
  </style>
</head>
<body>
<div class="wrap">

  <div class="top">
    <div class="brand">
      <div class="logo"></div>
      <div class="title">
        <h1>Cloudfreeks SNS Demo</h1>
        <p>SNS → HTTP Subscriber with a clear ON/OFF toggle (OFF = 503)</p>
      </div>
    </div>
  </div>

  <div class="banner">
    <div class="left">
      <div class="state">
        <span id="badge" class="badge">Loading...</span>
        <span id="stateText">Checking subscriber mode...</span>
      </div>
      <div class="sub">
        Endpoint for SNS Subscription: <b id="endpoint"></b>
      </div>
    </div>

    <div class="toggleWrap">
      <div class="toggleLabel">Subscriber</div>
      <label class="switch" title="Toggle subscriber ON/OFF">
        <input id="toggle" type="checkbox" onchange="toggleMode()">
        <span class="slider"></span>
      </label>
      <button onclick="refreshAll()" style="border:1px solid var(--line);background:rgba(11,18,32,.35);color:var(--text);padding:10px 12px;border-radius:12px;cursor:pointer;font-weight:700;font-size:13px;">
        Refresh
      </button>
    </div>
  </div>

  <div class="grid">
    <div class="card">
      <h2>How the ON/OFF works</h2>
      <p class="hint">
        <b>ON:</b> <code style="display:inline;padding:2px 6px">/sns</code> returns <b>200</b> → SNS delivery success.<br/>
        <b>OFF:</b> <code style="display:inline;padding:2px 6px">/sns</code> returns <b>503</b> → SNS delivery fails → SNS retries.
      </p>
      <code>
SNS Topic → Subscription (HTTP) → http://EC2-Public-IP/sns
If endpoint returns 2xx: success
If endpoint returns 5xx/timeout: retry
      </code>
    </div>

    <div class="card">
      <h2>Quick Lab Steps</h2>
      <p class="hint">
        1) Create SNS Topic<br/>
        2) Create HTTP subscription using the endpoint shown above<br/>
        3) Publish message → see it here<br/>
        4) Toggle OFF → publish again → see retry behavior
      </p>
      <code>
Tip: Keep this page open while you publish messages from SNS Console.
      </code>
    </div>
  </div>

  <div class="card" style="margin-top:16px">
    <h2>Latest Received Messages</h2>
    <p class="hint">Auto-refresh every 3 seconds.</p>
    <div class="list" id="list"></div>
  </div>

</div>

<script>
  function base(){ return window.location.origin; }

  async function refreshStatus(){
    const res = await fetch("/api/status");
    const data = await res.json();

    const toggle = document.getElementById("toggle");
    const badge = document.getElementById("badge");
    const stateText = document.getElementById("stateText");
    const endpoint = document.getElementById("endpoint");

    endpoint.textContent = base() + "/sns";

    if(data.enabled){
      toggle.checked = true;
      badge.className = "badge on";
      badge.textContent = "ON (200)";
      stateText.textContent = "Subscriber is ON — SNS messages will be accepted.";
    }else{
      toggle.checked = false;
      badge.className = "badge off";
      badge.textContent = "OFF (503)";
      stateText.textContent = "Subscriber is OFF — SNS delivery will fail and SNS will retry.";
    }
  }

  async function toggleMode(){
    const on = document.getElementById("toggle").checked;
    await fetch("/api/mode", {
      method:"POST",
      headers: {"Content-Type":"application/json"},
      body: JSON.stringify({enabled:on})
    });
    await refreshStatus();
  }

  function esc(s){
    return (s||"").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;");
  }

  async function refreshMessages(){
    const res = await fetch("/api/messages");
    const data = await res.json();
    const list = document.getElementById("list");
    list.innerHTML = "";

    if(!data.length){
      list.innerHTML = '<div class="msg"><div class="meta">No messages yet</div><pre>Publish a test message from SNS.</pre></div>';
      return;
    }

    data.slice().reverse().forEach(m => {
      const div = document.createElement("div");
      div.className = "msg";
      div.innerHTML = `
        <div class="meta">
          <span><b>Time:</b> ${esc(m.time)}</span>
          <span><b>Type:</b> ${esc(m.type)}</span>
          <span><b>Topic:</b> ${esc(m.topic || "-")}</span>
        </div>
        <pre>${esc(m.message)}</pre>
      `;
      list.appendChild(div);
    });
  }

  async function refreshAll(){
    await refreshStatus();
    await refreshMessages();
  }

  refreshAll();
  setInterval(refreshMessages, 3000);
  setInterval(refreshStatus, 6000);
</script>
</body>
</html>
"""

@app.get("/")
def home():
    return Response(HTML, mimetype="text/html")

@app.get("/api/status")
def api_status():
    return jsonify({"enabled": load_mode()})

@app.post("/api/mode")
def api_mode():
    body = request.get_json(force=True, silent=True) or {}
    enabled = bool(body.get("enabled", True))
    save_mode(enabled)
    return jsonify({"ok": True, "enabled": enabled})

@app.get("/api/messages")
def api_messages():
    return jsonify(load_messages())

@app.post("/sns")
def sns():
    enabled = load_mode()

    # OFF mode: simulate endpoint failure (503) so SNS retries
    if not enabled:
        return "Subscriber OFF (503). SNS delivery fails and SNS will retry.", 503

    try:
        payload = request.get_json(force=True, silent=False)
    except Exception:
        return "Invalid JSON", 400

    msg_type = payload.get("Type", "Unknown")

    # Subscription confirmation
    if msg_type == "SubscriptionConfirmation":
        sub_url = payload.get("SubscribeURL")
        if sub_url:
            try:
                requests.get(sub_url, timeout=10)
            except Exception as e:
                append_message({
                    "time": datetime.utcnow().isoformat() + "Z",
                    "type": "SubscriptionConfirmation-ERROR",
                    "topic": payload.get("TopicArn"),
                    "message": f"Failed to confirm: {str(e)}"
                })
                return "Failed to confirm subscription", 500

        append_message({
            "time": datetime.utcnow().isoformat() + "Z",
            "type": "SubscriptionConfirmation",
            "topic": payload.get("TopicArn"),
            "message": "Subscription confirmed ✅"
        })
        return "Confirmed", 200

    # Notification
    if msg_type == "Notification":
        append_message({
            "time": datetime.utcnow().isoformat() + "Z",
            "type": "Notification",
            "topic": payload.get("TopicArn"),
            "message": payload.get("Message", "")
        })
        return "Received", 200

    append_message({
        "time": datetime.utcnow().isoformat() + "Z",
        "type": msg_type,
        "topic": payload.get("TopicArn"),
        "message": json.dumps(payload)[:2000]
    })
    return "OK", 200
PY

echo "==> Creating venv and installing Python packages..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install flask requests gunicorn

echo "==> Configuring systemd service..."
cat > /etc/systemd/system/cloudfreeks-sns-demo.service <<EOF
[Unit]
Description=Cloudfreeks SNS Demo (SNS -> HTTP subscriber)
After=network.target

[Service]
User=root
WorkingDirectory=${APP_DIR}
Environment="PATH=${APP_DIR}/venv/bin"
ExecStart=${APP_DIR}/venv/bin/gunicorn -w 2 -b 127.0.0.1:${PORT} app:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudfreeks-sns-demo
systemctl restart cloudfreeks-sns-demo

echo "==> Configuring Nginx reverse proxy..."
cat > /etc/nginx/conf.d/cloudfreeks-sns-demo.conf <<EOF
server {
  listen 80;
  server_name _;

  location / {
    proxy_pass http://127.0.0.1:${PORT};
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
EOF

rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

nginx -t
systemctl enable nginx
systemctl restart nginx

echo "==> DONE ✅ Open: http://<EC2-PUBLIC-IP>/"
echo "==> SNS endpoint: http://<EC2-PUBLIC-IP>/sns"