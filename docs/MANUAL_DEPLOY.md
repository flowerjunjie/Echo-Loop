# Echo Loop Web 版手动部署指南

## 背景
代码已修复并提交（commit b25d8513），但由于网络不稳定，无法自动下载 Flutter SDK 完成构建。
请按照以下步骤手动完成构建部署。

---

## 步骤 1：下载 Flutter SDK（Dart 3.9+）

```bash
# 方法 A：使用官方源（需要稳定网络）
cd /tmp
curl -L -o flutter.tar.xz "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.35.0-stable.tar.xz"

# 方法 B：使用清华镜像（推荐）
curl -L -o flutter.tar.xz "https://mirrors.tuna.tsinghua.edu.cn/flutter/releases/3.35.0-stable/linux/flutter_linux_3.35.0-stable.tar.xz"

# 验证下载
ls -lh flutter.tar.xz
xz -t flutter.tar.xz
```

---

## 步骤 2：解压并设置环境

```bash
# 解压
tar xf flutter.tar.xz -C /tmp/

# 设置 PATH
export PATH="/tmp/flutter/bin:$PATH"

# 验证版本（需要 Dart 3.9+）
flutter --version
# 预期输出：Dart 3.9.x 或更高
```

---

## 步骤 3：构建 Web 版

```bash
cd /www/workspace/Echo-Loop

# 拉取最新代码
git pull origin code-fix

# 构建
flutter build web --release --dart-define=API_BASE_URL=http://38.55.146.160:3003

# 验证构建产物
ls -lh build/web/main.dart.js
flutter analyze lib/  # 应零 error
```

---

## 步骤 4：部署到服务器

```bash
# 同步构建产物
rsync -avz --delete build/web/ /www/workspace/Echo-Loop-landing/web/web/

# 重载 nginx
sudo nginx -s reload

# 验证部署
curl http://38.55.146.160:8100/web/version.json
curl http://38.55.146.160:8100/web/ | grep -o "<title>[^<]*</title>"
```

---

## 步骤 5：端到端验证

### 浏览器测试
1. 打开 http://38.55.146.160:8100/web/
2. 登录账号（邮箱 + OTP）
3. 进入「发现精选合集」
4. 点击任意合集 → 点击音频
5. 应跳转到 `/audio/:id` 详情页
6. 点击「开始学习」→ 允许麦克风
7. 录音 → 停止 → 转录
8. 检查 Network 面板，确认请求头包含 `Authorization: Bearer xxx`
9. 查看评分结果

### API 验证
```bash
# 健康检查
curl http://38.55.146.160:3003/health

# 邀请码统计
curl http://38.55.146.160:3003/api/v1/invite/stats \
  -H "X-Admin-Key: el-admin-c491bbd5a9c5782c3435223f604e943a"

# 激活码统计
curl http://38.55.146.160:3003/api/v1/activate/stats \
  -H "X-Admin-Key: el-admin-c491bbd5a9c5782c3435223f604e943a"
```

---

## 本次修复内容

| 文件 | 变更 | 说明 |
|------|------|------|
| lib/database/providers_web.dart | +296/-32 | AudioItemDaoStub → AudioItemDaoWebImpl |
| lib/services/web/web_asr_service.dart | +24/-10 | 添加 Token 认证拦截器 |
| lib/services/speech_practice_platform.dart | +10/-3 | Provider 传递 authSessionProvider.token |
| lib/screens/audio_detail_screen.dart | +400/0 | 新建音频详情页 |
| lib/router/web_router.dart | +9/0 | 注册 /audio/:id 路由 |

**总计**: 5 files, +707/-32 lines

---

## 问题排查

### Q: 转录返回 401 Unauthorized
**原因**: Token 未传递  
**解决**: 确认 WebAsrService 已添加拦截器，且 Provider 已传递 session?.accessToken

### Q: 音频列表为空
**原因**: AudioItemDaoWebImpl 未正确实现  
**解决**: 检查 localStorage key `el_web_audio_items_v1` 是否有数据

### Q: 路由 404
**原因**: /audio/:id 未注册  
**解决**: 检查 web_router.dart 是否包含该路由

### Q: Flutter 构建失败 SDK 版本不匹配
**原因**: Dart SDK 版本 < 3.9.2  
**解决**: 下载 Flutter 3.35+ (Dart 3.9+)

---

**文档生成时间**: 2026-08-28 17:30  
**Git Commit**: b25d8513
