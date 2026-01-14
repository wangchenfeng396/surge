#!/bin/bash
# Surge-Go 安装脚本

set -e

VERSION="${VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${CONFIG_DIR:-/etc/surge}"

echo "==> 安装 Surge-Go ${VERSION}"

# 检测操作系统和架构
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "${ARCH}" in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    ;;
  *)
    echo "不支持的架构: ${ARCH}"
    exit 1
    ;;
esac

# 下载二进制文件（假设有发布页面）
DOWNLOAD_URL="https://github.com/your-repo/surge-go/releases/download/${VERSION}/surge-${OS}-${ARCH}"

echo "==> 下载 ${DOWNLOAD_URL}"
curl -fsSL "${DOWNLOAD_URL}" -o /tmp/surge

# 安装
echo "==> 安装到 ${INSTALL_DIR}/surge"
sudo install -m 755 /tmp/surge "${INSTALL_DIR}/surge"
rm /tmp/surge

# 创建配置目录
if [ ! -d "${CONFIG_DIR}" ]; then
  echo "==> 创建配置目录 ${CONFIG_DIR}"
  sudo mkdir -p "${CONFIG_DIR}"
fi

# 创建示例配置
if [ ! -f "${CONFIG_DIR}/surge.conf" ]; then
  echo "==> 创建示例配置 ${CONFIG_DIR}/surge.conf"
  sudo tee "${CONFIG_DIR}/surge.conf" > /dev/null <<EOF
[General]
loglevel = info
dns-server = 8.8.8.8
http-listen = 0.0.0.0:8888
socks5-listen = 0.0.0.0:8889
http-api = 127.0.0.1:9090

[Proxy]
Direct = direct

[Proxy Group]
Proxy = select, Direct

[Rule]
FINAL, Proxy
EOF
fi

echo ""
echo "==> 安装完成！"
echo ""
echo "启动命令: sudo surge -c ${CONFIG_DIR}/surge.conf"
echo "配置文件: ${CONFIG_DIR}/surge.conf"
echo ""
