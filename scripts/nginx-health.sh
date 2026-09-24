#!/bin/bash
# nginx 健康检查脚本

echo "【nginx 状态】"

# 检查进程
if pgrep -x "nginx" > /dev/null; then
  echo "  ✅ nginx 进程运行中"
else
  echo "  ❌ nginx 进程未运行"
  exit 1
fi

# 检查端口
if ss -tlnp | grep -q ":443 "; then
  echo "  ✅ :443 端口监听中"
else
  echo "  ⚠️  :443 端口未监听"
fi

# 检查 HTTPS 响应
HTTP_CODE=$(/usr/bin/curl -s -k -o /dev/null -w "%{http_code}" https://localhost:443/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  echo "  ✅ HTTPS :443 → HTTP $HTTP_CODE"
elif [ "$HTTP_CODE" = "000" ]; then
  echo "  ❌ HTTPS :443 → 连接失败"
else
  echo "  ⚠️  HTTPS :443 → HTTP $HTTP_CODE"
fi

# 检查 SSL 证书
CERT_FILE=$(grep -r "ssl_certificate " /etc/nginx/sites-enabled/*.conf 2>/dev/null | head -1 | awk '{print $2}')
if [ -n "$CERT_FILE" ] && [ -f "$CERT_FILE" ]; then
  if openssl x509 -in "$CERT_FILE" -noout -checkend 2592000 2>/dev/null; then
    EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2)
    echo "  ✅ SSL 证书有效 (到期: $EXPIRY)"
  else
    echo "  ❌ SSL 证书即将过期"
  fi
else
  echo "  ⚠️  SSL 证书文件未找到: $CERT_FILE"
fi
