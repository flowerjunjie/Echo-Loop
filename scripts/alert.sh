#!/bin/bash
# Echo Loop 自动告警脚本
# 用法: ./scripts/alert.sh

ALERT_THRESHOLD_DISK=85
ALERT_THRESHOLD_MEMORY=90

echo "🔔 Echo Loop 系统告警检查"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 磁盘告警
DISK_USAGE=$(df / | awk 'NR==2{print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt "$ALERT_THRESHOLD_DISK" ]; then
  echo "⚠️  磁盘告警: / 使用率 ${DISK_USAGE}%"
  # TODO: 发送告警通知
else
  echo "✅ 磁盘正常: ${DISK_USAGE}%"
fi

WWW_USAGE=$(df /www | awk 'NR==2{print $5}' | tr -d '%')
if [ "$WWW_USAGE" -gt "$ALERT_THRESHOLD_DISK" ]; then
  echo "⚠️  /www 磁盘告警: ${WWW_USAGE}%"
else
  echo "✅ /www 正常: ${WWW_USAGE}%"
fi

# 服务告警
echo ""
echo "【服务状态】"
for service in "echo-transcribe:3003" "web:8100"; do
  name=$(echo $service | cut -d: -f1)
  port=$(echo $service | cut -d: -f2)
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/ 2>/dev/null | grep -q "200"; then
    echo "  ✅ $name: OK"
  else
    echo "  ❌ $name: FAILED"
  fi
done
$nginx_check

# SSL 证书告警
echo ""
echo "【SSL 证书】"
if [ -f /www/workspace/ssl/echo-loop.crt ] && openssl x509 -in /www/workspace/ssl/echo-loop.crt -noout -checkend 2592000 2>/dev/null; then
  expiry=$(openssl x509 -in /www/workspace/ssl/echo-loop.crt -noout -enddate 2>/dev/null | cut -d= -f2)
  echo "  ✅ SSL 证书有效 (到期: $expiry)"
else
  echo "  ❌ SSL 证书即将过期或无效"
fi

echo ""
echo "告警检查完成"
