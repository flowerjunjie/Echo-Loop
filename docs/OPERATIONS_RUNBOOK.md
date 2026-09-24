# Echo Loop 运营手册

> 最后更新：2026-08-31
> 维护者：DevOps Team

## 快速状态检查

```bash
./scripts/system-health.sh
```

预期输出：
```
【代码质量】Flutter analyze: 0 errors ✅
【服务状态】echo-transcribe: OK ✅ | nginx: HTTPS 200 ✅ | Web: 200 ✅
【SEO】robots.txt + sitemap.xml: HTTP 200 ✅
【磁盘】/ 80% · /www 82%
【系统状态】✅ 全绿
```

## 常用操作

### 查看服务状态
```bash
pm2 list                    # PM2 进程状态
pm2 logs echo-transcribe   # 查看日志
curl http://localhost:3003/health  # echo-transcribe 健康检查
```

### 重启服务
```bash
pm2 restart echo-transcribe  # 重启后端
sudo nginx -s reload        # 重载 nginx
```

### 查看日志
```bash
pm2 logs --lines 100        # 最近 100 行日志
tail -f /home/developer/.pm2/logs/echo-transcribe-out.log
```

### 备份系统
```bash
/www/workspace/scripts/backup.sh  # 手动备份
# 或等待 crontab 每日 2:00 自动执行
```

### 磁盘清理
```bash
# 清理 Flutter 缓存
flutter clean
rm -rf build/
rm -rf .dart_tool/

# 清理 PM2 旧日志
find /home/developer/.pm2/logs -name "*.log.*" -mtime +7 -delete

# 清理系统临时文件
sudo find /tmp -mtime +1 -delete
```

## 紧急联系

| 问题类型 | 处理人 | 联系方式 |
|---------|--------|---------|
| 服务器故障 | DevOps | Slack #ops |
| 代码问题 | 开发团队 | GitHub Issues |
| 安全事件 | CTO | 加密信道 |

## 监控告警

- **磁盘 > 85%**: 自动告警
- **服务不可用 > 5min**: 自动重启
- **SSL 证书即将过期**: 提前 30 天告警

## 部署流程

### Web 部署
```bash
cd /www/workspace/Echo-Loop
export PATH="./flutter/bin:$PATH"
flutter build web --release
rsync -avz build/web/ Echo-Loop-landing/web/
```

### 后端部署
```bash
cd /www/workspace/echo-transcribe
pm2 restart echo-transcribe
```

## 回滚方案

如需回滚到上一个版本：
```bash
# Web 回滚
cd /www/workspace/Echo-Loop
git revert HEAD
./scripts/deploy-web.sh

# 后端回滚
cd /www/workspace/echo-transcribe
git revert HEAD
pm2 restart echo-transcribe
```
