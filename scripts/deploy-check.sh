#!/bin/bash
# Echo Loop 部署验证脚本
echo "🟠 Echo Loop · 部署验证"
echo ""
echo "【服务健康】"
HEALTH=$(/usr/bin/curl -s http://localhost:3003/health 2>/dev/null)
if [ -n "$HEALTH" ]; then
  /usr/bin/python3 -c "import sys,json;d=json.load(sys.stdin);print(f'  echo-transcribe: OK (invites={d[\"invites\"]}, activations={d[\"activations\"]})')" 2>/dev/null
else
  echo "  echo-transcribe: ❌"
fi
NGINX=$(/usr/bin/curl -s -k -o /dev/null -w '%{http_code}' https://localhost:443/ 2>/dev/null)
echo "  nginx HTTPS: :443 HTTP $NGINX $([ "$NGINX" = "200" ] && echo '✅' || echo '❌')"
WEB=$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' http://localhost:8100/web/ 2>/dev/null)
echo "  Web App: :8100 HTTP $WEB $([ "$WEB" = "200" ] && echo '✅' || echo '❌')"
echo ""
echo "【代码质量】"
export PATH="/www/workspace/Echo-Loop/flutter/bin:$PATH"
ERRORS=$(/www/workspace/Echo-Loop/flutter/bin/flutter analyze lib/ 2>&1 | /usr/bin/grep "^  error" | /usr/bin/grep -v "^flutter/" | /usr/bin/wc -l)
echo "  Flutter analyze: $ERRORS errors $([ $ERRORS -eq 0 ] && echo '✅' || echo '❌')"
TESTS=$(/www/workspace/Echo-Loop/flutter/bin/flutter test test/services/web/ 2>&1 | /usr/bin/grep -E "passed|failed" | /usr/bin/tail -1)
echo "  Web tests: $TESTS"
echo ""
echo "【SEO】"
for p in "/robots.txt" "/sitemap.xml"; do
  c=$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' "http://localhost:8100$p" 2>/dev/null)
  printf "  %-15s HTTP %s\n" "$p" "$c"
done
echo ""
echo "【磁盘】"
df -h / /www 2>/dev/null | /usr/bin/awk 'NR>1{printf "  %s %s\n", $6, $5}'
