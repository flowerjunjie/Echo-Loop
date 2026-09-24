#!/bin/bash
# Echo Loop Web 版一键构建脚本
# 用法: bash scripts/build-web.sh

set -e

echo "======================================"
echo "  Echo Loop Web 版构建脚本"
echo "======================================"
echo ""

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装，正在下载..."
    
    # 尝试国内镜像
    echo "尝试清华镜像..."
    if ! curl -sL --max-time 30 "https://mirrors.tuna.tsinghua.edu.cn/flutter/releases/3.47.2-stable/linux/flutter_linux_3.47.2-stable.tar.xz" -o /tmp/flutter.tar.xz 2>/dev/null; then
        echo "镜像失败，尝试官方源..."
        curl -L --max-time 300 -o /tmp/flutter.tar.xz "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.2-stable.tar.xz"
    fi
    
    echo "✅ 下载完成，解压中..."
    tar xf /tmp/flutter.tar.xz -C /tmp/
    export PATH="/tmp/flutter/bin:$PATH"
    echo "✅ Flutter 已就绪"
else
    echo "✅ Flutter 已安装: $(flutter --version | head -1)"
    export PATH="$(dirname $(which flutter)):$PATH"
fi

# 验证版本
DART_VERSION=$(flutter --version | grep "Dart" | grep -oP '\d+\.\d+\.\d+' | head -1)
echo "Dart 版本: $DART_VERSION"

if [[ "$DART_VERSION" < "3.9.0" ]]; then
    echo "❌ Dart 版本过低，需要 3.9+"
    exit 1
fi

# 拉取最新代码
echo ""
echo "📦 拉取最新代码..."
git pull origin code-fix

# 构建
echo ""
echo "🔨 开始构建..."
flutter build web --release --dart-define=API_BASE_URL=http://38.55.146.160:3003

# 验证
echo ""
echo "✅ 构建完成!"
echo "产物大小: $(ls -lh build/web/main.dart.js | awk '{print $5}')"
echo "构建时间: $(stat -c %y build/web/main.dart.js | cut -d' ' -f1,2)"

# 部署
echo ""
echo "🚀 部署中..."
rsync -avz --delete build/web/ /www/workspace/Echo-Loop-landing/web/web/
sudo nginx -s reload 2>/dev/null || echo "⚠️ 需要手动执行: sudo nginx -s reload"

# 验证
echo ""
echo "✅ 验证部署..."
curl -s http://38.55.146.160:8100/web/version.json
echo ""
curl -s http://38.55.146.160:8100/web/ | grep -o "<title>[^<]*</title>"

echo ""
echo "======================================"
echo "  构建完成！"
echo "  Web App: http://38.55.146.160:8100/web/"
echo "======================================"
