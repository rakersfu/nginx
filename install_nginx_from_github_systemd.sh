#!/bin/bash

set -e

# check run as root
if [ "$EUID" -ne 0 ]; then 
   echo "[Error] This script must be run as root ❌"
   exit 1
fi

INSTALL_DIR=/opt/nginx
CONF_DIR=$INSTALL_DIR/conf
LOG_DIR=$INSTALL_DIR/logs
SSL_DIR=$INSTALL_DIR/ssl
HTML_DIR=$INSTALL_DIR/html
RELEASE_URL=https://github.com/rakersfu/nginx/releases/download/nginx-1.25.3/nginx-build.tar.gz

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RELEASE_TMP=$SCRIPT_DIR/nginx-build.tar.gz
UNPACK_DIR=$SCRIPT_DIR/nginx-build
SERVICE_FILE=/etc/systemd/system/nginx.service
SYMLINK=/usr/local/bin/nginx

# -------------------------------
# Always uninstall before install
# -------------------------------
echo "[nginx-install] Cleaning up old installation if exists..."
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true
rm -f "$SERVICE_FILE"
systemctl daemon-reload
rm -rf "$INSTALL_DIR"
rm -f "$SYMLINK"

# -------------------------------
# Start installation
# -------------------------------
echo "[nginx-install] Start installing Nginx (using precompiled package)..."

# Download precompiled package if missing
if [ -f "$RELEASE_TMP" ]; then
  echo "[nginx-install] Local nginx-build.tar.gz exists, skip download ✅"
else
  echo "[nginx-install] Downloading precompiled package..."
  wget -O "$RELEASE_TMP" "$RELEASE_URL"
fi

echo "[nginx-install] Extracting precompiled package..."
rm -rf "$UNPACK_DIR"
mkdir -p "$UNPACK_DIR"
tar -zxvf "$RELEASE_TMP" -C "$UNPACK_DIR"

# Automatically locate nginx main binary
FOUND_NGINX=$(find "$UNPACK_DIR" -type f -name nginx -executable | head -n 1)

if [ -z "$FOUND_NGINX" ]; then
  echo "[Error] nginx binary not found, installation failed ❌"
  exit 1
fi

FOUND_DIR=$(dirname "$FOUND_NGINX")
echo "[nginx-install] Main binary located at: $FOUND_NGINX"

echo "[nginx-install] Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Copy the directory that contains the nginx binary into the install dir.
# This handles archives that put the binary at top-level of some folder (e.g. output/nginx/nginx)
# or those that already have a sbin/ layout.
cp -r "$FOUND_DIR"/* "$INSTALL_DIR"/ || true

# If the binary ended up at $INSTALL_DIR/nginx (top-level), move it to sbin so later checks work
if [ -f "$INSTALL_DIR/nginx" ] && [ ! -f "$INSTALL_DIR/sbin/nginx" ]; then
  mkdir -p "$INSTALL_DIR/sbin"
  mv "$INSTALL_DIR/nginx" "$INSTALL_DIR/sbin/nginx"
  chmod 0755 "$INSTALL_DIR/sbin/nginx"
fi

# If binary is in a different path inside the install dir (e.g. bin/nginx), try to normalize to sbin/
if [ ! -f "$INSTALL_DIR/sbin/nginx" ]; then
  # search for nginx within the newly populated $INSTALL_DIR
  INSTALLED_NGINX=$(find "$INSTALL_DIR" -type f -name nginx -executable | head -n 1 || true)
  if [ -n "$INSTALLED_NGINX" ]; then
    mkdir -p "$INSTALL_DIR/sbin"
    cp -f "$INSTALLED_NGINX" "$INSTALL_DIR/sbin/nginx"
    chmod 0755 "$INSTALL_DIR/sbin/nginx"
  fi
fi

# Verify nginx binary exists after installation
if [ ! -f "$INSTALL_DIR/sbin/nginx" ]; then
  echo "[Error] nginx binary missing after installation, failed ❌"
  echo "[nginx-install] Debug: contents of $INSTALL_DIR:" 
  ls -al "$INSTALL_DIR" || true
  exit 1
fi

echo "[nginx-install] Creating symlink..."
ln -sf "$INSTALL_DIR/sbin/nginx" "$SYMLINK"

echo "[nginx-install] Creating required directories..."
mkdir -p "$CONF_DIR" "$LOG_DIR" "$SSL_DIR" "$HTML_DIR"

echo "[nginx-install] Creating log files..."
touch "$LOG_DIR/access.log"
touch "$LOG_DIR/error.log"

# Automatically select existing system user (priority: guest > admin > ubuntu)
for U in guest admin ubuntu; do
  if id "$U" >/dev/null 2>&1; then
    NGINX_USER="$U"
    break
  fi
done
NGINX_USER=${NGINX_USER:-www-data}

echo "[nginx-install] Creating default nginx.conf..."
cat > "$CONF_DIR/nginx.conf" <<EOF
user $NGINX_USER;

worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    access_log  logs/access.log;
    error_log   logs/error.log;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;

        location / {
            root   html;
            index  index.html index.htm;
        }
    }
}
EOF

echo "[nginx-install] Creating mime.types (minimal version)..."
cat > "$CONF_DIR/mime.types" <<EOF
types {
    text/html html htm;
    text/css css;
    application/javascript js;
    image/png png;
    image/jpeg jpg jpeg;
}
EOF

echo "[nginx-install] Creating default homepage..."
echo "<h1>Welcome to nginx @ $(hostname)</h1>" > "$HTML_DIR/index.html"

echo "[nginx-install] Validating configuration..."
"$SYMLINK" -t -c "$CONF_DIR/nginx.conf" -p "$INSTALL_DIR"

# -------------------------------
# Add systemd auto-start logic
# -------------------------------
echo "[nginx-install] Creating systemd service for auto-start..."
cat > "$SERVICE_FILE" <<'EOFSERVICE'
[Unit]
Description=Nginx Web Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/nginx -c /opt/nginx/conf/nginx.conf -p /opt/nginx -g "daemon off;"
ExecReload=/usr/local/bin/nginx -s reload -p /opt/nginx
ExecStop=/usr/local/bin/nginx -s quit -p /opt/nginx
Restart=always

[Install]
WantedBy=multi-user.target
EOFSERVICE

echo "[nginx-install] Reloading systemd daemon..."
systemctl daemon-reload

echo "[nginx-install] Enabling nginx service to start on boot..."
systemctl enable nginx

echo "[nginx-install] Starting nginx service via systemd..."
systemctl start nginx

echo "[nginx-install] Verifying nginx is running..."
if systemctl is-active --quiet nginx; then
  echo "[nginx-install] ✅ Nginx is running successfully"
else
  echo "[nginx-install] ⚠️ Warning: Nginx service may not have started correctly"
  systemctl status nginx || true
fi

echo "[nginx-install] Installation and auto-start setup completed ✅"
