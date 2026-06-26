#!/bin/bash

# Update system
sudo dnf update -y

# Install Python3 and pip3
sudo dnf install python3 python3-pip -y

# Install Flask, Gunicorn, and Boto3
sudo pip3 install Flask gunicorn boto3

# Create a directory for the Flask app and change ownership
sudo mkdir -p /var/www
sudo chown $USER:$USER /var/www
cd /var/www

# Flask application code without AWS credentials, using IAM Role
cat << 'EOF' > app.py
from flask import Flask, request, render_template_string
import boto3
import uuid

app = Flask(__name__)

# Replace this with your actual S3 bucket name
S3_BUCKET = ''

# Initialize the S3 client to use IAM role credentials
s3 = boto3.client('s3')

@app.route('/')
def upload_form():
    return render_template_string('''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Upload File to S3</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                background-color: #004f5d;
                color: #ef7f1a;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
            }
            .container {
                text-align: center;
                background-color: #fff;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            }
            .branding {
                font-size: 24px;
                color: #004f5d;
                margin-bottom: 20px;
            }
            form {
                background-color: #ef7f1a;
                padding: 15px;
                border-radius: 8px;
            }
            input[type=file] {
                margin-bottom: 10px;
            }
            input[type=submit] {
                background-color: #004f5d;
                color: #ffffff;
                border: none;
                padding: 10px 20px;
                border-radius: 5px;
                cursor: pointer;
            }
            input[type=submit]:hover {
                background-color: #003440;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="branding">Powered by CloudFreeks</div>
            <form action="/upload" method="post" enctype="multipart/form-data">
                <input type="file" name="file" />
                <input type="submit" value="Upload" />
            </form>
        </div>
    </body>
    </html>
    ''')

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return "No file part"
    file = request.files['file']
    if file.filename == '':
        return "No selected file"
    if file:
        filename = str(uuid.uuid4()) + "-" + file.filename
        s3.upload_fileobj(file, S3_BUCKET, filename)
        return f"Upload Successful. File: {filename}"

if __name__ == '__main__':
    app.run(debug=True)
EOF

# Write the systemd service unit file
cat << EOF | sudo tee /etc/systemd/system/flask-app.service
[Unit]
Description=Flask Application
After=network.target

[Service]
User=$(whoami)
WorkingDirectory=/var/www
ExecStart=/usr/bin/python3 -m gunicorn -b 0.0.0.0:80 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the Flask app service
sudo systemctl daemon-reload
sudo systemctl enable flask-app
sudo systemctl start flask-app
