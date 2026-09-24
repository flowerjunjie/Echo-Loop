#!/bin/bash
# Echo Loop 定时健康检查（每30分钟执行）
# 写入 /etc/crontab: */30 * * * * developer /www/workspace/Echo-Loop/scripts/cron-health-check.sh

LOG_DIR="/var/log/echo-loop"
mkdir -p $LOG_DIR
DATE=$(date '+%Y-%m-%d %H:%M:%S')
DISK_USE=$(df /www 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
MEM_USE=$(free 2>/dev/null | awk '/Mem:/{printf "%.0f", ($3/$2)*100}')
PM2_STATUS=$(pm2 describe echo-transcribe 2>/dev/null | grep "status" | awk '{print $2}')
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3003/health 2>/dev/null)

echo "[$DATE] disk=${DISK_USE}% mem=${MEM_USE}% pm2=$PM2_STATUS api=$API_STATUS" >> $LOG_DIR/health.log

# 磁盘告警
if [ "${DISK_USE:-0}" -gt 85 ] 2>/dev/null; then
  echo "⚠️  DISK WARNING: ${DISK_USE}%" | tee -a $LOG_DIR/health.log
fi
