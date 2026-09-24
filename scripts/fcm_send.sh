#!/bin/bash
# FCM 批量推送脚本
# 用法：./fcm_send.sh <type> <title> <body> [user_id]
#   type: reminder | review | promo
#   user_id: 留空则推送所有设备，否则推送指定用户
#
# 前置条件：后端 echo-transcribe 运行在 localhost:3006，ADMIN_KEY 已在 .env 中配置

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_URL="http://localhost:3006"
ADMIN_KEY=$(grep '^ADMIN_KEY=' "$SCRIPT_DIR/../echo-transcribe/.env" 2>/dev/null | cut -d= -f2 || echo "")

if [[ -z "$ADMIN_KEY" ]]; then
  echo "错误：无法读取 ADMIN_KEY，请确保 echo-transcribe/.env 存在"
  exit 1
fi

TYPE="${1:-reminder}"
TITLE="${2:-学习提醒}"
BODY="${3:-该复习了！}"
USER_ID="${4:-}"

# 获取目标设备token列表
if [[ -n "$USER_ID" ]]; then
  TOKENS=$(curl -s -H "X-Admin-Key: $ADMIN_KEY" "$BASE_URL/api/v1/device/fcm-tokens" \
    | grep -o "\"$USER_ID\"[^}]*}" \
    | grep -o '"fcmToken":"[^"]*"' \
    | cut -d'"' -f4 || true)
else
  TOKENS=$(curl -s -H "X-Admin-Key: $ADMIN_KEY" "$BASE_URL/api/v1/device/fcm-tokens" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
tokens = []
for uid, info in data.items():
    t = info.get('fcmToken','')
    if t: tokens.append(t)
print('\n'.join(tokens))
" 2>/dev/null || true)
fi

COUNT=$(echo "$TOKENS" | grep -c . || true)
if [[ "$COUNT" -eq 0 ]]; then
  echo "无可用设备，推送已跳过"
  exit 0
fi

echo "推送类型: $TYPE | 标题: $TITLE | 目标设备数: $COUNT"

# 逐个推送（FCM HTTP v1 API 调用）
SENT=0
FAILED=0
while IFS= read -r token; do
  [[ -z "$token" ]] && continue
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://fcm.googleapis.com/v1/projects/echo-loop/messages:send" \
    -H "Authorization: Bearer $(cat "$SCRIPT_DIR/../echo-transcribe/.env" 2>/dev/null | grep FCM_SERVER_KEY | cut -d= -f2 || echo '')" \
    -H "Content-Type: application/json" \
    -d "{\"message\":{\"token\":\"$token\",\"notification\":{\"title\":\"$TITLE\",\"body\":\"$BODY\"},\"data\":{\"type\":\"$TYPE\"}}}" \
    2>/dev/null || echo "000")
  if [[ "$HTTP_CODE" == "200" ]]; then
    ((SENT++)) || true
  else
    ((FAILED++)) || true
  fi
done <<< "$TOKENS"

echo "推送完成: 成功 $SENT / 失败 $FAILED / 总计 $COUNT"
