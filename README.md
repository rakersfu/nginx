# Nginx 构建工作流对比

本仓库包含两个 Nginx 构建工作流，针对不同的系统环境进行优化。本文档详细说明两个工作流的差异、共同特点以及使用场景。

---

## 📋 工作流概览

| 特性 | nginx_22.04_inside_20.04 | nginx_22.04_static_openssl |
|------|-------------------------|--------------------------|
| **目标系统** | QNAP、Ubuntu 20.04、Debian 10/11（老旧系统） | Ubuntu 22.04 及以上（现代系统） |
| **构建环境** | Docker 容器（Ubuntu 20.04） | 本地主机（Ubuntu 22.04） |
| **OpenSSL** | 系统自带版本 | 静态编译 OpenSSL 3.0.12 |
| **Runner** | ubuntu-22.04 | ubuntu-22.04 |
| **Release 标签** | nginx-1.25.3 | nginx-1.25.3 |

---

## 🔄 共同特点

### 基础配置
- **Nginx 版本**：1.25.3
- **触发方式**：`workflow_dispatch`（手���触发）+ `push` 到 main 分支
- **编译选项**：
  - `--with-http_ssl_module` - SSL/TLS 支持
  - `--with-http_v2_module` - HTTP/2 支持
  - `--with-http_gzip_static_module` - Gzip 压缩支持
  - `--with-pcre` - Perl 正则表达式引擎支持
- **并行编译**：使用 `make -j$(nproc)` 充分利用多核处理器
- **输出打包**：将编译产物打包为 `nginx-build.tar.gz`
- **发布方式**：GitHub Release（使用 `softprops/action-gh-release@v1`）
- **认证令牌**：均使用 `GITHUB_TOKEN` 环境变量

---

## 🎯 关键差异

### 1. **nginx_22.04_inside_20.04** (老旧系统优化版)
   
**核心策略**：容器化隔离，确保 glibc 兼容性

```
Ubuntu 22.04 主机
    ↓
Docker 容器 (Ubuntu 20.04)
    ↓
安装依赖 & 编译 Nginx
    ↓
输出二进制文件
```

**优势**：
- ✅ 确保编译环境 glibc 版本与目标系统兼容
- ✅ 避免宿主机库版本过新导致的兼容性问题
- ✅ 对 QNAP NAS、Ubuntu 20.04、Debian 10/11 等老旧系统友好
- ✅ 隔离构建环境，不污染宿主机

**劣势**：
- ⚠️ Docker 镜像拉取时间
- ⚠️ 容器启动和销毁的额外开销

**适用场景**：
- QNAP、群晖等老旧 NAS 系统
- Ubuntu 18.04/20.04、Debian 10/11 等
- 对兼容性有严格要求的生产环境

---

### 2. **nginx_22.04_static_openssl** (现代系统优化版)

**核心策略**：静态编译 OpenSSL，最大化安全性和独立性

```
Ubuntu 22.04 主机
    ↓
编译 OpenSSL 3.0.12 (静态库)
    ↓
编译 Nginx (链接静态 OpenSSL)
    ↓
输出二进制文件
```

**优势**：
- ✅ 使用最新的 OpenSSL 3.0.12（更新的安全补丁）
- ✅ 静态链接 OpenSSL，无需依赖系统 libssl
- ✅ 更好的安全性和更新的加密算法支持
- ✅ 编译速度更快（无容器开销）
- ✅ 适合现代云环境和容器化部署

**劣势**：
- ⚠️ 编译产物体积更大（静态链接）
- ⚠️ 对老旧系统的 glibc 兼容性可能有问题

**适用场景**：
- Ubuntu 22.04 及更新版本
- 现代 Linux 发行版（CentOS 8+、AlmaLinux、Rocky Linux）
- Kubernetes、Docker 等容器环境
- 对安全性要求高的应用

---

## 📊 编译依赖对比

### nginx_22.04_inside_20.04
```bash
安装依赖：build-essential
         libpcre3 libpcre3-dev
         zlib1g zlib1g-dev
         libssl-dev
         wget
```

### nginx_22.04_static_openssl
```bash
安装依赖：build-essential
         libpcre3 libpcre3-dev
         zlib1g zlib1g-dev
         wget
         
# OpenSSL 单独编译（不依赖系统 libssl-dev）
openssl-3.0.12 (从源码编译)
```

---

## 🚀 使用指南

### 选择构建版本

**选择 `nginx_22.04_inside_20.04` 如果：**
- 需要在 QNAP、群晖 等 NAS 设备上运行
- 部署环境是 Ubuntu 20.04 或 Debian 10/11
- 对系统兼容性的要求优先于安全性更新
- 系统的 glibc 版本较低（< 2.31）

**选择 `nginx_22.04_static_openssl` 如果：**
- 部署在 Ubuntu 22.04 LTS 或更新版本
- 使用现代 Linux 发行版（Rocky、AlmaLinux 等）
- 在容器/Kubernetes 环境中运行
- 对加密算法和 TLS 协议版本有更新的需求
- 希望减少系统依赖的复杂性

---

## 📦 Release 产物

两个工作流均生成以下发布物：

```
Release: nginx-1.25.3
├── Tag: nginx-1.25.3
├── Release Notes: 说明构建策略和功能特性
└── Artifact: nginx-build.tar.gz
    └── output/nginx/  (二进制和配置文件)
```

### 解压和使用

```bash
# 下载 Release
tar -xzvf nginx-build.tar.gz

# 二进制位置
./output/nginx/objs/nginx

# 可选：安装到系统
sudo mkdir -p /opt/nginx
sudo cp -r output/nginx/* /opt/nginx/
```

---

## 🔐 安全考量

| 方面 | nginx_22.04_inside_20.04 | nginx_22.04_static_openssl |
|------|-------------------------|--------------------------|
| **OpenSSL 版本** | 系统版本（Ubuntu 20.04 = 1.1.1） | 3.0.12（最新稳定版） |
| **TLS 1.3 支持** | ✅ (OpenSSL 1.1.1) | ✅ (OpenSSL 3.0) |
| **现代加密算法** | 受限于 OpenSSL 1.1.1 | ✅ 完整支持 |
| **安全补丁频率** | 取决于容器镜像更新 | 可手动更新 OpenSSL 版本 |

---

## 🔧 故障排除

### 兼容性问题
- **运行时错误 `libc.so.6: version 'GLIBC_xxx' not found`**
  → 使用 `nginx_22.04_inside_20.04`（确保 glibc 兼容性）

- **SSL 相关错误**
  → 检查目标系统 OpenSSL 版本：`openssl version`
  → 使用 `nginx_22.04_static_openssl` 可避免依赖系统 OpenSSL

### 编译问题
- **Docker 不可用**
  → 检查 Runner 上的 Docker 守护进程
  → 验证构建脚本中的 Docker 命令语法

- **网络超时**
  → Nginx 源码和 OpenSSL 源码下载可能超时
  → 考虑使用镜像源或本地缓存

---

## 📝 维护建议

1. **定期更新 Nginx 版本**
   - 编辑工作流中的版本号
   - 保持安全补丁和新功能同步

2. **OpenSSL 更新策略**
   - `nginx_22.04_inside_20.04`：自动跟随 Ubuntu 20.04 官方更新
   - `nginx_22.04_static_openssl`：手动更新版本号以获取新补丁

3. **兼容性测试**
   - 在目标系统上测试二进制文件
   - 验证 SSL/TLS 握手和性能

---

## 🤝 许可证

本项目中的构建脚本和工作流配置开源使用。Nginx 本身遵循 BSD-2-Clause 许可证。

---

**最后更新**：2026-06-17
