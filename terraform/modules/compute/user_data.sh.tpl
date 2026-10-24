#!/bin/bash
# App version: ${app_version}
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

# 1. Packages
dnf install -y python3-pip unzip

# 2. Dedicated unprivileged user and app folder
useradd --system --shell /sbin/nologin appuser || true
mkdir -p /opt/app

# 3. Download and unpack the app (uses the instance IAM role, no keys)
aws s3 cp s3://${app_bucket}/${app_s3_key} /tmp/app.zip --region ${region}
unzip -o /tmp/app.zip -d /opt/app

# 4. Python dependencies
python3 -m pip install -r /opt/app/requirements.txt
chown -R appuser:appuser /opt/app

# 5. Run the app as a systemd service
cat > /etc/systemd/system/app.service <<'UNIT'
[Unit]
Description=DevOps practical web app
After=network-online.target
Wants=network-online.target

[Service]
User=appuser
WorkingDirectory=/opt/app
Environment=AWS_REGION=${region}
Environment=SECRET_NAME=${secret_name}
Environment=APP_BUCKET=${app_bucket}
Environment=APP_PORT=${app_port}
ExecStart=/usr/local/bin/gunicorn --workers 2 --bind 0.0.0.0:${app_port} app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now app.service