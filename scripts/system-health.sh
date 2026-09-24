#!/bin/bash
# Echo Loop 系统健康检查脚本
# 用法: ./scripts/system-health.sh

echo "🟠 Echo Loop · 系统健康检查" && echo ""

# 代码质量
echo "【代码质量】"
cd /www/workspace/Echo-Loop
export PATH="$PWD/flutter/bin:$PATH"
ERRORS=$(flutter analyze lib/ 2>&1 | grep "^  error" | grep -v "^flutter/" | wc -l)
echo "  Flutter analyze: $ERRORS errors $([ $ERRORS -eq 0 ] && echo '✅' || echo '❌')"
TESTS=$(flutter test test/services/web/ 2>&1 | grep -E "passed|failed" | tail -1)
echo "  Web tests: $TESTS"

# 服务状态
echo ""
echo "【服务状态】"
HEALTH=$(/usr/bin/curl -s http://localhost:3003/health 2>/dev/null)
if [ -n "$HEALTH" ]; then
  INVITES=$(echo "$HEALTH" | /usr/bin/python3 -c "import sys,json;print(json.load(sys.stdin).get('invites',0))" 2>/dev/null || echo "?")
  echo "  echo-transcribe: OK (invites=$INVITES)"
else
  echo "  echo-transcribe: ❌"
fi
NGINX=$( curl -s -k -o /dev/null -w '%{http_code}' https://localhost:443/ 2>/dev/null)
echo "  nginx HTTPS: :443 HTTP $NGINX $([ "$NGINX" = "200" ] && echo '✅' || echo '❌')"
WEB=$( curl -s -o /dev/null -w '%{http_code}' http://localhost:8100/web/ 2>/dev/null)
echo "  Web App: :8100 HTTP $WEB $([ "$WEB" = "200" ] && echo '✅' || echo '❌')"

# SEO 端点
echo ""
echo "【SEO 端点】"
for p in "/robots.txt" "/sitemap.xml"; do
  c=$( curl -s -o /dev/null -w '%{http_code}' "http://localhost:8100$p" 2>/dev/null)
  printf "  %-15s HTTP %s %s\n" "$p" "$c" "$([ "$c" = "200" ] && echo '✅' || echo '❌')"
done

# 磁盘
echo ""
echo "【磁盘】"
df -h / /www 2>/dev/null | /usr/bin/awk 'NR>1{printf "  %s %s\n", $6, $5}'

echo ""
echo "【系统状态】$([ $ERRORS -eq 0 ] && [ "$NGINX" = "200" ] && [ "$WEB" = "200" ] && echo '✅ 全绿' || echo '⚠️ 需关注')"

echo ""
echo "【SSL 证书】"
if /usr/bin/curl -s -k -o /dev/null -w '%{http_code}' https://localhost:443/ 2>/dev/null | grep -q "200"; then
  CERT_EXPIRY=$(/usr/bin/openssl x509 -in /etc/nginx/ssl/server.crt -noout -enddate 2>/dev/null | cut -d= -f2)
  echo "  SSL: ✅ 有效 (到期: ${CERT_EXPIRY:-未知})"
else
  echo "  SSL: ⚠️  需检查"
fi
