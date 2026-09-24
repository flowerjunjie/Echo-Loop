# Echo Loop Web 版部署指南

## 架构概览

```
用户浏览器
    ↓
nginx (端口 8100) → /web/ → Flutter Web 应用
    ↓
echo-transcribe (端口 3006) → API 服务
    ↓
gateway (端口 3003) → 统一 API 入口
```

## 生产环境地址

- **Web 应用**: http://38.55.146.160:8100/web/
- **API 网关**: http://38.55.146.160:3003
- **echo-transcribe**: http://localhost:3006 (内部)

## 部署步骤

### 1. 构建 Web 版本

```bash
cd /www/workspace/Echo-Loop
export PATH=/tmp/flutter/bin:$PATH

# 构建 release 版本（需 6GB+ 内存）
flutter build web --release \
  --dart-define=API_BASE_URL=http://38.55.146.160:3003

# 验证
ls -lh build/web/main.dart.js
```

### 2. 部署到服务器

```bash
# 方法 A: 使用部署脚本
./deploy-web.sh root 38.55.146.160 /var/www/web

# 方法 B: 手动 rsync
rsync -avz --delete \
  build/web/ \
  root@38.55.146.160:/var/www/web/
```

### 3. 验证部署

```bash
# 检查 Web 页面
curl http://38.55.146.160:8100/web/version.json

# 检查 API 可达性
curl http://38.55.146.160:3003/api/v1/invite/info
```

## nginx 配置

### echo-loop-8100 (Web 应用)
- 监听端口: 8100
- 根目录: /www/workspace/Echo-Loop-landing
- Web 应用路径: /web/

### 如需添加 echo-transcribe 代理
在 nginx config 中添加:
```nginx
location /api/ {
    proxy_pass http://127.0.0.1:3003;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

## 常见问题

### Q: 转录功能返回 401 未授权
A: echo-transcribe API 需要 JWT Token。App 端会自动获取并携带 token。

### Q: Web 版无法连接后端
A: 检查 `main.dart.js` 中的 API URL:
```bash
grep "http://.*3003\|localhost" build/web/main.dart.js
```

### Q: 构建内存不足
A: 确保服务器有 6GB+ 可用内存:
```bash
free -h
```

## 路由清单 (39条)

| 路由 | 页面 | 状态 |
|------|------|------|
| `/` | WebHomeScreen | ✅ |
| `/login` | LoginScreen | ✅ |
| `/login/email` | EmailSignInScreen | ✅ |
| `/login/check-email` | CheckEmailScreen | ✅ |
| `/login/password` | PasswordSignInScreen | ✅ |
| `/invite/:code` | InviteScreen | ✅ |
| `/discover` | DiscoverCollectionsScreen | ✅ |
| `/discover/:collectionId` | OfficialCollectionDetailScreen | ✅ |
| `/study` | StudyScreen | ✅ |
| `/collection/:id` | CollectionDetailScreen | ✅ |
| `/player` | PlayerScreen | ✅ |
| `/blind-listen` | BlindListenPlayerScreen | ✅ |
| `/listen-and-repeat` | ListenAndRepeatPlayerScreen | ✅ |
| `/review-difficult` | ReviewDifficultPracticeScreen | ✅ |
| `/intensive-listen/:audioId` | IntensiveListenPlayerScreen | ✅ |
| `/audio/:audioId/plan` | LearningPlanScreen | ✅ |
| `/asr-test` | AsrTestScreen | ✅ |
| `/favorites` | FavoritesScreen | ✅ |
| `/activity-calendar` | ActivityCalendarScreen | ✅ |
| `/sentence-detail` | SentenceDetailScreen | ✅ |
| `/bookmark-review` | BookmarkReviewScreen | ✅ |
| `/playback-settings` | PlaybackSettingsScreen | ✅ |
| `/learning-settings` | LearningSettingsScreen | ✅ |
| `/asr-settings` | AsrSettingsScreen | ✅ |
| `/tts-settings` | TtsSettingsScreen | ✅ |
| `/dictionary-settings` | DictionarySettingsScreen | ✅ |
| `/flashcard` | FlashcardScreen | ✅ |
| `/preferences-viewer` | PreferencesViewerScreen | ✅ |
| `/reminder-settings` | ReminderSettingsScreen | ✅ |
| `/log-viewer` | LogViewerScreen | ✅ |
| `/settings` | WebSettingsScreen | ✅ |
| `/account` | AccountScreen | ✅ |
| `/paywall` | PaywallScreen | ✅ |
| `/activation-code` | ActivationCodeScreen | ✅ |
| `/activation-stats` | ActivationStatsScreen | ✅ |
| `/enhanced-stats` | EnhancedStatsScreen | ✅ |
| `/onboarding/survey` | OnboardingSurveyScreen | ✅ |
| `/privacy` | PrivacyScreen | ✅ |
| `/terms` | TermsScreen | ✅ |
