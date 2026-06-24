# Nginx 安装和配置指南

本目录包含用于安装和配置 Nginx 的自动化脚本。

## 📋 文件说明

- **install_nginx_from_github_systemd.sh** - 完整的 Nginx 安装脚本，包含 systemd 自启配置

## 🚀 快速开始

### 前置要求

- Linux 系统（Ubuntu、CentOS、Debian 等）
- Root 权限或 sudo 权限
- wget 工具（用于下载预编译的 Nginx 包）

### 安装步骤

1. **下载脚本**
   ```bash
   wget https://raw.githubusercontent.com/xiongli870110-hue/ttyd/main/nginx/install_nginx_from_github_systemd.sh
   chmod +x install_nginx_from_github_systemd.sh
   ```

2. **运行安装**
   ```bash
   sudo ./install_nginx_from_github_systemd.sh
   ```

   或直接以 root 身份运行：
   ```bash
   sudo su -
   ./install_nginx_from_github_systemd.sh
   ```

3. **验证安装**
   ```bash
   systemctl status nginx
   curl http://localhost
   ```

## 📁 安装目录结构

安装完成后，Nginx 会被安装到以下位置：

```
/opt/nginx/
├── sbin/
│   └── nginx              # Nginx 可执行文件
├── conf/
│   ├── nginx.conf         # 主配置文件
│   └── mime.types         # MIME 类型定义
├── logs/
│   ├── access.log         # 访问日志
│   └── error.log          # 错误日志
├── html/
│   └── index.html         # 默认首页
└── ssl/                   # SSL 证书目录（预留）
```

**快捷方式：**
```
/usr/local/bin/nginx → /opt/nginx/sbin/nginx
```

## ⚙️ 常用命令

### 服务管理

```bash
# 启动 Nginx
sudo systemctl start nginx

# 停止 Nginx
sudo systemctl stop nginx

# 重启 Nginx
sudo systemctl restart nginx

# 重新加载配置（不中断服务）
sudo systemctl reload nginx

# 查看服务状态
sudo systemctl status nginx

# 启用开机自启
sudo systemctl enable nginx

# 禁用开机自启
sudo systemctl disable nginx
```

### 快速操作

```bash
# 测试配置文件语法
/usr/local/bin/nginx -t

# 查看 Nginx 版本
/usr/local/bin/nginx -v

# 查看编译参数
/usr/local/bin/nginx -V

# 检查 Nginx 进程
ps aux | grep nginx

# 检查端口占用
netstat -tlnp | grep 80
# 或
ss -tlnp | grep 80
```

## 🔧 配置文件修改

编辑 Nginx 配置文件：

```bash
sudo nano /opt/nginx/conf/nginx.conf
# 或
sudo vim /opt/nginx/conf/nginx.conf
```

修改后验证配置并重新加载：

```bash
# 验证配置语法
/usr/local/bin/nginx -t -c /opt/nginx/conf/nginx.conf -p /opt/nginx

# 重新加载配置
sudo systemctl reload nginx
```

## 📊 查看日志

```bash
# 查看访问日志
tail -f /opt/nginx/logs/access.log

# 查看错误日志
tail -f /opt/nginx/logs/error.log

# 查看最后 100 行
tail -n 100 /opt/nginx/logs/access.log
```

## 🗑️ 卸载

完全卸载 Nginx：

```bash
# 停止服务
sudo systemctl stop nginx

# 禁用自启
sudo systemctl disable nginx

# 删除服务文件
sudo rm /etc/systemd/system/nginx.service

# 重新加载 systemd
sudo systemctl daemon-reload

# 删除安装目录
sudo rm -rf /opt/nginx

# 删除软链接
sudo rm /usr/local/bin/nginx
```

## 🐛 故障排查

### 服务无法启动

1. **检查配置文件语法**
   ```bash
   /usr/local/bin/nginx -t
   ```

2. **查看错误日志**
   ```bash
   tail -f /opt/nginx/logs/error.log
   ```

3. **检查端口是否被占用**
   ```bash
   netstat -tlnp | grep 80
   ```

### 权限问题

如果遇到权限错误，请确保：
- 脚本以 root 身份运行
- `/opt/nginx` 目录权限正确
- `/etc/systemd/system/nginx.service` 文件存在

```bash
# 检查目录权限
ls -ld /opt/nginx
ls -l /etc/systemd/system/nginx.service
```

### 常见错误

| 错误 | 原因 | 解决方案 |
|------|------|--------|
| `permission denied` | 权限不足 | 使用 `sudo` 或以 root 身份运行 |
| `Address already in use` | 端口被占用 | 检查其他进程或修改 Nginx 监听端口 |
| `configuration file syntax error` | 配置文件错误 | 使用 `nginx -t` 验证配置 |

## 📝 脚本功能说明

安装脚本会自动完成以下操作：

1. ✅ 检查 root 权限
2. ✅ 清理旧的安装（如果存在）
3. ✅ 下载预编译的 Nginx 包
4. ✅ 解压并安装到 `/opt/nginx`
5. ✅ 创建必要的目录和日志文件
6. ✅ 生成默认配置文件
7. ✅ 创建 systemd 服务文件
8. ✅ 启用开机自启
9. ✅ 启动服务并验证

## 🔒 安全建议

- 定期更新 Nginx 版本
- 限制配置文件访问权限
- 配置防火墙规则
- 使用 SSL/TLS 加密传输
- 定期备份配置文件

## 📞 获取帮助

如遇到问题，请：

1. 检查脚本输出信息中错误提示
2. 查看 Nginx 错误日志：`/opt/nginx/logs/error.log`
3. 运行配置检查：`/usr/local/bin/nginx -t`
4. 在项目 Issues 中提问

## 📄 许可证

本脚本遵循项目所采用的许可证。

---

**最后更新：** 2026-06-24

**支持的系统：** Ubuntu, Debian, CentOS, Rocky Linux 等 Linux 发行版
