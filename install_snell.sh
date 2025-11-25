#!/bin/bash

# Snell Server 一键安装脚本
# 版本: v5.0.1

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    log_error "请使用 root 用户运行此脚本"
    exit 1
fi

log_info "开始安装 Snell Server v5.0.1..."

# 1. 更新系统并安装依赖
log_info "更新系统并安装依赖..."
apt update && apt install -y wget unzip

# 2. 下载 Snell Server
log_info "下载 Snell Server..."
cd /tmp
wget -O snell-server.zip https://dl.nssurge.com/snell/snell-server-v5.0.1-linux-amd64.zip

# 3. 解压到目标目录
log_info "解压文件..."
unzip -o snell-server.zip -d /usr/local/bin
chmod +x /usr/local/bin/snell-server

# 4. 创建配置目录
log_info "创建配置目录..."
mkdir -p /etc/snell

# 5. 生成随机 PSK（如果需要自定义，可以修改这里）
PSK=${SNELL_PSK:-$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)}
PORT=${SNELL_PORT:-717}

# 6. 创建配置文件
log_info "创建配置文件..."
cat > /etc/snell/snell-server.conf << EOL
[snell-server]
listen = 0.0.0.0:${PORT}
psk = ${PSK}
ipv6 = false
EOL

# 7. 创建 systemd 服务文件
log_info "创建 systemd 服务..."
cat > /lib/systemd/system/snell.service << 'EOL'
[Unit]
Description=Snell Proxy Service
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
LimitNOFILE=32768
ExecStart=/usr/local/bin/snell-server -c /etc/snell/snell-server.conf
AmbientCapabilities=CAP_NET_BIND_SERVICE
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=snell-server

[Install]
WantedBy=multi-user.target
EOL

# 8. 重载 systemd 并启动服务
log_info "启动 Snell 服务..."
systemctl daemon-reload
systemctl enable snell
systemctl start snell

# 9. 检查服务状态
sleep 2
if systemctl is-active --quiet snell; then
    log_info "Snell Server 安装成功！"
    echo ""
    echo "========================================"
    echo -e "${GREEN}安装信息${NC}"
    echo "========================================"
    echo "监听端口: ${PORT}"
    echo "PSK: ${PSK}"
    echo "配置文件: /etc/snell/snell-server.conf"
    echo "========================================"
    echo ""
    echo "管理命令："
    echo "  启动: systemctl start snell"
    echo "  停止: systemctl stop snell"
    echo "  重启: systemctl restart snell"
    echo "  状态: systemctl status snell"
    echo "  日志: journalctl -u snell -f"
    echo "========================================"
else
    log_error "Snell Server 启动失败！"
    echo "查看日志: journalctl -u snell -n 50"
    exit 1
fi

# 清理临时文件
rm -f /tmp/snell-server.zip

log_info "安装完成！"