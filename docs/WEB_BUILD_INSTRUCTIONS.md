# Echo Loop Web 版构建部署指南

## 当前状态

### ✅ 已完成
- 代码修复已提交（commit `b25d8513`）
- 5 个文件修改，+707/-32 行
- 服务正常运行（PM2 uptime 19h+）

### ❌ 待完成
- Flutter SDK 不在当前环境
- 网络下载 Flutter SDK 超时
- 需要手动构建部署

## 修复内容

| 修复项 | 文件 | 说明 |
|--------|------|------|
| AudioItemDaoWebImpl | lib/database/providers_web.dart | 实现完整音频库 (+200行) |
| WebAsrService Token | lib/services/web/web_asr_service.dart | 添加认证拦截器 |
| Provider 传递 Token | lib/services/speech_practice_platform.dart | 读取 authSessionProvider |
| 音频详情页 | lib/screens/audio_detail_screen.dart | 新建 400 行 |
| 路由注册 | lib/router/web_router.dart | 添加 /audio/:id |

## 手动构建步骤

### 步骤 1：在有 Flutter SDK 的机器上

```bash
# 克隆或拉取最新代码
cd /www/workspace/Echo-Loop
git pull origin code-fix
```

### 步骤 2：构建 Web 版

```bash
# 确保 Flutter 版本 >= 3.27 (Dart 3.7+)
flutter --version

# 构建
flutter build web --release --dart-define=API_BASE_URL=http://38.55.146.160:3003

# 验证
ls -lh build/web/main.dart.js
flutter analyze lib/
```

### 步骤 3：部署

```bash
# 同步到服务器
rsync -avz --delete build/web/ /www/workspace/Echo-Loop-landing/web/web/

# 重载 nginx
sudo nginx -s reload
```

### 步骤 4：验证

```bash
# 检查版本
curl http://38.55.146.160:8100/web/version.json

# 检查页面
curl http://38.55.146.160:8100/web/ | grep -o "<title>[^<]*</title>"

# 检查资源
curl -I http://38.55.146.160:8100/web/main.dart.js
```

## 预期效果

修复后的用户流程：
1. 打开 http://38.55.146.160:8100/web/
2. 登录账号（Token 存 localStorage）
3. 进入「发现精选合集」
4. 点击音频 → 跳转到 `/audio/:id`（不再 404）
5. 点击「开始学习」→ 录音 → 转录（带认证，不再 401）
6. 查看评分结果

## 常见问题

### Q: Flutter 版本不匹配
```
Because echo_loop requires SDK version ^3.9.2, version solving failed.
```
**解决**: 升级 Flutter 到 3.27+ 或修改 pubspec.yaml 的 sdk 约束

### Q: 转录返回 401
**原因**: WebAsrService 未传递 Token
**解决**: 已修复，重新构建后生效

### Q: 音频列表为空
**原因**: AudioItemDaoStub 返回空列表
**解决**: 已实现 AudioItemDaoWebImpl，重新构建后生效

## Git 提交记录

```
b25d8513 fix: Web版学习流程修复 — 认证 + 音频库 + 详情页路由
8b2fcad1 fix: 更新注释中的API路径描述
8d3e734c docs: 更新TASKS.md记录激活码API修复 + 修复Landing APK下载链接
```
