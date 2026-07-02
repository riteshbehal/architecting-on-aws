#!/bin/bash
set -e

# Default region used if user doesn't type region on UI
DEFAULT_REGION="ap-south-1"

apt-get update -y
apt-get install -y apache2 php unzip curl

# Install AWS CLI v2
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# Config
cat > /var/www/html/config.php <<EOF
<?php
define("DEFAULT_REGION", "$DEFAULT_REGION");
?>
EOF

# Producer API endpoint
cat > /var/www/html/send.php <<'EOF'
<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
require_once "config.php";

$queueUrl = $_GET["queueUrl"] ?? "";
$msg      = $_GET["msg"] ?? ("Order-" . time());
$region   = $_GET["region"] ?? DEFAULT_REGION;

if (trim($queueUrl) === "") {
  http_response_code(400);
  echo json_encode(["ok"=>false, "error"=>"queueUrl is required"]);
  exit;
}

$cmd = "aws sqs send-message --region " . escapeshellarg($region) .
       " --queue-url " . escapeshellarg($queueUrl) .
       " --message-body " . escapeshellarg($msg) . " 2>&1";

$out = shell_exec($cmd);

echo json_encode([
  "ok" => true,
  "auth" => "EC2 IAM Role (Instance Profile)",
  "region" => $region,
  "queueUrl" => $queueUrl,
  "sent" => $msg,
  "raw" => $out
]);
EOF

# CloudFreeks Producer UI
cat > /var/www/html/index.html <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>CloudFreeks - SQS Producer (EC2 Only)</title>
  <style>
    body{margin:0;font-family:system-ui;background:linear-gradient(120deg,#0b1020,#121b3a,#0b1020);color:#fff}
    .wrap{max-width:1000px;margin:auto;padding:26px}
    .brand{display:flex;align-items:center;gap:12px}
    .logo{width:46px;height:46px;border-radius:14px;background:linear-gradient(135deg,#ff9900,#ff4d4d);box-shadow:0 18px 40px rgba(255,153,0,.25)}
    h1{margin:0;font-size:20px}
    .sub{opacity:.85;font-size:13px;margin-top:2px}
    .card{margin-top:18px;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.12);
      border-radius:18px;padding:16px;box-shadow:0 18px 40px rgba(0,0,0,.25)}
    label{display:block;margin-top:10px;opacity:.9;font-size:13px}
    input{width:100%;padding:12px;border-radius:12px;border:1px solid rgba(255,255,255,.2);
      background:rgba(0,0,0,.25);color:#fff;outline:none;margin-top:6px}
    button{margin-top:12px;padding:12px 14px;border-radius:12px;border:1px solid rgba(255,255,255,.2);
      background:rgba(255,255,255,.12);color:#fff;cursor:pointer}
    button:hover{background:rgba(255,255,255,.18)}
    pre{margin-top:12px;background:rgba(0,0,0,.25);padding:12px;border-radius:12px;border:1px solid rgba(255,255,255,.12);overflow:auto}
    .hint{opacity:.8;font-size:12px;margin-top:10px}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="brand">
      <div class="logo"></div>
      <div>
        <h1>CloudFreeks — SQS Producer App</h1>
        <div class="sub">EC2 Only • UI sends request to EC2 backend • Backend sends to SQS using IAM Role</div>
      </div>
    </div>

    <div class="card">
      <label>SQS Queue URL</label>
      <input id="queueUrl" placeholder="https://sqs.ap-south-1.amazonaws.com/ACCOUNT-ID/queue-name"/>

      <label>AWS Region (optional)</label>
      <input id="region" placeholder="ap-south-1"/>

      <label>Message</label>
      <input id="msg" placeholder="OrderID-5001"/>

      <button onclick="sendMsg()">Send Message</button>

      <div class="hint">Note: No AWS keys in browser. EC2 IAM Role is used in backend.</div>
      <pre id="out">{}</pre>
    </div>
  </div>

<script>
async function sendMsg(){
  const queueUrl = document.getElementById('queueUrl').value.trim();
  const region = document.getElementById('region').value.trim();
  const msg = document.getElementById('msg').value.trim() || ('Order-' + Date.now());

  const url = '/send.php?queueUrl=' + encodeURIComponent(queueUrl) +
              '&region=' + encodeURIComponent(region) +
              '&msg=' + encodeURIComponent(msg);

  const r = await fetch(url);
  const j = await r.json();
  document.getElementById('out').textContent = JSON.stringify(j, null, 2);
}
</script>
</body>
</html>
EOF

chown -R www-data:www-data /var/www/html
systemctl enable --now apache2