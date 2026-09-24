#!/bin/bash
# Echo-Loop 推广启动脚本

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Echo-Loop 推广启动"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. 检查服务器状态
echo "1️⃣ 检查服务器状态..."
HEALTH=$(curl -s http://38.55.146.160:3003/health)
if [ -n "$HEALTH" ]; then
    echo "   ✅ API服务正常"
else
    echo "   ❌ API服务异常"
fi

Landing=$(curl -s -o /dev/null -w "%{http_code}" http://38.55.146.160:8100/)
if [ "$Landing" = "200" ]; then
    echo "   ✅ Landing页正常"
else
    echo "   ❌ Landing页异常"
fi

# 2. 检查APK
echo ""
echo "2️⃣ 检查APK文件..."
APK_SIZE=$(ls -lh /www/workspace/Echo-Loop-landing/apk/app-release.apk 2>/dev/null | awk '{print $5}')
if [ -n "$APK_SIZE" ]; then
    echo "   ✅ APK就绪 ($APK_SIZE)"
else
    echo "   ❌ APK不存在"
fi

# 3. 检查模型
echo ""
echo "3️⃣ 检查模型文件..."
TTS_COUNT=$(ls /www/workspace/echo-transcribe/models/tts/ 2>/dev/null | wc -l)
ASR_COUNT=$(ls /www/workspace/echo-transcribe/models/asr/ 2>/dev/null | wc -l)
echo "   TTS模型: $TTS_COUNT 个"
echo "   ASR模型: $ASR_COUNT 个"

# 4. 生成推广链接
echo ""
echo "4️⃣ 推广链接:"
echo "   📱 APK下载: http://38.55.146.160:8100/apk/app-release.apk"
echo "   🌐 Landing: http://38.55.146.160:8100"
echo "   📄 隐私:    http://38.55.146.160:8100/privacy.html"
echo "   📄 条款:    http://38.55.146.160:8100/terms.html"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 准备就绪，可以开始推广！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
