# 📱 APK安装与测试指南

## 一、APK文件信息

### 生成的APK
```
📦 app-prod-debug.apk (167MB)
   路径: build/app/outputs/flutter-apk/app-prod-debug.apk
   时间: 2026-08-13 12:32
   说明: 推荐使用，功能完整

📦 app-dev-debug.apk (167MB)
   路径: build/app/outputs/flutter-apk/app-dev-debug.apk
   时间: 2026-08-13 12:29
   说明: 开发版本
```

---

## 二、安装到手机

### 方法1：USB连接安装（推荐）
```bash
# 1. 用USB线连接手机到电脑
# 2. 开启手机的开发者模式和USB调试
# 3. 执行安装命令
adb install build/app/outputs/flutter-apk/app-prod-debug.apk

# 4. 如果提示已安装，先卸载旧版本
adb uninstall top.echo.loop
adb install build/app/outputs/flutter-apk/app-prod-debug.apk
```

### 方法2：微信/邮箱传输
```bash
# 1. 将APK文件发送到手机
# 2. 在手机上打开文件安装
# 3. 允许安装未知来源应用
```

### 方法3：QR Code安装
```bash
# 1. 上传APK到网盘或文件传输网站
# 2. 生成二维码
# 3. 手机扫码下载安装
```

---

## 三、配置后端地址

### 重要：修改API地址
```bash
# 第一次打开App后，进入设置
# 找到「后端地址」或「API配置」
# 输入：http://38.55.146.160:3003
```

**或者在启动时添加参数：**
```bash
flutter run --dart-define=API_BASE_URL=http://38.55.146.160:3003
```

---

## 四、功能测试清单

### ✅ 基础功能测试
- [ ] 打开App，查看首页是否正常
- [ ] 登录/注册功能
- [ ] 导入音频文件
- [ ] 精听/跟读练习
- [ ] 收藏句子

### ✅ 激活码功能测试
- [ ] 进入「设置」→「激活码兑换」
- [ ] 输入测试激活码：`DFH3VH48`
- [ ] 点击「立即激活」
- [ ] 验证是否成功开通会员
- [ ] 检查权益是否到账

### ✅ 管理员功能测试
- [ ] 进入「设置」→「开发者选项」
- [ ] 点击「管理激活码」
- [ ] 生成新的激活码
- [ ] 复制/分享激活码
- [ ] 查看统计按钮

### ✅ 数据统计看板测试
- [ ] 点击「📊基础统计」
- [ ] 查看概览卡片（总数/已激活/未使用/激活率）
- [ ] 查看套餐分布
- [ ] 查看7天趋势图
- [ ] 查看创建人统计

### ✅ 增强统计测试
- [ ] 点击「📈高级统计」
- [ ] 查看收益分析（饼图）
- [ ] 查看趋势图表（柱状图）
- [ ] 查看活跃度分析（小时/星期分布）
- [ ] 查看高峰时段分析
- [ ] 测试下拉刷新

---

## 五、后端API测试

### 使用curl测试
```bash
# 1. 基础统计
curl http://38.55.146.160:3003/api/v1/activation-codes/stats \
  -H "X-Admin-Key: echo-loop-admin-key-change-me-in-production"

# 2. 高级统计（收益/活跃度）
curl http://38.55.146.160:3003/api/v1/activation-codes/advanced-stats \
  -H "X-Admin-Key: echo-loop-admin-key-change-me-in-production"

# 3. 生成激活码
curl -X POST http://38.55.146.160:3003/api/v1/activation-codes/generate \
  -H "Content-Type: application/json" \
  -H "X-Admin-Key: echo-loop-admin-key-change-me-in-production" \
  -d '{"seats":1,"period":"yearly","createdBy":"test"}'
```

---

## 六、常见问题排查

### Q1: App无法连接到后端
```
A: 检查网络设置
   - 确保手机可以访问 38.55.146.160:3003
   - 检查防火墙设置
   - 尝试使用HTTPS（如果配置了）
```

### Q2: 激活码无效
```
A: 检查激活码格式
   - 必须是8位大写字母+数字
   - 检查是否已被使用
   - 联系管理员重新生成
```

### Q3: 统计数据不显示
```
A: 检查后端运行状态
   - 访问 http://38.55.146.160:3003/health
   - 确认后端服务正在运行
   - 检查Admin Key是否正确
```

### Q4: 图表显示异常
```
A: 检查数据格式
   - 确认后端返回的数据格式正确
   - 检查是否有足够的测试数据
   - 刷新页面重新加载
```

---

## 七、性能优化建议

### 安装包优化
```bash
# 生成Release版本（体积更小，性能更好）
flutter build apk --release --split-per-abi
# 生成多个APK，每个针对特定CPU架构
```

### 功能裁剪（可选）
```dart
// 如果不需要某些功能，可以注释掉
// 在 main.dart 中禁用不需要的服务
```

---

## 八、下一步行动

### 立即行动
1. ✅ 安装APK到手机
2. ✅ 测试所有功能
3. ✅ 生成测试激活码
4. ✅ 联系第一个客户

### 本周目标
- [ ] 完成10个电话销售
- [ ] 添加5个意向客户微信
- [ ] 进行2次产品演示
- [ ] 签约1家机构

---

**祝你销售顺利！🚀**

*指南版本：v1.0*
*更新时间：2026-08-13*
