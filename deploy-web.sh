#!/bin/bash
# Echo Loop Web 版部署脚本
# 用法: ./deploy-web.sh [ssh_user] [server] [remote_path]

set -e

SSH_USER="${1:-root}"
SERVER="${2:-38.55.146.160}"
REMOTE_PATH="${3:-/var/www/web}"
BUILD_DIR="/www/workspace/Echo-Loop/build/web"

echo "=== Echo Loop Web 部署 ==="
echo "服务器: ${SSH_USER}@${SERVER}"
echo "远程路径: ${REMOTE_PATH}"
echo "本地构建: ${BUILD_DIR}"
echo ""

# 检查构建产物
if [ ! -f "${BUILD_DIR}/main.dart.js" ]; then
    echo "❌ 构建产物不存在，请先运行 flutter build web --release"
    exit 1
fi

# 检查 API URL 是否正确
if grep -q "localhost:3000" "${BUILD_DIR}/main.dart.js"; then
    echo "⚠️  检测到 localhost:3000，请确认已 patch API URL"
fi

if grep -q "38.55.146.160:3003" "${BUILD_DIR}/main.dart.js"; then
    echo "✅ API URL 已指向生产环境 38.55.146.160:3003"
fi

echo ""
echo "开始部署..."
rsync -avz --delete \
    --exclude='.DS_Store' \
    "${BUILD_DIR}/" \
    "${SSH_USER}@${SERVER}:${REMOTE_PATH}/"

echo ""
echo "✅ 部署完成"
echo ""
echo "验证命令:"
echo "  curl http://${SERVER}:8100/web/version.json"
echo "  curl http://${SERVER}:3003/api/v1/invite/info"
