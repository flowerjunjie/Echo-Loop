# Echo Loop Web 版功能测试清单

## 测试环境
- URL: http://38.55.146.160:8100/web/
- 浏览器: Chrome / Firefox / Safari
- 账号: 需要先登录

---

## 测试用例 1: 音频库加载

### 前置条件
- 用户已登录
- 后端有音频数据（需通过 API 或手动添加）

### 测试步骤
1. 打开 http://38.55.146.160:8100/web/
2. 进入「发现精选合集」
3. 检查音频列表是否正常显示

### 预期结果
- ✅ 音频列表不为空
- ✅ 每个音频显示名称、时长
- ✅ 可以点击进入详情页

### 验证点
```bash
# 检查 API 返回数据
curl http://38.55.146.160:3003/api/v1/audio/list
```

---

## 测试用例 2: 音频详情页

### 测试步骤
1. 点击任意音频
2. 观察页面跳转

### 预期结果
- ✅ URL 变为 `/web/audio/:id`
- ✅ 显示音频名称、时长
- ✅ 显示转录文本（如有）
- ✅ 显示操作按钮：开始学习、编辑字幕、删除

### 验证点
```bash
# 检查路由是否注册
curl -s http://38.55.146.160:8100/web/audio/test123 | grep -o "<title>[^<]*</title>"
```

---

## 测试用例 3: 录音转录

### 前置条件
- 用户已登录
- 麦克风权限已授权

### 测试步骤
1. 进入音频详情页
2. 点击「开始学习」
3. 允许麦克风权限
4. 点击录音按钮
5. 说一段英语
6. 点击停止

### 预期结果
- ✅ 录音波形正常显示
- ✅ 转录请求包含 Authorization header
- ✅ 转录结果正常返回
- ✅ 评分结果正常显示

### 验证点
```bash
# 检查 Network 面板
# 请求头应包含: Authorization: Bearer <token>

# 测试转录 API
curl -X POST http://38.55.146.160:3003/api/v1/transcribe \
  -H "Authorization: Bearer <your_token>" \
  -H "Content-Type: application/json" \
  -d '{"audio": "<base64_audio_data>"}'
```

---

## 测试用例 4: 学习流程完整闭环

### 测试步骤
1. 登录
2. 进入合集
3. 点击音频 → 进入详情页
4. 点击「开始学习」
5. 完成跟读练习
6. 查看评分
7. 返回合集

### 预期结果
- ✅ 每一步都能正常跳转
- ✅ 学习进度被正确保存
- ✅ 收藏功能正常
- ✅ 数据持久化到 localStorage

---

## 测试用例 5: 数据持久化

### 测试步骤
1. 收藏一个音频
2. 刷新页面
3. 检查收藏列表

### 预期结果
- ✅ 收藏数据不丢失
- ✅ localStorage 中有对应 key

### 验证点
```javascript
// 浏览器 Console
localStorage.getItem('el_web_bookmarks_v1')
localStorage.getItem('el_web_learning_progress_v1')
```

---

## 测试用例 6: 认证流程

### 测试步骤
1. 打开 Web App（未登录状态）
2. 尝试访问学习页面
3. 应该跳转到登录页
4. 输入邮箱和 OTP 登录
5. 检查 Token 是否正确存储

### 预期结果
- ✅ 未登录时重定向到登录页
- ✅ 登录后 Token 存储在 localStorage
- ✅ 刷新页面后保持登录状态

### 验证点
```javascript
// 浏览器 Console
localStorage.getItem('echo_loop_auth_session')
```

---

## 自动化测试脚本

```bash
#!/bin/bash
# Web 版自动化测试脚本

echo "=== Echo Loop Web 版自动化测试 ==="
echo ""

# 1. 健康检查
echo "【1】服务健康检查"
curl -s http://38.55.146.160:3003/health | python3 -m json.tool
echo ""

# 2. API 测试
echo "【2】API 端点测试"
curl -s http://38.55.146.160:3003/api/v1/invite/stats \
  -H "X-Admin-Key: el-admin-c491bbd5a9c5782c3435223f604e943a"
echo ""

# 3. Web 页面测试
echo "【3】Web 页面测试"
echo "Landing Page:"
curl -s http://38.55.146.160:8100/ | grep -o "<title>[^<]*</title>"
echo ""
echo "Web App:"
curl -s http://38.55.146.160:8100/web/version.json
echo ""

# 4. 资源检查
echo "【4】核心资源检查"
curl -s -I http://38.55.146.160:8100/web/main.dart.js | head -3
curl -s -I http://38.55.146.160:8100/web/flutter_bootstrap.js | head -3
echo ""

echo "=== 测试完成 ==="
```

---

## 已知限制

1. **构建依赖**: 需要 Flutter 3.47.2+ (Dart 3.10)
2. **网络要求**: 下载 Flutter SDK 需要稳定网络
3. **音频数据**: Web 版需要后端有音频数据才能测试学习流程

---

**测试执行时间**: 预计 30 分钟  
**测试人员**: 产品/QA  
**反馈渠道**: 发现问题立即报告
