# Echo Loop Web 版运维手册

## 服务架构

```
用户浏览器
    ↓ HTTPS :443
nginx (自签名证书)
    ↓ /web/
Flutter Web App (11MB, 39路由)
    ↓ HTTP :3003
nginx API Gateway
    ↓ proxy_pass
echo-transcribe (PM2守护, :3006)
```

## 访问地址

| 服务 | 地址 | 用途 |
|------|------|------|
| Web应用 | https://38.55.146.160:8100/web/ | 浏览器端英语学习 |
| API网关 | http://38.55.146.160:3003/api/v1/* | 后端API入口 |
| 健康检查 | http://38.55.146.160:3003/health | 服务状态监控 |
| Landing | https://38.55.146.160:8100/ | 营销落地页 |

## 日常运维命令

```bash
# 查看服务状态
pm2 list
pm2 logs echo-transcribe --lines 50

# 重启服务
pm2 restart echo-transcribe
sudo nginx -s reload

# 查看端口
ss -tlnp | grep -E ":80 |:443 |:3003 |:3006 "

# 健康检查
curl -s http://localhost:3003/health | python3 -m json.tool
curl -sk https://localhost/web/version.json
```

## 紧急操作

```bash
# 服务全部重启
pm2 restart all
sudo nginx -s reload

# 查看磁盘空间（当前 78.9%）
df -h /www

# 查看内存（当前 38%）
free -h
```

## 部署流程

```bash
# 1. 代码更新后重新构建
cd /www/workspace/Echo-Loop
export PATH=/tmp/flutter/bin:$PATH
flutter build web --release

# 2. 拷贝到部署目录
rsync -avz build/web/ /www/workspace/Echo-Loop-landing/web/

# 3. 验证
curl -sk https://localhost/web/version.json
```

## 注意事项

1. **SSL证书**: 当前为自签名证书，浏览器需手动确认例外
2. **域名解析**: 域名 echo-loop.top 解析到 38.55.146.160 后可执行:
   ```bash
   sudo certbot --nginx -d echo-loop.top
   ```
3. **PM2自启**: 已配置 systemd，reboot 后自动恢复
4. **磁盘监控**: 当前使用 78.9%，注意清理旧日志

## 关键端口

| 端口 | 服务 | 协议 |
|------|------|------|
| 80 | nginx HTTP→HTTPS重定向 | HTTP |
| 443 | nginx Web应用 | HTTPS |
| 3003 | nginx API网关→3006 | HTTP |
| 3006 | echo-transcribe API | HTTP |
