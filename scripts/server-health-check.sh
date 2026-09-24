#!/bin/bash
# Echo Loop 服务器健康检查脚本
# 用法: ./server-health-check.sh

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        🔥 Echo Loop 服务器健康检查报告                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 磁盘使用
echo "📊 磁盘使用"
df -h / /www 2>/dev/null | awk 'NR==1{print "  "$0} NR>1{printf "  %-15s %s\n", $1, $5}'
DISK_USE=$(df /www 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')
if [ "$DISK_USE" -gt 85 ]; then
  echo "  ⚠️  警告: /www 磁盘使用率 ${DISK_USE}% > 85%"
fi
echo ""

# 内存使用
echo "🧠 内存使用"
free -h | awk '/Mem:/ {printf "  总内存: %-8s 已用: %-8s 可用: %-8s 使用率: %.1f%%\n", $2, $3, $7, ($3/$2)*100}'
echo ""

# 服务端口
echo "🌐 服务端口"
for port in 80 443 3003 3006 8100; do
  if ss -tln 2>/dev/null | grep -q ":${port} "; then
    echo "  ✅ :${port} 监听中"
  else
    echo "  ❌ :${port} 未监听"
  fi
done
echo ""

# PM2 状态
echo "🔄 PM2 进程"
pm2 list 2>/dev/null | grep -E "name|echo" | head -5
echo ""

# HTTP 健康检查
echo "🏥 HTTP 健康检查"
WEB_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost/web/ 2>/dev/null || echo "FAIL")
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3003/health 2>/dev/null || echo "FAIL")
echo "  Web HTTPS: :${WEB_STATUS}"
echo "  API Health: :${API_STATUS}"
echo ""

# 安全状态
echo "🛡️ 安全基线"
JWT_LEN=$(grep JWT_SECRET /www/workspace/echo-transcribe/.env 2>/dev/null | cut -d= -f2 | wc -c)
if [ "$JWT_LEN" -gt 50 ]; then
  echo "  ✅ JWT_SECRET 长度: ${JWT_LEN}字符"
else
  echo "  ⚠️  JWT_SECRET 长度异常: ${JWT_LEN}字符"
fi
SSL_END=$(openssl x509 -in /www/workspace/ssl/echo-loop.crt -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$SSL_END" ]; then
  echo "  ✅ SSL证书到期: ${SSL_END}"
else
  echo "  ⚠️  SSL证书未找到"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 检查完成"
