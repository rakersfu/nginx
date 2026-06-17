#!/bin/bash

set -e

INSTALL_DIR=/opt/nginx
CONF_DIR=$INSTALL_DIR/conf
LOG_DIR=$INSTALL_DIR/logs
SSL_DIR=$INSTALL_DIR/ssl
HTML_DIR=$INSTALL_DIR/html
RELEASE_URL=https://github.com/xiongli870110-hue/nginx_build_auto/releases/download/nginx-1.25.3-qnap/nginx-build.tar.gz

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RELEASE_TMP=$SCRIPT_DIR/nginx-build.tar.gz
UNPACK_DIR=$SCRIPT_DIR/nginx-build
SYMLINK=/usr/local/bin/nginx

# -------------------------------
# Always uninstall before install
# -------------------------------
echo "[nginx-install] Cleaning up old installation if exists..."
pkill -f nginx 2>/dev/null || true
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
echo "[nginx-install] Main binary located at: $FOUND_DIR"

echo "[nginx-install] Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$FOUND_DIR/.."/* "$INSTALL_DIR/"

# Verify nginx binary exists after installation
if [ ! -f "$INSTALL_DIR/sbin/nginx" ]; then
  echo "[Error] nginx binary missing after installation, failed ❌"
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
NGINX_USER=${NGINX_USER:-admin}

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

echo "[nginx-install] Installation completed ✅"
echo "[nginx-install] Please ensure autorun.sh contains:"
echo "  if [ ! -x /usr/local/bin/nginx ]; then"
echo "    ln -sf /opt/nginx/sbin/nginx /usr/local/bin/nginx"
echo "    echo \"[auto_tasks] nginx symlink created\" >> \$LOGFILE"
echo "  fi"
echo "  echo \"[auto_tasks] Starting nginx...\" >> \$LOGFILE"
echo "  nginx -t -c /opt/nginx/conf/nginx.conf -p /opt/nginx >> \$LOGFILE 2>&1 && \\"
echo "  nginx -c /opt/nginx/conf/nginx.conf -p /opt/nginx >> \$LOGFILE 2>&1"
