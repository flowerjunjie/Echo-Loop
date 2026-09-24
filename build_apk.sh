#!/bin/bash
# Echo-Loop APK 构建脚本
# 同时构建真机版（arm64）和模拟器版（universal），挂载到落地页

set -e

# ─── 环境配置 ──────────────────────────────────────
API_BASE_URL="${API_BASE_URL:-http://38.55.146.160:3017}"
FLUTTER_PATH="${FLUTTER_PATH:-/home/developer/flutter/bin/flutter}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LANDING_APK_DIR="/www/workspace/Echo-Loop-landing/apk"
GRADLE_KTS="$PROJECT_DIR/android/app/build.gradle.kts"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Echo-Loop APK 构建脚本"
echo "   API地址:  $API_BASE_URL"
echo "   Flutter:  $FLUTTER_PATH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查 Flutter
if ! command -v "$FLUTTER_PATH" &> /dev/null; then
    echo "❌ Flutter 未找到: $FLUTTER_PATH"
    exit 1
fi

cd "$PROJECT_DIR"

# ──────────────────────────────────────────────────
# 步骤 1：构建真机版（arm64，当前配置）
# ──────────────────────────────────────────────────
echo "🧹 清理旧构建..."
"$FLUTTER_PATH" clean
"$FLUTTER_PATH" pub get
echo ""

echo "🔨 [1/2] 构建真机版 APK（arm64-v8a）..."
"$FLUTTER_PATH" build apk \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --flavor prod \
  --release

APK_REAL=$(find build/app/outputs -name "app-prod-release.apk" | head -1)
if [ -z "$APK_REAL" ]; then
    echo "❌ 未找到真机 APK"
    exit 1
fi

echo "✅ 真机 APK: $APK_REAL ($(du -sh "$APK_REAL" | cut -f1))"
if strings "$APK_REAL" | grep -q "$API_BASE_URL"; then
    echo "✅ API URL 验证通过: $API_BASE_URL"
else
    echo "❌ 警告：API URL 未嵌入真机 APK！"
    exit 1
fi
echo ""

# ──────────────────────────────────────────────────
# 步骤 2：临时放开 ABI，构建模拟器版（universal）
# ──────────────────────────────────────────────────
echo "🔧 临时放开 ABI（添加 x86_64 支持模拟器）..."
python3 << 'PYEOF'
import re
path = "/www/workspace/Echo-Loop/android/app/build.gradle.kts"
with open(path, 'r') as f:
    content = f.read()

# 1. 添加 x86_64 到 abiFilters
content = content.replace(
    'abiFilters += "arm64-v8a"',
    'abiFilters += listOf("arm64-v8a", "x86_64")'
)

# 2. 移除 packaging excludes（允许模拟器 so 被打包）
content = content.replace(
    '''excludes += listOf("lib/x86_64/**", "lib/armeabi-v7a/**", "lib/x86/**")''',
    ''
)

with open(path, 'w') as f:
    f.write(content)
print("ABI 配置已更新（arm64 + x86_64）")
PYEOF

echo ""
echo "🧹 清理并重新获取依赖..."
"$FLUTTER_PATH" clean
"$FLUTTER_PATH" pub get
echo ""

echo "🔨 [2/2] 构建模拟器版 APK（universal：arm64 + x86_64）..."
"$FLUTTER_PATH" build apk \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --flavor prod \
  --release

APK_EMU=$(find build/app/outputs -name "app-prod-release.apk" | head -1)
if [ -z "$APK_EMU" ]; then
    echo "❌ 未找到模拟器 APK"
    exit 1
fi

echo "✅ 模拟器 APK: $APK_EMU ($(du -sh "$APK_EMU" | cut -f1))"
if strings "$APK_EMU" | grep -q "$API_BASE_URL"; then
    echo "✅ API URL 验证通过: $API_BASE_URL"
else
    echo "❌ 警告：API URL 未嵌入模拟器 APK！"
    exit 1
fi
echo ""

# ──────────────────────────────────────────────────
# 步骤 3：恢复 ABI 配置，复制 APK 到落地页
# ──────────────────────────────────────────────────
echo "🔧 恢复 ABI 配置（仅 arm64）..."
python3 << 'PYEOF'
path = "/www/workspace/Echo-Loop/android/app/build.gradle.kts"
with open(path, 'r') as f:
    content = f.read()

content = content.replace(
    'abiFilters += listOf("arm64-v8a", "x86_64")',
    'abiFilters += "arm64-v8a"'
)

content = content.replace(
    '''excludes += listOf("lib/x86_64/**", "lib/armeabi-v7a/**", "lib/x86/**")''',
    '''excludes += listOf("lib/x86_64/**", "lib/armeabi-v7a/**", "lib/x86/**")'''
)

with open(path, 'w') as f:
    f.write(content)
print("ABI 配置已恢复（仅 arm64）")
PYEOF

mkdir -p "$LANDING_APK_DIR"
cp "$APK_REAL"  "$LANDING_APK_DIR/app-release.apk"
cp "$APK_EMU"   "$LANDING_APK_DIR/app-emulator-release.apk"

echo ""
echo "🌐 已挂载到落地页："
echo "   📱 真机版：$LANDING_APK_DIR/app-release.apk      ($(du -sh "$LANDING_APK_DIR/app-release.apk" | cut -f1))"
echo "   💻 模拟器：$LANDING_APK_DIR/app-emulator-release.apk  ($(du -sh "$LANDING_APK_DIR/app-emulator-release.apk" | cut -f1))"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 构建完成！"
echo "   落地页：http://38.55.146.160:8100"
echo "   API：  $API_BASE_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
