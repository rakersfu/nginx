#!/bin/bash
set -e

# ============================
# 1. 安装依赖
# ============================
sudo apt update
sudo apt install -y build-essential wget tar make \
  zlib1g-dev libpcre2-dev perl

# ============================
# 2. 构建 zlib（静态）
# ============================
echo "=== Build zlib ==="
wget https://zlib.net/current/zlib.tar.gz -O zlib.tar.gz
tar -xzf zlib.tar.gz
ZLIB_DIR=$(find . -maxdepth 1 -type d -name "zlib*" | head -n 1)
mv "$ZLIB_DIR" zlib-src

# ============================
# 3. 构建 OpenSSL（静态）
# ============================
echo "=== Build OpenSSL ==="
wget https://www.openssl.org/source/openssl-3.0.12.tar.gz -O openssl.tar.gz
tar -xzf openssl.tar.gz
mv openssl-3.0.12 openssl-src
cd openssl-src
./config no-shared
make -j$(nproc)
cd ..

# ============================
# 4. 构建 PCRE2（静态）
# ============================
echo "=== Build PCRE2 ==="
wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.42/pcre2-10.42.tar.gz -O pcre2.tar.gz
tar -xzf pcre2.tar.gz
mv pcre2-10.42 pcre2-src
cd pcre2-src
./configure --disable-shared --enable-static
make -j$(nproc)
cd ..

# ============================
# 5. 下载 Nginx
# ============================
echo "=== Download Nginx ==="
wget http://nginx.org/download/nginx-1.25.3.tar.gz -O nginx.tar.gz
tar -xzf nginx.tar.gz
cd nginx-1.25.3

# ============================
# 6. 构建 Nginx（静态）
# ============================
echo "=== Build Nginx (static) ==="

./configure --prefix=/opt/nginx \
  --with-http_ssl_module \
  --with-http_v2_module \
  --with-http_gzip_static_module \
  --with-pcre=../pcre2-src \
  --with-openssl=../openssl-src \
  --with-zlib=../zlib-src \
  --with-openssl-opt=no-shared \
  --with-cc-opt="-static -static-libgcc" \
  --with-ld-opt="-static"

make -j$(nproc)

# ============================
# 7. 输出结果
# ============================
echo "=== Build Finished ==="
echo "nginx binary at: $(pwd)/objs/nginx"

cd ..
mkdir -p output
cp nginx-1.25.3/objs/nginx output/nginx
tar -czvf nginx-static-arm.tar.gz output

echo "=== Static ARM Nginx build complete ==="
